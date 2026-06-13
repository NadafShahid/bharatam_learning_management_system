import 'package:cloud_firestore/cloud_firestore.dart';

/// One-time Firestore database seeder.
/// Creates all collections with initial/sample documents
/// matching the optimized Bharatam LMS schema.
class FirestoreSeed {
  static final _db = FirebaseFirestore.instance;

  /// Run the full seed — call once to set up the DB structure.
  static Future<void> seedAll() async {
    await _seedPlatformConfig();
    await _seedUsers();
    await _seedCourses();
    await _seedPurchases();
    await _seedTrainerPayouts();
    await _seedCertificates();
    await _seedTrainerWallet();
  }

  // ─── 1. PLATFORM CONFIG ──────────────────────────────────────

  static Future<void> _seedPlatformConfig() async {
    await _db.collection('platform_config').doc('settings').set({
      'commissionPercent': 20,
      'minWithdrawalThreshold': 1000,
      'freeUploadLimit': 5,
      'perVideoUploadPrice': 49,
      'monthlyPlanPrice': 499,
      'categories': [
        'Mathematics',
        'Language',
        'Science',
        'Arts',
        'Yoga & Wellness',
        'Philosophy',
        'History',
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── 2. USERS ────────────────────────────────────────────────

  static Future<void> _seedUsers() async {
    final usersRef = _db.collection('learners');
    final bharatamUsersRef = _db.collection('bharatam_users');

    // --- Admin ---
    final adminData = {
      'phoneNumber': '+919999900000',
      'name': 'Super Admin',
      'role': 'admin',
      'profileImageUrl': '',
      'isBlocked': false,
      'preferredLanguage': 'en',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await usersRef.doc('admin_001').set(adminData);
    await bharatamUsersRef.doc('admin_001').set(adminData);

    // --- Trainer ---
    final trainersRef = _db.collection('trainers');
    final trainerData = {
      'phoneNumber': '+919876543210',
      'name': 'Dr. Sharma',
      'role': 'trainer',
      'profileImageUrl': '',
      'isBlocked': false,
      'preferredLanguage': 'en',
      'specialization': 'Vedic Mathematics',
      'bankAccount': 'XXXX-XXXX-1234',
      'ifscCode': 'SBIN0001234',
      'uploadPlan': 'free',
      'freeUploadsUsed': 3,
      'totalStudents': 342,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await trainersRef.doc('trainer_001').set(trainerData);
    await _db.collection('bharatam_trainers').doc('trainer_001').set(trainerData);
    await bharatamUsersRef.doc('trainer_001').set(trainerData);

    // --- Student ---
    final studentData = {
      'phoneNumber': '+919876512345',
      'name': 'Arjun Bhardwaj',
      'role': 'student',
      'profileImageUrl': '',
      'isBlocked': false,
      'preferredLanguage': 'en',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await usersRef.doc('student_001').set(studentData);
    await bharatamUsersRef.doc('student_001').set(studentData);

    // --- Student enrollment (subcollection) ---
    await usersRef
        .doc('student_001')
        .collection('enrollments')
        .doc('course_001')
        .set({
      'accessType': 'module',
      'unlockedModuleIds': ['mod_001'],
      'unlockedVideoIds': [],
      'progress': {
        'completedVideoIds': ['v001', 'v002'],
        'lastWatchedVideoId': 'v002',
      },
      'isCompleted': false,
      'enrolledAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── 3. COURSES ──────────────────────────────────────────────

  static Future<void> _seedCourses() async {
    final coursesRef = _db.collection('bharatam_courses');

    // --- Course 1: Vedic Mathematics ---
    final course1Ref = coursesRef.doc('course_001');
    await course1Ref.set({
      'courseName': 'Vedic Mathematics Masterclass',
      'description':
          'This course takes you on a journey through classical Indian knowledge. '
          'Designed for all learners with interactive exercises, quizzes, and practical applications. '
          'Earn a verified certificate upon completion.',
      'category': 'Mathematics',
      'price': 1499,
      'trainerId': 'trainer_001',
      'trainerName': 'Dr. Sharma',
      'isApproved': true,
      'approvalStatus': 'approved',
      'rejectionReason': '',
      'isDraft': false,
      'totalVideos': 10,
      'totalDurationMinutes': 153.14,
      'totalStudents': 342,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Modules for Course 1
    final modulesRef = course1Ref.collection('modules');
    await modulesRef.doc('mod_001').set({
      'title': 'Introduction & Basics',
      'order': 1,
      'price': 299,
    });
    await modulesRef.doc('mod_002').set({
      'title': 'Core Techniques',
      'order': 2,
      'price': 499,
    });
    await modulesRef.doc('mod_003').set({
      'title': 'Advanced Applications',
      'order': 3,
      'price': 599,
    });

    // Videos for Course 1
    final videosRef = course1Ref.collection('videos');

    // Module 1 videos
    await videosRef.doc('v001').set({
      'title': 'Welcome & Overview',
      'moduleId': 'mod_001',
      'bunnyVideoId': '',
      'durationMinutes': 12.5,
      'isFree': true,
      'price': null,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 1,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    await videosRef.doc('v002').set({
      'title': 'History and Origins',
      'moduleId': 'mod_001',
      'bunnyVideoId': '',
      'durationMinutes': 18.75,
      'isFree': true,
      'price': null,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 2,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    await videosRef.doc('v003').set({
      'title': 'Number Systems',
      'moduleId': 'mod_001',
      'bunnyVideoId': '',
      'durationMinutes': 22.15,
      'isFree': false,
      'price': 49,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 3,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    // Module 2 videos
    await videosRef.doc('v004').set({
      'title': 'Quick Multiplication',
      'moduleId': 'mod_002',
      'bunnyVideoId': '',
      'durationMinutes': 25.0,
      'isFree': false,
      'price': 79,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 1,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    await videosRef.doc('v005').set({
      'title': 'Division Shortcuts',
      'moduleId': 'mod_002',
      'bunnyVideoId': '',
      'durationMinutes': 20.25,
      'isFree': false,
      'price': 79,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 2,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    await videosRef.doc('v006').set({
      'title': 'Squaring Methods',
      'moduleId': 'mod_002',
      'bunnyVideoId': '',
      'durationMinutes': 28.5,
      'isFree': false,
      'price': 79,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 3,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    // Module 3 videos
    await videosRef.doc('v007').set({
      'title': 'Competitive Exam Tricks',
      'moduleId': 'mod_003',
      'bunnyVideoId': '',
      'durationMinutes': 15.66,
      'isFree': false,
      'price': 99,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 1,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    await videosRef.doc('v008').set({
      'title': 'Real-World Use Cases',
      'moduleId': 'mod_003',
      'bunnyVideoId': '',
      'durationMinutes': 10.33,
      'isFree': false,
      'price': 99,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 2,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    // Standalone videos (moduleId = null)
    await videosRef.doc('v_stand_1').set({
      'title': 'Course Introduction (Free)',
      'moduleId': null,
      'bunnyVideoId': '',
      'durationMinutes': 5.5,
      'isFree': true,
      'price': null,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 100,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    await videosRef.doc('v_stand_2').set({
      'title': 'Bonus: Secrets of Mental Math',
      'moduleId': null,
      'bunnyVideoId': '',
      'durationMinutes': 12.0,
      'isFree': false,
      'price': 99,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 101,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    // --- Course 2: Sanskrit Grammar ---
    final course2Ref = coursesRef.doc('course_002');
    await course2Ref.set({
      'courseName': 'Sanskrit Grammar Basics',
      'description':
          'Learn the fundamentals of Sanskrit grammar through structured lessons.',
      'category': 'Language',
      'price': 999,
      'trainerId': 'trainer_001',
      'trainerName': 'Dr. Sharma',
      'isApproved': true,
      'approvalStatus': 'pending',
      'rejectionReason': '',
      'isDraft': false,
      'totalVideos': 2,
      'totalDurationMinutes': 35.0,
      'totalStudents': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await course2Ref.collection('modules').doc('mod_004').set({
      'title': 'Alphabets & Pronunciation',
      'order': 1,
      'price': 199,
    });

    await course2Ref.collection('videos').doc('v009').set({
      'title': 'Vowels & Consonants',
      'moduleId': 'mod_004',
      'bunnyVideoId': '',
      'durationMinutes': 15,
      'isFree': true,
      'price': null,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 1,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    await course2Ref.collection('videos').doc('v010').set({
      'title': 'Compound Letters',
      'moduleId': 'mod_004',
      'bunnyVideoId': '',
      'durationMinutes': 20,
      'isFree': false,
      'price': 49,
      'status': 'active',
      'approvalStatus': 'approved',
      'order': 2,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── 4. PURCHASES ────────────────────────────────────────────

  static Future<void> _seedPurchases() async {
    await _db.collection('purchases').doc('purchase_001').set({
      'userId': 'student_001',
      'courseId': 'course_001',
      'moduleId': 'mod_001',
      'videoId': null,
      'purchaseType': 'module',
      'amountPaid': 299,
      'trainerId': 'trainer_001',
      'trainerShare': 239.20,
      'platformCommission': 59.80,
      'transactionId': 'TXN98765',
      'status': 'success',
      'purchasedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── 5. TRAINER PAYOUTS ──────────────────────────────────────

  static Future<void> _seedTrainerPayouts() async {
    await _db.collection('trainer_payouts').doc('payout_001').set({
      'trainerId': 'trainer_001',
      'amount': 5000,
      'bankAccount': 'XXXX-XXXX-1234',
      'ifscCode': 'SBIN0001234',
      'status': 'processed',
      'requestedAt': FieldValue.serverTimestamp(),
      'processedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── 6. CERTIFICATES ────────────────────────────────────────

  static Future<void> _seedCertificates() async {
    await _db.collection('certificates').doc('cert_001').set({
      'userId': 'student_001',
      'userName': 'Arjun Bhardwaj',
      'courseId': 'course_001',
      'courseName': 'Vedic Mathematics Masterclass',
      'issuedAt': FieldValue.serverTimestamp(),
      'certificateUrl': '',
    });
  }

  // ─── 7. WALLET & TRANSACTIONS ────────────────────────────────
  static Future<void> _seedTrainerWallet() async {
    // Seed wallet for trainer_001
    await _db.collection('bharatam_wallets').doc('trainer_001').set({
      'trainerId': 'trainer_001',
      'balance': 239.20,
      'totalEarnings': 239.20,
      'totalWithdrawn': 0.0,
      'pendingWithdrawal': 0.0,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Seed ledger transaction matching purchase_001 (trainer share: 239.20)
    await _db.collection('bharatam_wallet_transactions').doc('ledger_001').set({
      'trainerId': 'trainer_001',
      'amount': 239.20,
      'type': 'earnings_credit',
      'status': 'completed',
      'referenceId': 'purchase_001',
      'description': 'Earnings from Vedic Mathematics Masterclass (Module)',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
