import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/app_models.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../../core/localization.dart';

class StudentChatScreen extends StatefulWidget {
  const StudentChatScreen({super.key});

  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends State<StudentChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChatService();
  
  UserModel? _currentUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      const storage = FlutterSecureStorage();
      final phone = await storage.read(key: 'userPhone');
      if (phone != null) {
        final userService = UserService();
        final user = await userService.getUserByPhone(phone);
        if (mounted) {
          setState(() {
            _currentUser = user;
            _isLoadingUser = false;
          });
          // Mark messages as read when entering
          if (user != null) {
            _chatService.markAsRead(user.id, false);
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingUser = false);
        }
      }
    } catch (e) {
      debugPrint('Error fetching user details for chat: $e');
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    HapticFeedback.lightImpact();
    _messageController.clear();

    try {
      await _chatService.sendMessage(
        studentId: _currentUser!.id,
        studentName: _currentUser!.name.isNotEmpty ? _currentUser!.name : 'Student',
        studentPhone: _currentUser!.phoneNumber,
        message: text,
        senderId: _currentUser!.id,
        senderName: _currentUser!.name.isNotEmpty ? _currentUser!.name : 'Student',
        senderRole: 'student',
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, locale, child) {
        if (_isLoadingUser) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Text(T.get('support_chat')),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_currentUser == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Text(T.get('support_chat')),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_person_rounded, size: 64, color: AppColors.textHint),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      T.get('access_denied'),
                      style: AppTextStyles.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      T.get('please_login_chat'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFE65100), // deep orange
                    Color(0xFFFF8F00), // amber orange
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22E65100),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      )
                    else
                      const SizedBox(width: AppSpacing.lg),
                    const CircleAvatar(
                      backgroundColor: Colors.white24,
                      radius: 20,
                      child: Text('🎓', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            T.get('bharatam_support_chat'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            T.get('ask_anything_online'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder(
                  stream: _chatService.getMessagesStream(_currentUser!.id),
                  builder: (context, snapshot) {
                    // Clear any local unread notifications when a message arrives
                    _chatService.markAsRead(_currentUser!.id, false);

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Something went wrong: ${snapshot.error}'),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data ?? [];
                    
                    if (messages.isEmpty) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.xxl),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 54,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                T.get('start_conversation'),
                                style: AppTextStyles.headlineSmall,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                T.get('chat_intro_desc'),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Scroll to bottom on new messages
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                    return ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final chatMessage = messages[index];
                        final bool isMe = chatMessage.senderRole == 'student';
                        
                        final timeStr = DateFormat('hh:mm a').format(chatMessage.timestamp);

                        return _buildMessageBubble(
                          message: chatMessage.message,
                          time: timeStr,
                          isMe: isMe,
                          senderName: chatMessage.senderName,
                        );
                      },
                    );
                  },
                ),
              ),
              _buildMessageInput(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required String time,
    required bool isMe,
    required String senderName,
  }) {
    final Alignment bubbleAlignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final double leftPadding = isMe ? 50.0 : 0.0;
    final double rightPadding = isMe ? 0.0 : 50.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      alignment: bubbleAlignment,
      child: Padding(
        padding: EdgeInsets.only(left: leftPadding, right: rightPadding),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  T.get('support_admin'),
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMe ? AppGradients.primary : null,
                color: isMe ? null : AppColors.surface,
                boxShadow: AppShadows.subtle,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.md),
                  topRight: const Radius.circular(AppRadius.md),
                  bottomLeft: isMe ? const Radius.circular(AppRadius.md) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(AppRadius.md),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                time,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.xl,
        top: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.bottomNav,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: 4,
                  minLines: 1,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: T.get('type_message_hint'),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33FF6A3D),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
