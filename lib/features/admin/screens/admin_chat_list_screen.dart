import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/chat_service.dart';
import '../../../../widgets/animations.dart';
import 'admin_chat_screen.dart';

class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({super.key});

  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  final _chatService = ChatService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      final hrs = difference.inHours;
      return '$hrs ${hrs == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 2) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Student Support Inbox'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFE65100),
                Color(0xFFFF8F00),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Premium Search Bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.subtle,
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase().trim();
                    });
                  },
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by student name or number...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: AppColors.textHint),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder(
              stream: _chatService.getChatListStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading inbox: ${snapshot.error}', style: TextStyle(color: AppColors.error)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chats = snapshot.data ?? [];
                
                // Filter docs based on search query (name or phone number)
                final filteredChats = chats.where((chat) {
                  final name = chat.studentName.toLowerCase();
                  final phone = chat.studentPhone.toLowerCase();
                  return name.contains(_searchQuery) || phone.contains(_searchQuery);
                }).toList();

                if (filteredChats.isEmpty) {
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
                              Icons.question_answer_rounded,
                              size: 54,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            _searchQuery.isNotEmpty ? 'No Matching Chats' : 'Inbox Empty',
                            style: AppTextStyles.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No student chats found matching "$_searchQuery".'
                                : 'When students start a support chat, their conversations will list here in real-time.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    final String studentId = chat.studentId;
                    final String studentName = chat.studentName;
                    final String studentPhone = chat.studentPhone;
                    final String lastMessage = chat.lastMessage;
                    final bool unread = chat.unreadByAdmin;
                    final DateTime lastTime = chat.lastMessageTime;

                    return FadeSlideIn(
                      delay: Duration(milliseconds: 50 * index),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadows.subtle,
                          border: Border.all(
                            color: unread ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
                            width: unread ? 1.5 : 1.0,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminChatScreen(
                                    studentId: studentId,
                                    studentName: studentName,
                                    studentPhone: studentPhone,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: unread 
                                          ? AppColors.primary.withValues(alpha: 0.1) 
                                          : AppColors.background,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                        style: TextStyle(
                                          color: unread ? AppColors.primary : AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                studentName,
                                                style: AppTextStyles.titleMedium.copyWith(
                                                  fontWeight: unread ? FontWeight.bold : FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatRelativeTime(lastTime),
                                              style: AppTextStyles.bodySmall.copyWith(
                                                fontSize: 11,
                                                color: unread ? AppColors.primary : AppColors.textHint,
                                                fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '+91 $studentPhone',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          lastMessage,
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            color: unread ? AppColors.textPrimary : AppColors.textSecondary,
                                            fontWeight: unread ? FontWeight.w500 : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  if (unread) ...[
                                    const SizedBox(width: AppSpacing.md),
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
