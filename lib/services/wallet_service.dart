import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Credits the trainer's wallet balance with their revenue share from a purchase.
  /// Uses a Firestore transaction to ensure atomic execution and check for duplicates.
  Future<void> creditTrainerWallet({
    required String purchaseId,
    required String trainerId,
    required double trainerShare,
    required double amountPaid,
    required String description,
  }) async {
    try {
      // 1. Check if a ledger entry already exists for this purchase to prevent double-crediting
      final ledgerQuery = await _db
          .collection('bharatam_wallet_transactions')
          .where('referenceId', isEqualTo: purchaseId)
          .where('type', isEqualTo: 'earnings_credit')
          .get();

      if (ledgerQuery.docs.isNotEmpty) {
        debugPrint('Wallet already credited for purchase $purchaseId');
        return;
      }

      // 2. Perform transaction to update wallet and log ledger entry
      await _db.runTransaction((transaction) async {
        final walletRef = _db.collection('bharatam_wallets').doc(trainerId);
        final walletDoc = await transaction.get(walletRef);

        double balance = trainerShare;
        double totalEarnings = trainerShare;
        double totalWithdrawn = 0.0;
        double pendingWithdrawal = 0.0;

        if (walletDoc.exists) {
          final data = walletDoc.data()!;
          balance = (data['balance'] ?? 0.0).toDouble() + trainerShare;
          totalEarnings = (data['totalEarnings'] ?? 0.0).toDouble() + trainerShare;
          totalWithdrawn = (data['totalWithdrawn'] ?? 0.0).toDouble();
          pendingWithdrawal = (data['pendingWithdrawal'] ?? 0.0).toDouble();
        }

        // Set/Update Wallet
        transaction.set(walletRef, {
          'trainerId': trainerId,
          'balance': balance,
          'totalEarnings': totalEarnings,
          'totalWithdrawn': totalWithdrawn,
          'pendingWithdrawal': pendingWithdrawal,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Add Ledger Transaction
        final ledgerRef = _db.collection('bharatam_wallet_transactions').doc();
        transaction.set(ledgerRef, {
          'trainerId': trainerId,
          'amount': trainerShare,
          'type': 'earnings_credit',
          'status': 'completed',
          'referenceId': purchaseId,
          'description': description,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('Successfully credited trainer $trainerId wallet with ₹$trainerShare for purchase $purchaseId');
    } catch (e) {
      debugPrint('Error crediting trainer wallet: $e');
      rethrow;
    }
  }

  /// Trainer requests a withdrawal.
  /// Moves the requested amount from available balance to pending withdrawal.
  Future<void> requestWithdrawal({
    required String trainerId,
    required double amount,
  }) async {
    // 1. Fetch user bank details to lock them in at request time
    final userDoc = await _db.collection('bharatam_users').doc(trainerId).get();
    if (!userDoc.exists) {
      throw Exception('Trainer profile not found.');
    }

    final userData = userDoc.data() ?? {};
    final bankName = userData['bankName'] ?? '';
    final bankAccount = userData['bankAccount'] ?? userData['accountNumber'] ?? '';
    final ifscCode = userData['ifscCode'] ?? '';
    final upiId = userData['upiId'] ?? '';

    if (bankName.toString().isEmpty && bankAccount.toString().isEmpty && upiId.toString().isEmpty) {
      throw Exception('Please configure your bank details or UPI ID in your profile before requesting a withdrawal.');
    }

    // 2. Query for duplicate pending requests (cannot be done inside transaction directly)
    final pendingQuery = await _db
        .collection('bharatam_withdrawal_requests')
        .where('trainerId', isEqualTo: trainerId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (pendingQuery.docs.isNotEmpty) {
      final pendingAmount = (pendingQuery.docs.first.data()['amount'] ?? 0).toDouble();
      throw Exception('You already have a pending withdrawal request of ₹${pendingAmount.toInt()}. Please wait for admin approval.');
    }

    // 3. Perform atomic wallet transaction
    await _db.runTransaction((transaction) async {
      final walletRef = _db.collection('bharatam_wallets').doc(trainerId);
      final walletDoc = await transaction.get(walletRef);

      if (!walletDoc.exists) {
        throw Exception('Wallet not found. Please earn some rewards first.');
      }

      final walletData = walletDoc.data()!;
      final balance = (walletData['balance'] ?? 0.0).toDouble();
      final pendingWithdrawal = (walletData['pendingWithdrawal'] ?? 0.0).toDouble();

      // Verify balance
      if (balance < amount) {
        throw Exception('Insufficient balance. Available balance is ₹${balance.toInt()}.');
      }

      // Fetch minimum threshold
      final configRef = _db.collection('platform_config').doc('settings');
      final configDoc = await transaction.get(configRef);
      double minThreshold = 1000.0;
      if (configDoc.exists) {
        minThreshold = (configDoc.data()?['minWithdrawalThreshold'] ?? 1000.0).toDouble();
      }

      // Verify threshold
      if (amount < minThreshold) {
        throw Exception('The minimum withdrawal limit is ₹${minThreshold.toInt()}.');
      }

      // Create Request document reference
      final requestRef = _db.collection('bharatam_withdrawal_requests').doc();
      final requestId = requestRef.id;

      // Update Wallet: deduct balance, increase pending
      transaction.update(walletRef, {
        'balance': balance - amount,
        'pendingWithdrawal': pendingWithdrawal + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write Withdrawal Request
      transaction.set(requestRef, {
        'trainerId': trainerId,
        'amount': amount,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'processedAt': null,
        'rejectionReason': null,
        'bankName': bankName,
        'bankAccount': bankAccount,
        'ifscCode': ifscCode,
        'upiId': upiId,
      });

      // Add Ledger Transaction
      final ledgerRef = _db.collection('bharatam_wallet_transactions').doc();
      transaction.set(ledgerRef, {
        'trainerId': trainerId,
        'amount': -amount,
        'type': 'withdrawal_request',
        'status': 'pending',
        'referenceId': requestId,
        'description': 'Withdrawal request submitted',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Admin approves a withdrawal request.
  /// Deducts from pending balance, adds to total withdrawn, completes the process.
  Future<void> approveWithdrawal(String requestId) async {
    await _db.runTransaction((transaction) async {
      final requestRef = _db.collection('bharatam_withdrawal_requests').doc(requestId);
      final requestDoc = await transaction.get(requestRef);

      if (!requestDoc.exists) {
        throw Exception('Withdrawal request not found.');
      }

      final requestData = requestDoc.data()!;
      final status = requestData['status'] ?? 'pending';
      if (status != 'pending') {
        throw Exception('Request has already been processed.');
      }

      final trainerId = requestData['trainerId'] ?? '';
      final amount = (requestData['amount'] ?? 0.0).toDouble();

      final walletRef = _db.collection('bharatam_wallets').doc(trainerId);
      final walletDoc = await transaction.get(walletRef);

      if (!walletDoc.exists) {
        throw Exception('Trainer wallet not found.');
      }

      final walletData = walletDoc.data()!;
      final totalWithdrawn = (walletData['totalWithdrawn'] ?? 0.0).toDouble();
      final pendingWithdrawal = (walletData['pendingWithdrawal'] ?? 0.0).toDouble();

      // Update Wallet: deduct from pending, add to totalWithdrawn
      transaction.update(walletRef, {
        'pendingWithdrawal': pendingWithdrawal - amount,
        'totalWithdrawn': totalWithdrawn + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Request status to approved
      transaction.update(requestRef, {
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
      });

      // Log Completed transaction
      final ledgerRef = _db.collection('bharatam_wallet_transactions').doc();
      transaction.set(ledgerRef, {
        'trainerId': trainerId,
        'amount': -amount,
        'type': 'withdrawal_approval',
        'status': 'completed',
        'referenceId': requestId,
        'description': 'Withdrawal request approved & processed',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Admin rejects a withdrawal request.
  /// Restores pending balance back into Available Wallet Balance.
  Future<void> rejectWithdrawal(String requestId, {required String reason}) async {
    await _db.runTransaction((transaction) async {
      final requestRef = _db.collection('bharatam_withdrawal_requests').doc(requestId);
      final requestDoc = await transaction.get(requestRef);

      if (!requestDoc.exists) {
        throw Exception('Withdrawal request not found.');
      }

      final requestData = requestDoc.data()!;
      final status = requestData['status'] ?? 'pending';
      if (status != 'pending') {
        throw Exception('Request has already been processed.');
      }

      final trainerId = requestData['trainerId'] ?? '';
      final amount = (requestData['amount'] ?? 0.0).toDouble();

      final walletRef = _db.collection('bharatam_wallets').doc(trainerId);
      final walletDoc = await transaction.get(walletRef);

      if (!walletDoc.exists) {
        throw Exception('Trainer wallet not found.');
      }

      final walletData = walletDoc.data()!;
      final balance = (walletData['balance'] ?? 0.0).toDouble();
      final pendingWithdrawal = (walletData['pendingWithdrawal'] ?? 0.0).toDouble();

      // Update Wallet: restore balance, deduct from pending
      transaction.update(walletRef, {
        'balance': balance + amount,
        'pendingWithdrawal': pendingWithdrawal - amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Request status to rejected with reason
      transaction.update(requestRef, {
        'status': 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
      });

      // Log Rejected transaction
      final ledgerRef = _db.collection('bharatam_wallet_transactions').doc();
      transaction.set(ledgerRef, {
        'trainerId': trainerId,
        'amount': amount, // Show positive restore
        'type': 'withdrawal_rejection',
        'status': 'rejected',
        'referenceId': requestId,
        'description': 'Withdrawal request rejected: $reason',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Stream to listen to a trainer's wallet updates.
  Stream<DocumentSnapshot<Map<String, dynamic>>> getTrainerWalletStream(String trainerId) {
    return _db.collection('bharatam_wallets').doc(trainerId).snapshots();
  }

  /// Stream to listen to a trainer's transaction ledger history (sorted newest first).
  Stream<QuerySnapshot<Map<String, dynamic>>> getTrainerLedgerStream(String trainerId) {
    return _db
        .collection('bharatam_wallet_transactions')
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Stream to listen to a trainer's withdrawal requests history.
  Stream<QuerySnapshot<Map<String, dynamic>>> getTrainerWithdrawalsStream(String trainerId) {
    return _db
        .collection('bharatam_withdrawal_requests')
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  /// Stream to listen to all withdrawal requests (Admin use).
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllWithdrawalsStream() {
    return _db
        .collection('bharatam_withdrawal_requests')
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  /// Get minimum threshold configuration from settings.
  Future<double> getMinWithdrawalThreshold() async {
    try {
      final doc = await _db.collection('platform_config').doc('settings').get();
      if (doc.exists) {
        return (doc.data()?['minWithdrawalThreshold'] ?? 1000.0).toDouble();
      }
    } catch (_) {}
    return 1000.0;
  }

  /// Set minimum threshold configuration from settings.
  Future<void> setMinWithdrawalThreshold(double threshold) async {
    await _db.collection('platform_config').doc('settings').set({
      'minWithdrawalThreshold': threshold,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
