import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';
import '../widgets/instructor_avatar.dart';

class TrainerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<TrainerStats> getTrainerStatsStream(String trainerId) {
    // 1. Listen to courses for this trainer
    final coursesStream = _db
        .collection('bharatam_courses')
        .where('trainerId', isEqualTo: trainerId)
        .snapshots();

    // 2. Listen to purchases for this trainer
    final purchasesStream = _db
        .collection('purchases')
        .where('trainerId', isEqualTo: trainerId)
        .snapshots();

    return Stream.castFrom(
      _db.collection('trainers').doc(trainerId).snapshots().asyncMap((userDoc) async {
        final coursesSnapshot = await _db
            .collection('bharatam_courses')
            .where('trainerId', isEqualTo: trainerId)
            .get();

        final purchasesSnapshot = await _db
            .collection('purchases')
            .where('trainerId', isEqualTo: trainerId)
            .get();

        double totalEarnings = 0;
        for (var doc in purchasesSnapshot.docs) {
          totalEarnings += (doc.data()['trainerShare'] ?? 0).toDouble();
        }

        int totalStudents = 0;
        final userData = userDoc.data();
        if (userData != null) {
          totalStudents = userData['totalStudents'] ?? 0;
        }

        // Map recent courses
        List<CourseModel> recentCourses = coursesSnapshot.docs.map((doc) {
          final data = doc.data();
          final oneTime = data['oneTimePrice'] != null ? double.tryParse(data['oneTimePrice'].toString()) : null;
          final limited = data['limitedTimePrice'] != null ? double.tryParse(data['limitedTimePrice'].toString()) : null;
          final lifetime = data['lifetimePrice'] != null ? double.tryParse(data['lifetimePrice'].toString()) : null;
          final priceVal = data['price'] != null 
              ? (double.tryParse(data['price'].toString()) ?? 0.0)
              : ((oneTime != null && oneTime > 0) 
                  ? oneTime 
                  : ((limited != null && limited > 0) 
                      ? limited 
                      : (lifetime ?? 0.0)));

          return CourseModel(
            id: doc.id,
            title: data['courseName'] ?? data['title'] ?? '',
            description: data['description'] ?? '',
            category: data['category'] ?? '',
            price: priceVal,
            emoji: data['emoji'] ?? CourseModel.emojiForCategory(data['category'] ?? ''),
            thumbnailUrl: data['thumbnailUrl'] ?? '',
            trainerId: data['trainerId'] ?? '',
            trainerName: data['trainerName'] ?? '',
            isApproved: data['isApproved'] ?? false,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
            limitedTimePrice: limited,
            oneTimePrice: oneTime,
            lifetimePrice: lifetime,
            limitedTimeDays: data['limitedTimeDays'] != null ? int.tryParse(data['limitedTimeDays'].toString()) : null,
          );
        }).toList();

        // Sort by createdAt descending
        recentCourses.sort((a, b) {
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        
        // Map recent purchases
        List<PurchaseRecord> recentPurchases = purchasesSnapshot.docs.map((doc) {
          final data = doc.data();
          return PurchaseRecord(
            userId: data['userId'] ?? '',
            courseId: data['courseId'] ?? '',
            moduleId: data['moduleId'],
            videoId: data['videoId'],
            purchaseType: PurchaseType.values.firstWhere(
              (e) => e.toString().split('.').last == data['purchaseType'],
              orElse: () => PurchaseType.course,
            ),
            purchasedAt: (data['purchasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            amountPaid: (data['amountPaid'] ?? 0).toDouble(),
            trainerShare: (data['trainerShare'] ?? 0).toDouble(),
            transactionId: data['transactionId'] ?? '',
            trainerId: data['trainerId'] ?? '',
            status: data['status'] ?? 'success',
          );
        }).toList();

        // Sort purchases by date descending
        recentPurchases.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));

        return TrainerStats(
          totalEarnings: totalEarnings,
          totalStudents: totalStudents,
          totalCourses: coursesSnapshot.docs.length,
          recentCourses: recentCourses.take(3).toList(),
          recentPurchases: recentPurchases,
        );
      }),
    );
  }

  Future<List<InstructorData>> getTrainers() async {
    final querySnapshot = await _db
        .collection('bharatam_users')
        .where('role', isEqualTo: 'trainer')
        .get();

    final instructorSnapshot = await _db
        .collection('bharatam_users')
        .where('role', isEqualTo: 'Instructor')
        .get();

    final legacySnapshot = await _db.collection('bharatam_trainers').get();

    final Map<String, InstructorData> uniqueTrainers = {};

    void addTrainerFromDoc(DocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      
      final name = _readFirstString(data, [
        'name',
        'displayName',
        'fullName',
        'trainerName',
      ]);
      final emoji = _readFirstString(data, [
        'emoji',
        'avatarEmoji',
        'profileEmoji',
      ]);

      final imageUrl = _readFirstString(data, [
        'profileImageUrl',
        'photoUrl',
        'image',
      ]);

      final rating = (data['rating'] ?? 0.0).toDouble();

      uniqueTrainers[doc.id] = InstructorData(
        id: doc.id,
        name: name.isNotEmpty ? name : 'Trainer',
        emoji: emoji.isNotEmpty ? emoji : '\u{1F393}',
        imageUrl: imageUrl,
        rating: rating,
      );
    }

    for (final doc in querySnapshot.docs) {
      addTrainerFromDoc(doc);
    }
    for (final doc in instructorSnapshot.docs) {
      addTrainerFromDoc(doc);
    }
    for (final doc in legacySnapshot.docs) {
      addTrainerFromDoc(doc);
    }

    final trainers = uniqueTrainers.values.toList();
    trainers.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return trainers;
  }

  Future<List<InstructorData>> getTrainersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    // Firestore 'in' query supports up to 10-30 IDs depending on version, 
    // but here we might have more. For now, we'll fetch all and filter or do chunked.
    // Given it's a prototype, we can fetch all and filter for now if the list is small,
    // or use a more targeted approach.
    final all = await getTrainers();
    return all.where((t) => ids.contains(t.id)).toList();
  }

