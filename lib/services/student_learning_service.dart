import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_models.dart';

class LectureRatingSummary {
  final double average;
  final int count;

  const LectureRatingSummary({
    required this.average,
    required this.count,
  });
}

class StudentLearningService {
  // Testing phase: keep student ratings and certificates visible without
  // requiring actual video playback/completion. Set this to false for release.
  static const bool testingBypassCompletionGate = false;

  static const _storage = FlutterSecureStorage();
  static final _db = FirebaseFirestore.instance;
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static final Map<String, Set<String>> _completedVideos = {};
  static final Map<String, DateTime> _courseCompletionDates = {};
  static final Map<String, int> _studentRatings = {};
  static final Map<String, List<int>> _ratingPool = {
    'v001': [5, 5, 4, 5, 4],
    'v002': [4, 5, 4, 4],
    'v003': [5, 4, 4],
    'v004': [5, 5, 5, 4],
    'v005': [4, 4, 5],
    'v006': [5, 4, 5],
    'v007': [4, 5],
    'v008': [5, 5, 4],
    'v_stand_1': [5, 4, 4],
    'v_stand_2': [4, 5],
  };

  // ── userId cache ─────────────────────────────────────────────────────────
  // Reads from secure storage where LoginScreen already wrote key='userId'.
  // No extra Firestore query needed.
  static String? _cachedUserId;

  static void setCachedUserId(String? id) {
    _cachedUserId = id;
  }

  Future<String?> _getUserId() async {
    if (_cachedUserId != null && _cachedUserId!.isNotEmpty) return _cachedUserId;
    try {
      final id = await _storage.read(key: 'userId');
      if (id != null && id.isNotEmpty) {
        // Bypass accounts — no Firestore sync
        if (id == 'bypass_student' || id == 'bypass_trainer') return null;
        _cachedUserId = id;
        return id;
      }
    } catch (e) {
      debugPrint('StudentLearningService._getUserId: $e');
    }
    return null;
  }

  static void clearCachedUserId() {
    _cachedUserId = null;
  }

  // ── Firestore path ────────────────────────────────────────────────────────
  static DocumentReference<Map<String, dynamic>> _progressDoc(
          String userId, String courseId) =>
      _db
          .collection('student_progress')
          .doc(userId)
          .collection('courses')
          .doc(courseId);

  // ── Load / Reload ────────────────────────────────────────────────────────

  Future<void> loadCourse(String courseId) async {
    // Use cached in-memory data if already loaded in this session
    if (_completedVideos.containsKey(courseId)) return;
    await _loadCourseData(courseId);
  }

  /// Forces a fresh re-read from Firestore (primary) or local storage (fallback).
  /// Always call this when returning to a list screen so fresh completion
  /// status is guaranteed.
  Future<void> reloadCourse(String courseId) async {
    _completedVideos.remove(courseId);
    _courseCompletionDates.remove(courseId);
    _studentRatings.removeWhere((k, _) => k.startsWith('$courseId:'));
    await _loadCourseData(courseId);
  }

  Future<void> _loadCourseData(String courseId) async {
    // ── 1. Try Firestore (source of truth) ───────────────────────────────
    try {
      final userId = await _getUserId();
      if (userId != null) {
        final doc = await _progressDoc(userId, courseId).get();
        if (doc.exists) {
          final data = doc.data()!;
          final rawList = (data['completedVideos'] as List<dynamic>?) ?? [];
          _completedVideos[courseId] =
              rawList.map((e) => e.toString()).toSet();

          final completedAt = data['completedAt'];
          if (completedAt is Timestamp) {
            _courseCompletionDates[courseId] = completedAt.toDate();
          }

          // Mirror Firestore data back to local storage to keep them in sync
          await _storage.write(
            key: _completedVideosKey(courseId),
            value: jsonEncode(_completedVideos[courseId]!.toList()),
          );
          if (_courseCompletionDates.containsKey(courseId)) {
            await _storage.write(
              key: _courseCompletionKey(courseId),
              value: _courseCompletionDates[courseId]!.toIso8601String(),
            );
          }

          // Ratings are still local
          _loadRatingsFromStorage(courseId);
          return;
        }
      }
    } catch (e) {
      debugPrint('StudentLearningService: Firestore load error for $courseId: $e');
    }

    // ── 2. Fallback: local secure storage ────────────────────────────────
    final completedRaw =
        await _storage.read(key: _completedVideosKey(courseId));
    final completedList = completedRaw == null
        ? <String>[]
        : List<String>.from(jsonDecode(completedRaw) as List);
    _completedVideos[courseId] = completedList.toSet();

    final completionRaw =
        await _storage.read(key: _courseCompletionKey(courseId));
    if (completionRaw != null) {
      _courseCompletionDates[courseId] = DateTime.parse(completionRaw);
    }

    _loadRatingsFromStorage(courseId);
  }

