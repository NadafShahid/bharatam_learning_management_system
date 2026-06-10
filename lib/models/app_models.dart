/// Conceptual data models for Bharatam LMS.
/// These drive UI rendering and access-control logic without a backend.
library;

enum PurchaseType { course, module, video }
enum VideoStatus { active, deleted }
enum TrainerPlan { free, perVideo, monthly }
enum CourseContentType { video, pdf }
enum ApprovalStatus { pending, approved, rejected }

class UserModel {
  final String id;
  final String name;
  final String phoneNumber;
  final String role;
  final String profileImageUrl;
  final bool isBlocked;
  final String preferredLanguage;
  final String bankName;
  final String bankAccount;
  final String ifscCode;
  final String upiId;

  const UserModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.role,
    this.profileImageUrl = '',
    this.isBlocked = false,
    this.preferredLanguage = 'en',
    this.bankName = '',
    this.bankAccount = '',
    this.ifscCode = '',
    this.upiId = '',
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      role: map['role'] ?? 'student',
      profileImageUrl: map['profileImageUrl'] ?? '',
      isBlocked: map['isBlocked'] ?? false,
      preferredLanguage: map['preferredLanguage'] ?? 'en',
      bankName: map['bankName'] ?? '',
      bankAccount: map['bankAccount'] ?? map['accountNumber'] ?? '',
      ifscCode: map['ifscCode'] ?? '',
      upiId: map['upiId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'isBlocked': isBlocked,
      'preferredLanguage': preferredLanguage,
      'bankName': bankName,
      'bankAccount': bankAccount,
      'bankaccount': bankAccount, // Alias for lowercase matching
      'ifscCode': ifscCode,
      'upiId': upiId,
    };
  }
}

class CourseModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final String emoji;
  final String trainerId;
  final String trainerName;
  final bool isApproved;
  final String thumbnailUrl;
  final DateTime? createdAt;
  final List<ModuleModel> modules;
  final List<VideoModel> standaloneVideos;
  final double? limitedTimePrice;
  final double? oneTimePrice;
  final double? lifetimePrice;
  final int? limitedTimeDays;
  final int views;

  const CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.emoji,
    required this.trainerId,
    required this.trainerName,
    this.isApproved = false,
    this.thumbnailUrl = '',
    this.createdAt,
    this.modules = const [],
    this.standaloneVideos = const [],
    this.limitedTimePrice,
    this.oneTimePrice,
    this.lifetimePrice,
    this.limitedTimeDays,
    this.views = 0,
  });

  static String emojiForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('math')) return '🔢';
    if (lower.contains('sanskrit') || lower.contains('language')) return '📜';
    if (lower.contains('yoga')) return '🧘';
    if (lower.contains('history')) return '🏛️';
    return '📚';
  }

  double get totalDurationMinutes {
    double total = 0;
    for (final m in modules) {
      for (final v in m.videos) {
        total += v.durationMinutes;
      }
    }
    for (final v in standaloneVideos) {
      total += v.durationMinutes;
    }
    return total;
  }

  int get totalVideos {
    int total = 0;
    for (final m in modules) {
      total += m.videos.length;
    }
    total += standaloneVideos.length;
    return total;
  }

  CourseModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? price,
    String? emoji,
    String? trainerId,
    String? trainerName,
    bool? isApproved,
    String? thumbnailUrl,
    DateTime? createdAt,
    List<ModuleModel>? modules,
    List<VideoModel>? standaloneVideos,
    double? limitedTimePrice,
    double? oneTimePrice,
    double? lifetimePrice,
    int? limitedTimeDays,
    int? views,
  }) {
    return CourseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      emoji: emoji ?? this.emoji,
      trainerId: trainerId ?? this.trainerId,
      trainerName: trainerName ?? this.trainerName,
      isApproved: isApproved ?? this.isApproved,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      modules: modules ?? this.modules,
      standaloneVideos: standaloneVideos ?? this.standaloneVideos,
      limitedTimePrice: limitedTimePrice ?? this.limitedTimePrice,
      oneTimePrice: oneTimePrice ?? this.oneTimePrice,
      lifetimePrice: lifetimePrice ?? this.lifetimePrice,
      limitedTimeDays: limitedTimeDays ?? this.limitedTimeDays,
      views: views ?? this.views,
    );
  }
}

class TrainerStats {
  final double totalEarnings;
  final int totalStudents;
  final int totalCourses;
  final List<CourseModel> recentCourses;
  final List<PurchaseRecord> recentPurchases;

