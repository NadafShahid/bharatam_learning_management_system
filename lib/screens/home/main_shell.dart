import 'package:flutter/material.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../home/home_screen.dart';
import '../chat/student_chat_screen.dart';
import 'my_trainers_feed_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/localization.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  // Each screen wrapped in RepaintBoundary to isolate tab repaints
  // and avoid OPlus IJankManager scene-tracking mismatches
  static const _screens = [
    RepaintBoundary(child: HomeScreen()),
    RepaintBoundary(child: StudentChatScreen()),
    RepaintBoundary(child: MyTrainersFeedScreen()),
    RepaintBoundary(child: ProfileScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, locale, child) {
        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final isForward = _currentIndex > _previousIndex;
              final slideIn = Tween<Offset>(
                begin: Offset(isForward ? 0.04 : -0.04, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ));

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: slideIn,
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: _screens[_currentIndex],
            ),
          ),
          bottomNavigationBar: AppBottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index != _currentIndex) {
                setState(() {
                  _previousIndex = _currentIndex;
                  _currentIndex = index;
                });
              }
            },
          ),
        );
      },
    );
  }
}
