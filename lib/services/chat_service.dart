import 'package:firebase_database/firebase_database.dart';

class ChatConversation {
  final String key;
  final String studentId;
  final String studentName;
  final String studentPhone;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool unreadByAdmin;
  final bool unreadByStudent;

  const ChatConversation({
    required this.key,
    required this.studentId,
    required this.studentName,
    required this.studentPhone,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadByAdmin,
    required this.unreadByStudent,
  });
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String message;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.timestamp,
  });
}

class ChatService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  DatabaseReference get _chatsRef => _db.ref('supportChats');

  String _chatKey(String studentId) {
    return studentId.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
  }

  String _stringValue(Map<dynamic, dynamic> data, String key, [String fallback = '']) {
    return (data[key] ?? fallback).toString();
  }

  bool _boolValue(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  int _intValue(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime _dateFromMillis(int millis) {
    if (millis <= 0) return DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Sends a message and updates the live chat metadata in Firebase Realtime Database.
  Future<void> sendMessage({
    required String studentId,
    required String studentName,
    required String studentPhone,
    required String message,
    required String senderId,
    required String senderName,
    required String senderRole,
  }) async {
    final chatRef = _chatsRef.child(_chatKey(studentId));
    final messageRef = chatRef.child('messages').push();
    final now = ServerValue.timestamp;

    await chatRef.child('metadata').update({
      'studentId': studentId,
      'studentName': studentName,
      'studentPhone': studentPhone,
      'lastMessage': message,
      'lastMessageTime': now,
      if (senderRole == 'student') 'unreadByAdmin': true,
      if (senderRole == 'admin') 'unreadByStudent': true,
    });

    await messageRef.set({
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': message,
      'timestamp': now,
    });
  }

  /// Listens to real-time message changes for a specific student conversation.
  Stream<List<ChatMessage>> getMessagesStream(String studentId) {
    return _chatsRef
        .child(_chatKey(studentId))
        .child('messages')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final messages = <ChatMessage>[];
      for (final child in event.snapshot.children) {
        final raw = child.value;
        if (raw is! Map) continue;
        final data = Map<dynamic, dynamic>.from(raw);
        messages.add(ChatMessage(
          id: child.key ?? '',
          senderId: _stringValue(data, 'senderId'),
          senderName: _stringValue(data, 'senderName'),
          senderRole: _stringValue(data, 'senderRole'),
          message: _stringValue(data, 'message'),
          timestamp: _dateFromMillis(_intValue(data, 'timestamp')),
        ));
      }
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  /// Listens to real-time changes of all chats for the Admin view.
  Stream<List<ChatConversation>> getChatListStream() {
    return _chatsRef.orderByChild('metadata/lastMessageTime').onValue.map((event) {
      final chats = <ChatConversation>[];
      for (final child in event.snapshot.children) {
        final raw = child.child('metadata').value;
        if (raw is! Map) continue;
        final data = Map<dynamic, dynamic>.from(raw);
        chats.add(ChatConversation(
          key: child.key ?? '',
          studentId: _stringValue(data, 'studentId', child.key ?? ''),
          studentName: _stringValue(data, 'studentName', 'Student'),
          studentPhone: _stringValue(data, 'studentPhone', 'Unknown'),
          lastMessage: _stringValue(data, 'lastMessage'),
          lastMessageTime: _dateFromMillis(_intValue(data, 'lastMessageTime')),
          unreadByAdmin: _boolValue(data, 'unreadByAdmin'),
          unreadByStudent: _boolValue(data, 'unreadByStudent'),
        ));
      }
      chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return chats;
    });
  }

  /// Marks the conversation as read by the admin or student.
  Future<void> markAsRead(String studentId, bool isAdmin) async {
    final updateData = isAdmin 
        ? {'unreadByAdmin': false} 
        : {'unreadByStudent': false};

    await _chatsRef.child(_chatKey(studentId)).child('metadata').update(updateData);
  }
}