  const TrainerStats({
    required this.totalEarnings,
    required this.totalStudents,
    required this.totalCourses,
    this.recentCourses = const [],
    this.recentPurchases = const [],
  });
}

class ModuleModel {
  final String id;
  final String title;
  final int order;
  final double? price; // null = only available via full course
  final List<VideoModel> videos;

  const ModuleModel({
    required this.id,
    required this.title,
    required this.order,
    this.price,
    this.videos = const [],
  });

  ModuleModel copyWith({
    String? id,
    String? title,
    int? order,
    double? price,
    List<VideoModel>? videos,
  }) {
    return ModuleModel(
      id: id ?? this.id,
      title: title ?? this.title,
      order: order ?? this.order,
      price: price ?? this.price,
      videos: videos ?? this.videos,
    );
  }
}

class VideoModel {
  final String id;
  final String title;
  final String bunnyVideoId;
  final String courseId;
  final String moduleId;
  final int order;
  final String trainerName;
  final String storageUrl;
  final String fileName;
  final CourseContentType contentType;
  final ApprovalStatus approvalStatus;
  final double durationMinutes;
  final bool isFree;
  final double? price; // null = only available via module/course
  final VideoStatus status;
  final DateTime? createdAt;
  final int views;
  final String thumbnailUrl;

  const VideoModel({
    required this.id,
    required this.title,
    this.bunnyVideoId = '',
    this.courseId = '',
    this.moduleId = '',
    this.order = 0,
    this.trainerName = '',
    this.storageUrl = '',
    this.fileName = '',
    this.contentType = CourseContentType.video,
    this.approvalStatus = ApprovalStatus.approved,
    required this.durationMinutes,
    this.isFree = false,
    this.price,
    this.status = VideoStatus.active,
    this.createdAt,
    this.views = 0,
    this.thumbnailUrl = '',
  });

