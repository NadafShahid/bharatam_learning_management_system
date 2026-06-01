import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';

class CourseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Static cache for trainer names — persists across multiple getCourseList calls
  static final Map<String, String> _trainerNamesCache = {};

  bool _isApprovedCourseData(Map<String, dynamic> data) {
    final status = data['approvalStatus']?.toString().toLowerCase();
    if (status == 'approved') return true;
    if (status == 'pending' || status == 'rejected' || status == 'draft') {
      return false;
    }
    if (data['isApproved'] is bool) return data['isApproved'] as bool;
    return data['isApproved']?.toString().toLowerCase() == 'true';
  }

  bool _needsCourseApproval(Map<String, dynamic> data) {
    final status = data['approvalStatus']?.toString().toLowerCase();
    if (status == 'pending') return true;
    if (status == 'draft' || status == 'rejected') return false;
    return !_isApprovedCourseData(data);
  }

  /// Lightweight real-time stream of courses — maps only top-level fields.
  /// Does NOT read subcollections (modules/videos/pdfs).
  /// Use this on the home screen for fast load + automatic Firestore updates.
  Stream<List<CourseModel>> getCourseListStream() {
    return _db
        .collection('bharatam_courses')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) => _mapCoursesLightweight(snapshot.docs));
  }

  /// One-shot lightweight fetch — same as getCourseListStream but async/await.
  /// Use this when you need a quick initial load without subscribing to changes.
  Future<List<CourseModel>> getCourseList() async {
    final snapshot = await _db
        .collection('bharatam_courses')
        .where('isApproved', isEqualTo: true)
        .get();
    return _mapCoursesLightweight(snapshot.docs);
  }

  /// Fetches a single course by its ID, fully populated with modules, videos, and PDFs.
  Future<CourseModel?> getCourseById(String courseId) async {
    try {
      final snapshot = await _db
          .collection('bharatam_courses')
          .where(FieldPath.documentId, isEqualTo: courseId)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final courseData = snapshot.docs.first.data();
      if (!_isApprovedCourseData(courseData)) return null;
      final courses = await _mapCourses(snapshot.docs, onlyApprovedContent: true);
      return courses.isNotEmpty ? courses.first : null;
    } catch (e) {
      print('Error in getCourseById: $e');
      return null;
    }
  }


  /// Maps course documents using ONLY top-level fields — no subcollection reads.
  /// Provides trainer name resolution with a persistent cache.
  Future<List<CourseModel>> _mapCoursesLightweight(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final courses = <CourseModel>[];

    // Collect all trainer IDs that need name resolution
    final unresolvedIds = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      final trainerName = data['trainerName'] as String? ?? '';
      final trainerId = data['trainerId'] as String? ?? '';
      if ((trainerName.isEmpty || trainerName == 'Trainer' || trainerName == 'Unknown') &&
          trainerId.isNotEmpty &&
          !_trainerNamesCache.containsKey(trainerId)) {
        unresolvedIds.add(trainerId);
      }
    }

    // Batch-resolve trainer names (one read per unique unresolved trainer)
    for (final trainerId in unresolvedIds) {
      try {
        var tDoc = await _db.collection('bharatam_users').doc(trainerId).get();
        if (tDoc.exists) {
          final d = tDoc.data()!;
          _trainerNamesCache[trainerId] =
              d['name'] ?? d['displayName'] ?? d['fullName'] ?? 'Trainer';
        } else {
          tDoc = await _db.collection('bharatam_trainers').doc(trainerId).get();
          if (tDoc.exists) {
            final d = tDoc.data()!;
            _trainerNamesCache[trainerId] =
                d['name'] ?? d['displayName'] ?? d['fullName'] ?? 'Trainer';
          }
        }
      } catch (_) {
        _trainerNamesCache[trainerId] = 'Trainer';
      }
    }

    for (final doc in docs) {
      try {
        final data = doc.data();
        final trainerId = data['trainerId'] as String? ?? '';
        String trainerName = data['trainerName'] as String? ?? 'Trainer';
        if ((trainerName.isEmpty || trainerName == 'Trainer' || trainerName == 'Unknown') &&
            trainerId.isNotEmpty) {
          trainerName = _trainerNamesCache[trainerId] ?? trainerName;
        }

        final isApprovedVal = _isApprovedCourseData(data);

        DateTime? createdAtVal;
        if (data['createdAt'] is Timestamp) {
          createdAtVal = (data['createdAt'] as Timestamp).toDate();
        } else if (data['createdAt'] is int) {
          createdAtVal = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
        } else if (data['createdAt'] != null) {
          createdAtVal = DateTime.tryParse(data['createdAt'].toString());
        }

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

        courses.add(CourseModel(
          id: doc.id,
          title: data['courseName'] ?? data['title'] ?? '',
          description: data['description'] ?? '',
          category: data['category'] ?? '',
          price: priceVal,
          emoji: data['emoji'] ?? CourseModel.emojiForCategory(data['category'] ?? ''),
          thumbnailUrl: data['thumbnailUrl'] ?? '',
          trainerId: trainerId,
          trainerName: trainerName,
          isApproved: isApprovedVal,
          createdAt: createdAtVal,
          // modules and standaloneVideos are intentionally empty here —
          // they are loaded on demand when the course detail screen opens.
          modules: const [],
          standaloneVideos: const [],
          limitedTimePrice: limited,
          oneTimePrice: oneTime,
          lifetimePrice: lifetime,
          limitedTimeDays: data['limitedTimeDays'] != null
              ? int.tryParse(data['limitedTimeDays'].toString())
              : null,
          views: data['views'] is int ? data['views'] as int : (int.tryParse(data['views']?.toString() ?? '') ?? 0),
        ));
      } catch (e, stack) {
        print('Error mapping lightweight course ${doc.id}: $e\n$stack');
      }
    }

    courses.sort((a, b) {
      final viewsCompare = b.views.compareTo(a.views);
      if (viewsCompare != 0) return viewsCompare;
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return courses;
  }

  Future<List<CourseModel>> getCourses() async {
    final querySnapshot = await _db
        .collection('bharatam_courses')
        .get();
    
    final approvedDocs = querySnapshot.docs
        .where((doc) => _isApprovedCourseData(doc.data()))
        .toList();
    final courses = await _mapCourses(approvedDocs, onlyApprovedContent: true);
    return courses;
  }

  Future<List<CourseModel>> getCoursesByTrainer(String trainerId) async {
    final querySnapshot = await _db
        .collection('bharatam_courses')
        .where('trainerId', isEqualTo: trainerId)
        .get();
    return _mapCourses(querySnapshot.docs);
  }

  Future<List<CourseModel>> getAllCoursesForAdmin() async {
    final querySnapshot = await _db.collection('bharatam_courses').get();
    return _mapCourses(querySnapshot.docs);
  }

  Future<List<CourseModel>> getPendingCourses() async {
    final querySnapshot = await _db
        .collection('bharatam_courses')
        .where('isApproved', isEqualTo: false)
        .get();
    final pendingDocs = querySnapshot.docs
        .where((doc) => _needsCourseApproval(doc.data()))
        .toList();
    return _mapCourses(pendingDocs);
  }

  Future<List<CourseApprovalItem>> getCourseApprovalQueue() async {
    final querySnapshot = await _db.collection('bharatam_courses').get();
    final courses = await _mapCourses(querySnapshot.docs);
    final coursesById = {for (final course in courses) course.id: course};
    final items = <CourseApprovalItem>[];

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final course = coursesById[doc.id];
      if (course == null) continue;

      final pendingVideosSnapshot = await doc.reference
          .collection('videos')
          .where('approvalStatus', isEqualTo: 'pending')
          .get();
      final pendingPdfsSnapshot = await doc.reference
          .collection('pdfs')
          .where('approvalStatus', isEqualTo: 'pending')
          .get();

      final needsCourseApproval = _needsCourseApproval(data);
      final pendingVideoCount = pendingVideosSnapshot.size;
      final pendingPdfCount = pendingPdfsSnapshot.size;

      if (needsCourseApproval || pendingVideoCount > 0 || pendingPdfCount > 0) {
        items.add(CourseApprovalItem(
          course: course,
          needsCourseApproval: needsCourseApproval,
          pendingVideoCount: pendingVideoCount,
          pendingPdfCount: pendingPdfCount,
        ));
      }
    }

    items.sort((a, b) {
      if (a.needsCourseApproval != b.needsCourseApproval) {
        return a.needsCourseApproval ? -1 : 1;
      }
      return a.course.category.compareTo(b.course.category);
    });
    return items;
  }

  Future<List<VideoModel>> getPendingContent() async {
    // To avoid requiring a collectionGroup index, we fetch all courses
    // and then query each course's 'videos' subcollection for pending content.
    final coursesSnapshot = await _db.collection('bharatam_courses').get();
    final pendingVideos = <VideoModel>[];
    final trainerNamesCache = <String, String>{};

    for (final courseDoc in coursesSnapshot.docs) {
      final videosSnapshot = await courseDoc.reference
          .collection('videos')
          .where('approvalStatus', isEqualTo: 'pending')
          .get();
          
      String trainerName = courseDoc.data()['trainerName'] ?? 'Unknown';
      final trainerId = courseDoc.data()['trainerId'] as String?;

      if ((trainerName == 'Trainer' || trainerName == 'Unknown') && trainerId != null && trainerId.isNotEmpty) {
        if (trainerNamesCache.containsKey(trainerId)) {
          trainerName = trainerNamesCache[trainerId]!;
        } else {
          try {
            var tDoc = await _db.collection('bharatam_users').doc(trainerId).get();
            if (tDoc.exists) {
              final tData = tDoc.data()!;
              trainerName = tData['name'] ?? tData['displayName'] ?? tData['fullName'] ?? trainerName;
            } else {
              tDoc = await _db.collection('bharatam_trainers').doc(trainerId).get();
              if (tDoc.exists) {
                final tData = tDoc.data()!;
                trainerName = tData['name'] ?? tData['displayName'] ?? tData['fullName'] ?? trainerName;
              }
            }
            trainerNamesCache[trainerId] = trainerName;
          } catch (e) {
            // keep default
          }
        }
      }

      for (final videoDoc in videosSnapshot.docs) {
        pendingVideos.add(_videoFromDoc(videoDoc.id, videoDoc.data(), courseId: courseDoc.id, trainerName: trainerName));
      }
      
      final pdfsSnapshot = await courseDoc.reference
          .collection('pdfs')
          .where('approvalStatus', isEqualTo: 'pending')
          .get();
          
      for (final pdfDoc in pdfsSnapshot.docs) {
        pendingVideos.add(_videoFromDoc(pdfDoc.id, pdfDoc.data(), courseId: courseDoc.id, trainerName: trainerName));
      }
    }

    return pendingVideos;
  }

  Future<String> createCourse({
    required String title,
    required String description,
    required String category,
    required double price,
    required String trainerId,
    required String trainerName,
    bool isApproved = false,
    String thumbnailUrl = '',
    String? approvalStatus,
    double? limitedTimePrice,
    double? oneTimePrice,
    double? lifetimePrice,
    int? limitedTimeDays,
  }) async {
    String finalTrainerName = trainerName;
    if ((finalTrainerName == 'Trainer' || finalTrainerName == 'Unknown') && trainerId.isNotEmpty) {
      try {
        var trainerDoc = await _db.collection('bharatam_users').doc(trainerId).get();
        if (trainerDoc.exists) {
          final data = trainerDoc.data()!;
          finalTrainerName = data['name'] ?? data['displayName'] ?? data['fullName'] ?? finalTrainerName;
        } else {
          trainerDoc = await _db.collection('bharatam_trainers').doc(trainerId).get();
          if (trainerDoc.exists) {
            final data = trainerDoc.data()!;
            finalTrainerName = data['name'] ?? data['displayName'] ?? data['fullName'] ?? finalTrainerName;
          }
        }
      } catch (e) {
        // keep default
      }
    }

    final doc = await _db.collection('bharatam_courses').add({
      'courseName': title,
      'description': description,
      'category': category,
      'limitedTimePrice': limitedTimePrice,
      'oneTimePrice': oneTimePrice,
      'lifetimePrice': lifetimePrice,
      'limitedTimeDays': limitedTimeDays,
      'thumbnailUrl': thumbnailUrl,
      'trainerId': trainerId,
      'trainerName': finalTrainerName,
      'isApproved': isApproved,
      'approvalStatus': approvalStatus ?? (isApproved ? 'approved' : 'pending'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateCourse({
    required String courseId,
    required String title,
    required String description,
    required String category,
    required double price,
    required String thumbnailUrl,
    String? approvalStatus,
    double? limitedTimePrice,
    double? oneTimePrice,
    double? lifetimePrice,
    int? limitedTimeDays,
  }) async {
    final Map<String, dynamic> data = {
      'courseName': title,
      'description': description,
      'category': category,
      'limitedTimePrice': limitedTimePrice,
      'oneTimePrice': oneTimePrice,
      'lifetimePrice': lifetimePrice,
      'limitedTimeDays': limitedTimeDays,
      'thumbnailUrl': thumbnailUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (approvalStatus != null) {
      data['approvalStatus'] = approvalStatus;
    }
    await _db.collection('bharatam_courses').doc(courseId).update(data);
  }

  Future<void> approveCourse(String courseId) async {
    final courseRef = _db.collection('bharatam_courses').doc(courseId);
    final pendingVideos = await courseRef
        .collection('videos')
        .where('approvalStatus', isEqualTo: 'pending')
        .get();
    final pendingPdfs = await courseRef
        .collection('pdfs')
        .where('approvalStatus', isEqualTo: 'pending')
        .get();

    final batch = _db.batch();
    batch.update(courseRef, {
      'isApproved': true,
      'approvalStatus': 'approved',
      'contentApprovalStatus': 'approved',
      'hasPendingContent': false,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final doc in [...pendingVideos.docs, ...pendingPdfs.docs]) {
      batch.update(doc.reference, {
        'approvalStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> rejectCourse(String courseId, {String? reason}) async {
    final courseRef = _db.collection('bharatam_courses').doc(courseId);
    final courseSnapshot = await courseRef.get();
    final data = courseSnapshot.data() ?? {};

    if (_isApprovedCourseData(data)) {
      final pendingVideos = await courseRef
          .collection('videos')
          .where('approvalStatus', isEqualTo: 'pending')
          .get();
      final pendingPdfs = await courseRef
          .collection('pdfs')
          .where('approvalStatus', isEqualTo: 'pending')
          .get();

      final batch = _db.batch();
      batch.update(courseRef, {
        'contentApprovalStatus': 'rejected',
        'hasPendingContent': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final doc in [...pendingVideos.docs, ...pendingPdfs.docs]) {
        batch.update(doc.reference, {
          'approvalStatus': 'rejected',
          'rejectionReason': reason ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return;
    }

    await courseRef.update({
      'isApproved': false,
      'approvalStatus': 'rejected',
      'rejectionReason': reason ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveContent(String courseId, String contentId, CourseContentType contentType) async {
    final subcollection = contentType == CourseContentType.pdf ? 'pdfs' : 'videos';
    await _db
        .collection('bharatam_courses')
        .doc(courseId)
        .collection(subcollection)
        .doc(contentId)
        .update({
      'approvalStatus': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _refreshCourseContentApprovalState(courseId);
  }

  Future<void> rejectContent(String courseId, String contentId, CourseContentType contentType, {String? reason}) async {
    final subcollection = contentType == CourseContentType.pdf ? 'pdfs' : 'videos';
    await _db
        .collection('bharatam_courses')
        .doc(courseId)
        .collection(subcollection)
        .doc(contentId)
        .update({
      'approvalStatus': 'rejected',
      'rejectionReason': reason ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _refreshCourseContentApprovalState(courseId);
  }

  Future<void> uploadCourseContent({
    required String courseId,
    required String title,
    required CourseContentType contentType,
    required String storageUrl,
    String fileName = '',
    String bunnyVideoId = '',
    String? moduleId,
    double durationMinutes = 0,
    double? price,
    bool isFree = false,
    int order = 0,
    bool autoApprove = false,
    String thumbnailUrl = '',
  }) async {
    final subcollection = contentType == CourseContentType.pdf ? 'pdfs' : 'videos';

    // Auto-compute order: count existing docs in the subcollection so that
    // 1st upload → order 1, 2nd → order 2, etc.
    // If caller explicitly passes a positive order value, use that instead.
    int computedOrder = order;
    if (computedOrder <= 0) {
      final existingSnapshot = await _db
          .collection('bharatam_courses')
          .doc(courseId)
          .collection(subcollection)
          .get();
      computedOrder = existingSnapshot.size + 1;
    }

    await _db.collection('bharatam_courses').doc(courseId).collection(subcollection).add({
      'title': title,
      'contentType': contentType == CourseContentType.pdf ? 'pdf' : 'video',
      'storageUrl': storageUrl,
      'fileName': fileName,
      'bunnyVideoId': bunnyVideoId,
      'durationMinutes': durationMinutes,
      'isFree': isFree,
      'order': computedOrder,
      'status': 'active',
      'approvalStatus': autoApprove ? 'approved' : 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'views': 0,
      'thumbnailUrl': thumbnailUrl,
    });

    await _db.collection('bharatam_courses').doc(courseId).update({
      'hasPendingContent': !autoApprove,
      'contentApprovalStatus': autoApprove ? 'approved' : 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _refreshCourseContentApprovalState(String courseId) async {
    final courseRef = _db.collection('bharatam_courses').doc(courseId);
    final pendingVideos = await courseRef
        .collection('videos')
        .where('approvalStatus', isEqualTo: 'pending')
        .limit(1)
        .get();
    final pendingPdfs = await courseRef
        .collection('pdfs')
        .where('approvalStatus', isEqualTo: 'pending')
        .limit(1)
        .get();
    final hasPendingContent = pendingVideos.docs.isNotEmpty || pendingPdfs.docs.isNotEmpty;
    await courseRef.update({
      'hasPendingContent': hasPendingContent,
      'contentApprovalStatus': hasPendingContent ? 'pending' : 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementVideoViews(String courseId, String videoId, int incrementBy) async {
    final ref = _db.collection('bharatam_courses').doc(courseId).collection('videos').doc(videoId);
    await ref.update({
      'views': FieldValue.increment(incrementBy),
    });
  }

  Future<void> incrementCourseViews(String courseId, int incrementBy) async {
    final ref = _db.collection('bharatam_courses').doc(courseId);
    await ref.update({
      'views': FieldValue.increment(incrementBy),
    });
  }

  /// Fetches all videos (or PDFs) for a course from Firestore,
  /// ordered by the `order` field ascending.
  Future<List<VideoModel>> getCourseVideos(String courseId, {bool isPdf = false}) async {
    final subcollection = isPdf ? 'pdfs' : 'videos';
    final snapshot = await _db
        .collection('bharatam_courses')
        .doc(courseId)
        .collection(subcollection)
        .orderBy('order')
        .get();
    return snapshot.docs
        .map((doc) => _videoFromDoc(doc.id, doc.data(), courseId: courseId))
        .toList();
  }

  /// Batch-updates the `order` field for each video in [orderedVideoIds].
  /// The first ID in the list gets order=1, the second order=2, and so on.
  /// [contentType] selects whether to write to the 'videos' or 'pdfs' subcollection.
  Future<void> updateVideoOrder({
    required String courseId,
    required List<String> orderedVideoIds,
    CourseContentType contentType = CourseContentType.video,
  }) async {
    final subcollection = contentType == CourseContentType.pdf ? 'pdfs' : 'videos';
    final courseRef = _db.collection('bharatam_courses').doc(courseId);
    final batch = _db.batch();
    for (int i = 0; i < orderedVideoIds.length; i++) {
      final docRef = courseRef.collection(subcollection).doc(orderedVideoIds[i]);
      batch.update(docRef, {
        'order': i + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteCourse(String courseId) async {
    await _db.collection('bharatam_courses').doc(courseId).delete();
  }

  Future<List<CourseModel>> _mapCourses(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    bool onlyApprovedContent = false,
  }) async {
    final courses = <CourseModel>[];
    final trainerNamesCache = <String, String>{};

    for (final doc in docs) {
      try {
        final data = doc.data();
        
        String trainerName = data['trainerName'] ?? 'Unknown';
        final trainerId = data['trainerId'] as String?;

        if ((trainerName == 'Trainer' || trainerName == 'Unknown') && trainerId != null && trainerId.isNotEmpty) {
          if (trainerNamesCache.containsKey(trainerId)) {
            trainerName = trainerNamesCache[trainerId]!;
          } else {
            try {
              var tDoc = await _db.collection('bharatam_users').doc(trainerId).get();
              if (tDoc.exists) {
                final tData = tDoc.data()!;
                trainerName = tData['name'] ?? tData['displayName'] ?? tData['fullName'] ?? trainerName;
              } else {
                tDoc = await _db.collection('bharatam_trainers').doc(trainerId).get();
                if (tDoc.exists) {
                  final tData = tDoc.data()!;
                  trainerName = tData['name'] ?? tData['displayName'] ?? tData['fullName'] ?? trainerName;
                }
              }
              trainerNamesCache[trainerId] = trainerName;
            } catch (e) {
              // keep default
            }
          }
        }

        final modulesSnapshot =
            await doc.reference.collection('modules').orderBy('order').get();
        final modules = <ModuleModel>[];

        // Fetch all videos and pdfs for this course once
        final allVideosSnapshot = await doc.reference.collection('videos').get();
        final allPdfsSnapshot = await doc.reference.collection('pdfs').get();
        
        final allContentList = [
          ...allVideosSnapshot.docs.map((vDoc) => _videoFromDoc(vDoc.id, vDoc.data(), courseId: doc.id, trainerName: trainerName)),
          ...allPdfsSnapshot.docs.map((pDoc) => _videoFromDoc(pDoc.id, pDoc.data(), courseId: doc.id, trainerName: trainerName))
        ];

        final allVideos = allContentList
            .where((video) => !onlyApprovedContent || video.approvalStatus == ApprovalStatus.approved)
            .toList();

        for (final modDoc in modulesSnapshot.docs) {
          final modData = modDoc.data();
          
          final moduleVideos = allVideos.where((v) => v.moduleId == modDoc.id).toList();
          
          // Sort by order locally
          moduleVideos.sort((a, b) => a.order.compareTo(b.order));

          modules.add(ModuleModel(
            id: modDoc.id,
            title: modData['title'] ?? '',
            order: modData['order'] ?? 0,
            price: modData['price'] != null ? double.tryParse(modData['price'].toString()) : null,
            videos: moduleVideos,
          ));
        }

        final standaloneVideos = allVideos
            .where((v) => v.moduleId.isEmpty)
            .toList();
        standaloneVideos.sort((a, b) => a.order.compareTo(b.order));

        final isApprovedVal = _isApprovedCourseData(data);

        DateTime? createdAtVal;
        if (data['createdAt'] is Timestamp) {
          createdAtVal = (data['createdAt'] as Timestamp).toDate();
        } else if (data['createdAt'] is int) {
          createdAtVal = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
        } else if (data['createdAt'] != null) {
          createdAtVal = DateTime.tryParse(data['createdAt'].toString());
        }

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

        courses.add(CourseModel(
          id: doc.id,
          title: data['courseName'] ?? data['title'] ?? '',
          description: data['description'] ?? '',
          category: data['category'] ?? '',
          price: priceVal,
          emoji: data['emoji'] ?? CourseModel.emojiForCategory(data['category'] ?? ''),
          thumbnailUrl: data['thumbnailUrl'] ?? '',
          trainerId: trainerId ?? '',
          trainerName: trainerName,
          isApproved: isApprovedVal,
          createdAt: createdAtVal,
          modules: modules,
          standaloneVideos: standaloneVideos,
          limitedTimePrice: limited,
          oneTimePrice: oneTime,
          lifetimePrice: lifetime,
          limitedTimeDays: data['limitedTimeDays'] != null ? int.tryParse(data['limitedTimeDays'].toString()) : null,
          views: data['views'] is int ? data['views'] as int : (int.tryParse(data['views']?.toString() ?? '') ?? 0),
        ));
      } catch (e, stack) {
        print('Error mapping course document ${doc.id}: $e\n$stack');
      }
    }

    courses.sort((a, b) {
      final viewsCompare = b.views.compareTo(a.views);
      if (viewsCompare != 0) return viewsCompare;
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return courses;
  }

  VideoModel _videoFromDoc(String id, Map<String, dynamic> data, {String courseId = '', String trainerName = ''}) {
    final approvalStatus = switch (data['approvalStatus']) {
      'pending' => ApprovalStatus.pending,
      'rejected' => ApprovalStatus.rejected,
      _ => ApprovalStatus.approved,
    };

    bool isFreeVal = false;
    if (data['isFree'] is bool) {
      isFreeVal = data['isFree'] as bool;
    } else if (data['isFree'] != null) {
      isFreeVal = data['isFree'].toString().toLowerCase() == 'true';
    }

    DateTime? createdAtVal;
    if (data['createdAt'] is Timestamp) {
      createdAtVal = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is int) {
      createdAtVal = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
    } else if (data['createdAt'] != null) {
      createdAtVal = DateTime.tryParse(data['createdAt'].toString());
    }

    return VideoModel(
      id: id,
      title: data['title'] ?? '',
      bunnyVideoId: data['bunnyVideoId'] ?? '',
      courseId: courseId,
      moduleId: data['moduleId'] ?? '',
      order: data['order'] is int ? data['order'] as int : (int.tryParse(data['order']?.toString() ?? '') ?? 0),
      trainerName: trainerName,
      storageUrl: data['storageUrl'] ?? '',
      fileName: data['fileName'] ?? '',
      contentType:
          data['contentType'] == 'pdf' ? CourseContentType.pdf : CourseContentType.video,
      approvalStatus: approvalStatus,
      durationMinutes: data['durationMinutes'] != null ? (double.tryParse(data['durationMinutes'].toString()) ?? 0.0) : 0.0,
      isFree: isFreeVal,
      price: data['price'] != null ? double.tryParse(data['price'].toString()) : null,
      status: (data['status'] == 'deleted')
          ? VideoStatus.deleted
          : VideoStatus.active,
      createdAt: createdAtVal,
      views: data['views'] is int ? data['views'] as int : (int.tryParse(data['views']?.toString() ?? '') ?? 0),
      thumbnailUrl: data['thumbnailUrl'] ?? '',
    );
  }

  String _emojiForCategory(String category) {
    return CourseModel.emojiForCategory(category);
  }

  Future<void> updateVideoDuration(String courseId, String videoId, double durationMinutes, {bool isPdf = false}) async {
    final subcollection = isPdf ? 'pdfs' : 'videos';
    await _db
        .collection('bharatam_courses')
        .doc(courseId)
        .collection(subcollection)
        .doc(videoId)
        .update({
      'durationMinutes': durationMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class CourseApprovalItem {
  final CourseModel course;
  final bool needsCourseApproval;
  final int pendingVideoCount;
  final int pendingPdfCount;

  const CourseApprovalItem({
    required this.course,
    required this.needsCourseApproval,
    required this.pendingVideoCount,
    required this.pendingPdfCount,
  });

  int get pendingContentCount => pendingVideoCount + pendingPdfCount;
  bool get isContentUpdate => !needsCourseApproval && pendingContentCount > 0;
}
