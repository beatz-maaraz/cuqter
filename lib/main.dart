import 'package:cuqter/Account/login.dart';
import 'package:cuqter/Screen/navigation_screen.dart';
import 'package:cuqter/Screen/desktop_navigation_screen.dart';
import 'package:cuqter/responsive/responsive_layout.dart';
import 'package:cuqter/providers/chat_provider.dart';
import 'package:cuqter/providers/theme_provider.dart';
import 'package:cuqter/utils/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cuqter/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await showMessageNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBOvtzNFHyoCeq8pZZ_JdaG0dmd4a1DPHs",
        authDomain: "cuqter-2fa01.firebaseapp.com",
        databaseURL: "https://cuqter-2fa01-default-rtdb.firebaseio.com",
        projectId: "cuqter-2fa01",
        storageBucket: "cuqter-2fa01.firebasestorage.app",
        messagingSenderId: "921725231252",
        appId: "1:921725231252:web:a2dbfa0c97694cbf299481",
        measurementId: "G-5TKLZ0RS2M",
      ),
    );
  } else {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Pre-cache key brand assets for instant flicker-free opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        precacheImage(const AssetImage('assets/icon/icon.png'), context);
        precacheImage(const AssetImage('assets/icon/google_icon.png'), context);
      } catch (_) {}
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Cuqter',
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: Colors.white,
          onSurface: AppColors.text,
          primaryContainer: AppColors.secondary,
          onPrimaryContainer: AppColors.text,
          surfaceContainerHighest: AppColors.card,
          onSurfaceVariant: AppColors.text,
          secondaryContainer: AppColors.accent,
          onSecondaryContainer: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          surface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        
        const double scale = 0.90;
        final scaledSize = mediaQuery.size / scale;

        return MediaQuery(
          data: mediaQuery.copyWith(
            size: scaledSize,
            padding: mediaQuery.padding / scale,
            viewPadding: mediaQuery.viewPadding / scale,
            viewInsets: mediaQuery.viewInsets / scale,
            systemGestureInsets: mediaQuery.systemGestureInsets / scale,
          ),
          child: OverflowBox(
            minWidth: scaledSize.width,
            maxWidth: scaledSize.width,
            minHeight: scaledSize.height,
            maxHeight: scaledSize.height,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.hasData) {
              return const ResponsiveLayout(
                mobileLayout: NavigationScreen(),
                desktopLayout: DesktopNavigationScreen(),
              );
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            return const Loginpage();
          }
          return const _StartupSplashScreen();
        },
      ),
    );
  }
}

class _StartupSplashScreen extends StatelessWidget {
  const _StartupSplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF14142B), Color(0xFF0E0E1E), Color(0xFF1F122B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFD9E2FF), Color(0xFFFFFFFF), Color(0xFFF9D8FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0057C3).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/icon/icon.png',
                  height: 64,
                  width: 64,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.chat_bubble_rounded,
                    size: 48,
                    color: Color(0xFF0057C3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF0057C3), Color(0xFF883CA6)],
                ).createShader(bounds),
                child: const Text(
                  'Cuqter',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF0057C3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