  void _loadRatingsFromStorage(String courseId) async {
    try {
      final ratingsRaw = await _storage.read(key: _ratingsKey(courseId));
      if (ratingsRaw != null) {
        final decoded =
            Map<String, dynamic>.from(jsonDecode(ratingsRaw) as Map);
        decoded.forEach((videoId, rating) {
          _studentRatings[_ratingKey(courseId, videoId)] = rating as int;
        });
      }
    } catch (_) {}
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  bool isVideoCompleted(String courseId, String videoId) {
    return _completedVideos[courseId]?.contains(videoId) ?? false;
  }

  bool isCourseCompleted(String courseId, int totalVideos,
      {PurchaseRecord? purchase, int? limitedTimeDays}) {
    if (testingBypassCompletionGate) return true;
    if (purchase != null && purchase.planType == 'limited') {
      final days = limitedTimeDays ?? 30;
      final elapsedDays =
          DateTime.now().difference(purchase.purchasedAt).inDays;
      final completed = elapsedDays >= (days / 2);
      if (completed && !_courseCompletionDates.containsKey(courseId)) {
        final compDate =
            purchase.purchasedAt.add(Duration(days: days ~/ 2));
        _courseCompletionDates[courseId] = compDate;
      }
      return completed;
    }
    if (totalVideos == 0) return false;
    return (_completedVideos[courseId]?.length ?? 0) >= totalVideos;
  }

  int completedCount(String courseId) {
    return _completedVideos[courseId]?.length ?? 0;
  }

  DateTime? courseCompletionDate(String courseId) {
    return _courseCompletionDates[courseId];
  }

  // ── Mark complete ─────────────────────────────────────────────────────────

  Future<bool> completeVideo({
    required String courseId,
    required String videoId,
    required int totalVideos,
    PurchaseRecord? purchase,
    int? limitedTimeDays,
  }) async {
    final completed =
        _completedVideos.putIfAbsent(courseId, () => <String>{});
    final wasAdded = completed.add(videoId);
    if (!wasAdded) {
      return isCourseCompleted(courseId, totalVideos,
          purchase: purchase, limitedTimeDays: limitedTimeDays);
    }

    // 1. Local storage — fast, works offline
    await _storage.write(
      key: _completedVideosKey(courseId),
      value: jsonEncode(completed.toList()),
    );

    DateTime? completionDate;
    final isCourseNowDone =
        completed.length >= totalVideos;
    if (isCourseNowDone &&
        !_courseCompletionDates.containsKey(courseId)) {
      completionDate = DateTime.now();
      _courseCompletionDates[courseId] = completionDate;
      await _storage.write(
        key: _courseCompletionKey(courseId),
        value: completionDate.toIso8601String(),
      );
    }

    // 2. Firestore — persistent, cross-device (fire-and-forget)
    _syncProgressToFirestore(
      courseId: courseId,
      completedVideos: Set<String>.from(completed),
      totalVideos: totalVideos,
      completionDate: completionDate ?? _courseCompletionDates[courseId],
      isCompleted: isCourseNowDone,
    );

    changes.value++;
    return isCourseCompleted(courseId, totalVideos,
        purchase: purchase, limitedTimeDays: limitedTimeDays);
  }

  void _syncProgressToFirestore({
    required String courseId,
    required Set<String> completedVideos,
    required int totalVideos,
    required bool isCompleted,
    DateTime? completionDate,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return;

      final data = <String, dynamic>{
        'completedVideos': completedVideos.toList(),
        'completedCount': completedVideos.length,
        'totalVideos': totalVideos,
        'isCompleted': isCompleted,
        'lastUpdated': FieldValue.serverTimestamp(),
        'userId': userId,
        'courseId': courseId,
      };

      if (isCompleted && completionDate != null) {
        data['completedAt'] = Timestamp.fromDate(completionDate);
      }

      await _progressDoc(userId, courseId)
          .set(data, SetOptions(merge: true));

      debugPrint(
        'StudentLearningService: synced $courseId '
        '(${completedVideos.length}/$totalVideos, done=$isCompleted)',
      );
    } catch (e) {
      debugPrint('StudentLearningService: Firestore sync error: $e');
    }
  }

  // ── Ratings ───────────────────────────────────────────────────────────────

  int? studentRating(String courseId, String videoId) {
    return _studentRatings[_ratingKey(courseId, videoId)];
  }

  Future<void> submitRating({
    required String courseId,
    required String videoId,
    required int rating,
  }) async {
    final key = _ratingKey(courseId, videoId);
    final previous = _studentRatings[key];
    final pool = _ratingPool.putIfAbsent(videoId, () => <int>[]);
    if (previous != null) {
      final index = pool.indexOf(previous);
      if (index != -1) pool[index] = rating;
    } else {
      pool.add(rating);
    }
    _studentRatings[key] = rating;

    final ratingsForCourse = <String, int>{};
    _studentRatings.forEach((storedKey, value) {
      if (storedKey.startsWith('$courseId:')) {
        ratingsForCourse[storedKey.substring(courseId.length + 1)] = value;
      }
    });

    await _storage.write(
      key: _ratingsKey(courseId),
      value: jsonEncode(ratingsForCourse),
    );
    changes.value++;
  }

  LectureRatingSummary ratingSummary(String videoId) {
    final ratings = _ratingPool[videoId] ?? const <int>[];
    if (ratings.isEmpty) {
      return const LectureRatingSummary(average: 0, count: 0);
    }
    final total = ratings.fold<int>(0, (sum, r) => sum + r);
    return LectureRatingSummary(
      average: total / ratings.length,
      count: ratings.length,
    );
  }

  // ── Storage keys ──────────────────────────────────────────────────────────

  static String _completedVideosKey(String courseId) =>
      'learning_completed_videos_$courseId';

  static String _courseCompletionKey(String courseId) =>
      'learning_course_completed_at_$courseId';

  static String _ratingsKey(String courseId) =>
      'learning_ratings_$courseId';

  static String _ratingKey(String courseId, String videoId) =>
      '$courseId:$videoId';
}
