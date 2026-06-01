import 'package:cloud_firestore/cloud_firestore.dart';

class Advertisement {
  final String id;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String badgeText;
  final DateTime? createdAt;
  final bool isActive;

  Advertisement({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.badgeText = 'SPECIAL OFFER',
    this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'badgeText': badgeText,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }

  factory Advertisement.fromMap(Map<String, dynamic> data, String id) {
    return Advertisement(
      id: id,
      imageUrl: data['imageUrl'] ?? '',
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      badgeText: data['badgeText'] ?? 'SPECIAL OFFER',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
    );
  }
}

class AdService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addAdvertisement(Advertisement ad) async {
    await _db.collection('advertisements').add(ad.toMap());
  }

  Future<List<Advertisement>> getAdvertisements() async {
    final snapshot = await _db
        .collection('advertisements')
        .where('isActive', isEqualTo: true)
        .get();
    
    final list = snapshot.docs.map((doc) => Advertisement.fromMap(doc.data(), doc.id)).toList();
    list.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return list;
  }

  Future<void> deleteAdvertisement(String id) async {
    await _db.collection('advertisements').doc(id).delete();
  }

  Future<void> toggleAdStatus(String id, bool isActive) async {
    await _db.collection('advertisements').doc(id).update({'isActive': isActive});
  }
}