  String get durationFormatted {
    final mins = durationMinutes.toInt();
    final secs = ((durationMinutes - mins) * 60).toInt();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  VideoModel copyWith({
    String? id,
    String? title,
    String? bunnyVideoId,
    String? courseId,
    String? moduleId,
    int? order,
    String? trainerName,
    String? storageUrl,
    String? fileName,
    CourseContentType? contentType,
    ApprovalStatus? approvalStatus,
    double? durationMinutes,
    bool? isFree,
    double? price,
    VideoStatus? status,
    DateTime? createdAt,
    int? views,
    String? thumbnailUrl,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      bunnyVideoId: bunnyVideoId ?? this.bunnyVideoId,
      courseId: courseId ?? this.courseId,
      moduleId: moduleId ?? this.moduleId,
      order: order ?? this.order,
      trainerName: trainerName ?? this.trainerName,
      storageUrl: storageUrl ?? this.storageUrl,
      fileName: fileName ?? this.fileName,
      contentType: contentType ?? this.contentType,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isFree: isFree ?? this.isFree,
      price: price ?? this.price,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      views: views ?? this.views,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  String get resolvedThumbnailUrl {
    if (thumbnailUrl.isNotEmpty) {
      return thumbnailUrl;
    }
    if (bunnyVideoId.isNotEmpty) {
      return 'https://vz-5549fe19-18c.b-cdn.net/$bunnyVideoId/thumbnail.jpg';
    }
    if (storageUrl.isNotEmpty && storageUrl.contains('vz-5549fe19-18c.b-cdn.net')) {
      final uri = Uri.tryParse(storageUrl);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final videoId = uri.pathSegments.first;
        return 'https://vz-5549fe19-18c.b-cdn.net/$videoId/thumbnail.jpg';
      }
    }
    return '';
  }
}

class PurchaseRecord {
  final String userId;
  final String courseId;
  final String? moduleId;
  final String? videoId;
  final PurchaseType purchaseType;
  final DateTime purchasedAt;
  final double amountPaid;
  final double trainerShare;
  final String transactionId;
  final String trainerId;
  final String status;
  final String? planType; // 'limited', 'onetime', 'lifetime'

  const PurchaseRecord({
    required this.userId,
    required this.courseId,
    this.moduleId,
    this.videoId,
    required this.purchaseType,
    required this.purchasedAt,
    this.amountPaid = 0.0,
    this.trainerShare = 0.0,
    this.transactionId = '',
    this.trainerId = '',
    this.status = 'success',
    this.planType,
  });
}

/// Access-control helper: determines if a user can play a video.
class AccessControl {
  final List<PurchaseRecord> purchases;

  const AccessControl({this.purchases = const []});

  bool canPlayVideo({
    required VideoModel video,
    required String courseId,
    String? moduleId,
  }) {
    if (video.isFree) return true;

    for (final p in purchases) {
      // Full course purchase
      if (p.courseId == courseId && p.purchaseType == PurchaseType.course) {
        // Apply secure expiration verification logic for subscription plans
        if (p.planType == 'limited') {
          final difference = DateTime.now().difference(p.purchasedAt).inDays;
          if (difference > 30) continue; // Expired!
        } else if (p.planType == 'onetime') {
          final difference = DateTime.now().difference(p.purchasedAt).inDays;
          if (difference > 365) continue; // Expired!
        }
        return true;
      }
      // Module purchase
      if (moduleId != null &&
          p.courseId == courseId &&
          p.moduleId == moduleId &&
          p.purchaseType == PurchaseType.module) {
        return true;
      }
      // Single video purchase
      if (p.courseId == courseId &&
          p.videoId == video.id &&
          p.purchaseType == PurchaseType.video) {
        return true;
      }
    }
    return false;
  }
}

/// Dummy data for the entire app prototype.
class DummyData {
  static const currentUserId = 'user_001';

  static final demoCourse = CourseModel(
    id: 'course_001',
    title: 'Vedic Mathematics Masterclass',
    description:
        'This course takes you on a journey through classical Indian knowledge. '
        'Designed for all learners with interactive exercises, quizzes, and practical applications. '
        'Earn a verified certificate upon completion.',
    category: 'Mathematics',
    price: 1499,
    emoji: '🔢',
    trainerId: 'trainer_001',
    trainerName: 'Dr. Sharma',
    isApproved: true,
    modules: [
      ModuleModel(
        id: 'mod_001',
        title: 'Introduction & Basics',
        order: 1,
        price: 299,
        videos: [
          VideoModel(id: 'v001', title: 'Welcome & Overview', durationMinutes: 12.5, isFree: true),
          VideoModel(id: 'v002', title: 'History and Origins', durationMinutes: 18.75, isFree: true),
          VideoModel(id: 'v003', title: 'Number Systems', durationMinutes: 22.15, price: 49),
        ],
      ),
      ModuleModel(
        id: 'mod_002',
        title: 'Core Techniques',
        order: 2,
        price: 499,
        videos: [
          VideoModel(id: 'v004', title: 'Quick Multiplication', durationMinutes: 25.0, price: 79),
          VideoModel(id: 'v005', title: 'Division Shortcuts', durationMinutes: 20.25, price: 79),
          VideoModel(id: 'v006', title: 'Squaring Methods', durationMinutes: 28.5, price: 79),
        ],
      ),
      ModuleModel(
        id: 'mod_003',
        title: 'Advanced Applications',
        order: 3,
        price: 599,
        videos: [
          VideoModel(id: 'v007', title: 'Competitive Exam Tricks', durationMinutes: 15.66, price: 99),
          VideoModel(id: 'v008', title: 'Real-World Use Cases', durationMinutes: 10.33, price: 99),
        ],
      ),
    ],
    standaloneVideos: [
      VideoModel(
        id: 'v_stand_1',
        title: 'Course Introduction (Free)',
        durationMinutes: 5.5,
        isFree: true,
      ),
      VideoModel(
        id: 'v_stand_2',
        title: 'Bonus: Secrets of Mental Math',
        durationMinutes: 12.0,
        price: 99,
      ),
    ],
  );

  static final demoCourse2 = CourseModel(
    id: 'course_002',
    title: 'Sanskrit Grammar Basics',
    description: 'Learn the fundamentals of Sanskrit grammar through structured lessons.',
    category: 'Language',
    price: 999,
    emoji: '📜',
    trainerId: 'trainer_001',
    trainerName: 'Acharya Raj',
    isApproved: true,
    modules: [
      ModuleModel(
        id: 'mod_004',
        title: 'Alphabets & Pronunciation',
        order: 1,
        price: 199,
        videos: [
          VideoModel(id: 'v009', title: 'Vowels & Consonants', durationMinutes: 15, isFree: true),
          VideoModel(id: 'v010', title: 'Compound Letters', durationMinutes: 20, price: 49),
        ],
      ),
    ],
  );

  static final trainerVideoCount = 3; // simulates 3 of 5 free uploads used

  static final userPurchases = <PurchaseRecord>[
    // User has purchased module 1 of Vedic Math
    PurchaseRecord(
      userId: currentUserId,
      courseId: 'course_001',
      moduleId: 'mod_001',
      purchaseType: PurchaseType.module,
      purchasedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];
}
