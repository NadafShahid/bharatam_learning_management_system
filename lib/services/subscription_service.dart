import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  Future<void> subscribe(String trainerId) async {
    final userId = _userService.currentUserId;
    await _db.collection('subscribe').doc('${userId}_$trainerId').set({
      'userId': userId,
      'trainerId': trainerId,
      'subscribedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unsubscribe(String trainerId) async {
    final userId = _userService.currentUserId;
    await _db.collection('subscribe').doc('${userId}_$trainerId').delete();
  }

  Future<bool> isSubscribed(String trainerId) async {
    final userId = _userService.currentUserId;
    final doc = await _db.collection('subscribe').doc('${userId}_$trainerId').get();
    return doc.exists;
  }

  Future<List<String>> getSubscribedTrainerIds() async {
    final userId = _userService.currentUserId;
    final snapshot = await _db
        .collection('subscribe')
        .where('userId', isEqualTo: userId)
        .get();
    
    return snapshot.docs.map((doc) => doc.data()['trainerId'] as String).toList();
  }

  Future<int> getSubscriberCount(String trainerId) async {
    final snapshot = await _db
        .collection('subscribe')
        .where('trainerId', isEqualTo: trainerId)
        .get();
    return snapshot.docs.length;
  }
}
