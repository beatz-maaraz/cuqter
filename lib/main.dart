import 'dart:ui';
import 'package:cuqter/Account/login.dart';
import 'package:cuqter/Screen/home/navigation_screen.dart';
import 'package:cuqter/Screen/home/desktop_navigation_screen.dart';
import 'package:cuqter/responsive/responsive_layout.dart';
import 'package:cuqter/providers/chat_provider.dart';
import 'package:cuqter/providers/theme_provider.dart';
import 'package:cuqter/utils/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cuqter/services/notification_service.dart';
import 'package:cuqter/services/deep_link_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cuqter/services/biometric_service.dart';
import 'package:cuqter/Screen/settings/app_lock_screen.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await showMessageNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optimize RAM usage and image decoding
  if (kIsWeb) {
    PaintingBinding.instance.imageCache.maximumSize = 150;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 64 * 1024 * 1024;
  } else {
    PaintingBinding.instance.imageCache.maximumSize = 100;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await BiometricService.isAppLockEnabled();
    // Start listening for cuqter.com deep links
    DeepLinkService().init(navigatorKey);
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

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      try {
        precacheImage(const AssetImage('assets/icon/icon.png'), context);
        precacheImage(const AssetImage('assets/icon/google_icon.png'), context);
        precacheImage(const AssetImage('assets/Wallpaper/dark.png'), context);
        precacheImage(const AssetImage('assets/Wallpaper/light.png'), context);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Cuqter',
      scrollBehavior: const AppScrollBehavior(),
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: themeProvider.primaryColor,
              brightness: Brightness.light,
            ).copyWith(
              primary: themeProvider.primaryColor,
              secondary: themeProvider.primaryColor.withValues(alpha: 0.2),
              surface: Colors.white,
              onSurface: AppColors.text,
              primaryContainer: themeProvider.primaryColor.withValues(
                alpha: 0.2,
              ),
              onPrimaryContainer: AppColors.text,
              surfaceContainerHighest: AppColors.card,
              onSurfaceVariant: AppColors.text,
              secondaryContainer: AppColors.accent,
              onSecondaryContainer: Colors.white,
            ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.dark,
        ).copyWith(primary: themeProvider.primaryColor, surface: Colors.black),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: AppLockWrapper(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          initialData: FirebaseAuth.instance.currentUser,
          builder: (context, snapshot) {
            if (snapshot.hasData || FirebaseAuth.instance.currentUser != null) {
              return const ResponsiveLayout(
                mobileLayout: NavigationScreen(),
                desktopLayout: DesktopNavigationScreen(),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            return const Loginpage();
          },
        ),
      ),
    );
  }
}

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper>
    with WidgetsBindingObserver {
  late bool _isLocked;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLocked =
        BiometricService.appLockEnabled &&
        FirebaseAuth.instance.currentUser != null;
    _checkAppLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _isPaused = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_isPaused && !_isLocked) {
        _isPaused = false;
        _checkAppLock();
      }
    }
  }

  Future<void> _checkAppLock() async {
    if (BiometricService.isAuthenticating) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isLockEnabled = await BiometricService.isAppLockEnabled();
    if (mounted) {
      setState(() {
        _isLocked = isLockEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return AppLockScreen(
        onUnlocked: () {
          if (mounted) {
            setState(() {
              _isLocked = false;
              _isPaused = false;
            });
          }
        },
      );
    }
    return widget.child;
  }
}
