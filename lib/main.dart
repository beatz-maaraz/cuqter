import 'package:cuqter/Account/login.dart';
import 'package:cuqter/Screen/home/navigation_screen.dart';
import 'package:cuqter/Screen/home/desktop_navigation_screen.dart';
import 'package:cuqter/responsive/responsive_layout.dart';
import 'package:cuqter/widgets/liquid_background.dart';
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
import 'package:flutter/cupertino.dart';
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
  
  // Optimize RAM usage by setting maximum image cache bounds
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50 MB

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isCupertino = themeProvider.isCupertino;
    final isDark = themeProvider.isDarkMode;

    // Pre-cache key brand assets for instant flicker-free opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        precacheImage(const AssetImage('assets/icon/icon.png'), context);
        precacheImage(const AssetImage('assets/icon/google_icon.png'), context);
      } catch (_) {}
    });

    final homeWidget = AppLockWrapper(
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
    );

    Widget buildAppShell(BuildContext context, Widget? child) {
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
            child: Scaffold(
              backgroundColor: isDark ? Colors.black : Colors.white,
              body: LiquidBackground(
                child: Material(
                  type: MaterialType.transparency,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (isCupertino) {
      return CupertinoApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Cuqter',
        theme: CupertinoThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
          primaryColor: themeProvider.primaryColor,
          scaffoldBackgroundColor: isDark ? Colors.black : Colors.white,
          barBackgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9F9),
        ),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        builder: (context, child) => buildAppShell(context, child),
        home: homeWidget,
      );
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Cuqter',
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: themeProvider.primaryColor,
          secondary: themeProvider.primaryColor.withValues(alpha: 0.2),
          surface: Colors.white,
          onSurface: AppColors.text,
          primaryContainer: themeProvider.primaryColor.withValues(alpha: 0.2),
          onPrimaryContainer: AppColors.text,
          surfaceContainerHighest: AppColors.card,
          onSurfaceVariant: AppColors.text,
          secondaryContainer: AppColors.accent,
          onSecondaryContainer: Colors.white,
        ),
        cupertinoOverrideTheme: CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: themeProvider.primaryColor,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: themeProvider.primaryColor,
          surface: Colors.black,
        ),
        cupertinoOverrideTheme: CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: themeProvider.primaryColor,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
      ),
      builder: (context, child) => buildAppShell(context, child),
      home: homeWidget,
    );
  }
}

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  late bool _isLocked;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLocked = BiometricService.appLockEnabled && FirebaseAuth.instance.currentUser != null;
    _checkAppLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
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
            ],
          ),
        ),
      ),
    );
  }
}
