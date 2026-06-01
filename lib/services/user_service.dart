import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_models.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cached logged in user ID to support bypass/non-Firebase Auth flows
  static String? _cachedUserId;

  static void setCachedUserId(String? id) {
    _cachedUserId = id;
  }

  // For dummy purposes if no auth is implemented yet
  String get currentUserId {
    if (_cachedUserId != null) return _cachedUserId!;
    return _auth.currentUser?.uid ?? DummyData.currentUserId;
  }

  Future<UserModel?> getUserByPhone(String phone) async {
    // Handle bypass numbers for testing
    if (phone == '9898989898') {
      _cachedUserId = 'bypass_trainer';
      return const UserModel(
        id: 'bypass_trainer',
        name: 'Demo Trainer',
        phoneNumber: '9898989898',
        role: 'trainer',
      );
    } else if (phone == '9999999999') {
      _cachedUserId = 'bypass_student';
      return const UserModel(
        id: 'bypass_student',
        name: 'Demo Student',
        phoneNumber: '9999999999',
        role: 'student',
      );
    }

    // 1. Search in the unified 'bharatam_users' collection first!
    var snapshot = await _db
        .collection('bharatam_users')
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final user = UserModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      _cachedUserId = user.id;
      return user;
    }

    // 2. Fallback to legacy collections for existing accounts
    snapshot = await _db
        .collection('learners')
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final user = UserModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      _cachedUserId = user.id;
      return user;

    }

    // Check trainers account collection (bharatam_trainers) first as it's the source of truth for account details
    snapshot = await _db
        .collection('bharatam_trainers')
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      // Fallback to legacy trainers collection if not found in bharatam_trainers
      snapshot = await _db
          .collection('trainers')
          .where('phoneNumber', isEqualTo: phone)
          .limit(1)
          .get();
          
      if (snapshot.docs.isEmpty) return null;
    }

    // We found a trainer in either bharatam_trainers or trainers
    final doc = snapshot.docs.first;
    final data = doc.data();
    final id = doc.id;

    _cachedUserId = id;

    // If we found them in bharatam_trainers, try to fetch the profile photo from trainers collection
    // as per user request: "profile photo is saved inside the trainers collection"
    if (snapshot.docs.first.reference.parent.id == 'bharatam_trainers') {
      try {
        final trainerDoc = await _db.collection('trainers').doc(id).get();
        if (trainerDoc.exists) {
          final trainerData = trainerDoc.data();
          if (trainerData != null && trainerData['profileImageUrl'] != null) {
            data['profileImageUrl'] = trainerData['profileImageUrl'];
          }
        }
      } catch (_) {}
    }

    return UserModel.fromMap(data, id);
  }

  Future<void> updateUserProfile(UserModel user) async {
    // 1. Update the unified 'bharatam_users' collection
    await _db.collection('bharatam_users').doc(user.id).set(user.toMap(), SetOptions(merge: true));

    // Determine the primary legacy collection based on role
    final collectionName = user.role == 'trainer' ? 'bharatam_trainers' : 'learners';
    
    // Update the main legacy account collection
    await _db.collection(collectionName).doc(user.id).set(user.toMap(), SetOptions(merge: true));
    
    // Special handling for trainers: sync profile photo to 'trainers' collection
    if (user.role == 'trainer' || user.role == 'Instructor') {
      try {
        // According to user request: profile photo goes to 'trainers' collection
        // while other details are in the 'account' collection (bharatam_trainers)
        await _db.collection('trainers').doc(user.id).set({
          'profileImageUrl': user.profileImageUrl,
          'name': user.name, // Usually name is needed for identification
          'phoneNumber': user.phoneNumber,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error syncing to trainers collection: $e');
      }
    }
  }

  Future<List<PurchaseRecord>> getUserPurchases(String userId) async {
    final snapshot = await _db.collection('purchases').where('userId', isEqualTo: userId).get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      
      PurchaseType type = PurchaseType.course;
      if (data['purchaseType'] == 'module') type = PurchaseType.module;
      if (data['purchaseType'] == 'video') type = PurchaseType.video;
      
      return PurchaseRecord(
        userId: data['userId'] ?? '',
        courseId: data['courseId'] ?? '',
        moduleId: data['moduleId'],
        videoId: data['videoId'],
        purchaseType: type,
        purchasedAt: (data['purchasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        amountPaid: (data['amountPaid'] ?? 0.0).toDouble(),
        trainerShare: (data['trainerShare'] ?? 0.0).toDouble(),
        transactionId: data['transactionId'] ?? '',
        trainerId: data['trainerId'] ?? '',
        status: data['status'] ?? 'success',
        planType: data['planType'], // Securely retrieve plan type
      );
    }).toList();
  }

  Future<List<UserModel>> getLearners() async {
    try {
      final snapshot = await _db
          .collection('bharatam_users')
          .where('role', isEqualTo: 'student')
          .get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching learners: $e');
      return [];
    }
  }

  Future<List<UserModel>> getTrainers() async {
    try {
      final snapshot = await _db
          .collection('bharatam_users')
          .where('role', isEqualTo: 'trainer')
          .get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching trainers: $e');
      return [];
    }
  }
}
