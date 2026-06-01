import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'services/user_service.dart';
import 'core/localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Restore cached user ID and language preference on app startup
  try {
    const storage = FlutterSecureStorage();
    final userId = await storage.read(key: 'userId');
    if (userId != null) {
      UserService.setCachedUserId(userId);
    }
    final lang = await storage.read(key: 'appLanguage');
    if (lang != null) {
      localeNotifier.value = lang;
    }
  } catch (e) {
    debugPrint('Error restoring user session: $e');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const BharatamLMSApp());
}

class BharatamLMSApp extends StatelessWidget {
  const BharatamLMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: darkModeNotifier,
          builder: (context, isDark, _) {
            return MaterialApp(
              title: 'Bharatam LMS',
              locale: Locale(locale),
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(),
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}

