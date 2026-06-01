import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryService {
  CategoryService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const List<String> fallbackCategories = [
    'Vedic Math',
    'Sanskrit',
    'History',
    'Yoga',
    'Mathematics',
    'Language',
    'Science',
    'Philosophy',
    'Arts',
  ];

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _db.collection('bharatam_categories');

  Stream<List<String>> watchCategories() {
    return _categoriesRef
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => _normalizeCategories(snapshot.docs
            .map((doc) => doc.data()['name']?.toString() ?? '')
            .toList()));
  }

  Future<List<String>> getCategories() async {
    final snapshot = await _categoriesRef.where('isActive', isEqualTo: true).get();
    return _normalizeCategories(snapshot.docs
        .map((doc) => doc.data()['name']?.toString() ?? '')
        .toList());
  }

  Future<void> addCategory(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Category name is required');
    }

    final normalizedName = cleanName.toLowerCase();
    final existing = await _categoriesRef
        .where('normalizedName', isEqualTo: normalizedName)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      await doc.reference.update({
        'name': cleanName,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await _categoriesRef.add({
      'name': cleanName,
      'normalizedName': normalizedName,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<String> _normalizeCategories(List<String> categories) {
    final unique = <String, String>{};
    for (final category in categories) {
      final clean = category.trim();
      if (clean.isEmpty) continue;
      unique.putIfAbsent(clean.toLowerCase(), () => clean);
    }

    final sorted = unique.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }
}