  Future<List<Map<String, dynamic>>> getTrainerRevenueList() async {
    final querySnapshot = await _db
        .collection('bharatam_users')
        .where('role', isEqualTo: 'trainer')
        .get();

    final instructorSnapshot = await _db
        .collection('bharatam_users')
        .where('role', isEqualTo: 'Instructor')
        .get();

    final legacySnapshot = await _db.collection('trainers').get();
    final purchasesSnapshot = await _db.collection('purchases').get();

    final Map<String, Map<String, dynamic>> trainerMap = {};

    void addTrainerData(String id, Map<String, dynamic> data) {
      trainerMap[id] = {
        'id': id,
        'name': data['name'] ?? 'Unknown',
        'phone': data['phoneNumber'] ?? '',
        'bankName': data['bankName'] ?? '',
        'bankAccount': data['bankAccount'] ?? data['accountNumber'] ?? '',
        'ifscCode': data['ifscCode'] ?? '',
        'upiId': data['upiId'] ?? '',
      };
    }

    for (var doc in legacySnapshot.docs) {
      addTrainerData(doc.id, doc.data());
    }
    for (var doc in querySnapshot.docs) {
      addTrainerData(doc.id, doc.data());
    }
    for (var doc in instructorSnapshot.docs) {
      addTrainerData(doc.id, doc.data());
    }

    final List<Map<String, dynamic>> result = [];

    for (var trainerId in trainerMap.keys) {
      final trainerData = trainerMap[trainerId]!;
      double totalRevenue = 0;
      for (var purchaseDoc in purchasesSnapshot.docs) {
        final purchaseData = purchaseDoc.data();
        if (purchaseData['trainerId'] == trainerId) {
          totalRevenue += (purchaseData['trainerShare'] ?? 0).toDouble();
        }
      }
      trainerData['totalRevenue'] = totalRevenue;
      result.add(trainerData);
    }

    return result;
  }

  String _readFirstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
