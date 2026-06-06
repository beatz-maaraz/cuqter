import 'package:cuqter/Account/login.dart';
import 'package:cuqter/Screen/navigation_screen.dart';
import 'package:cuqter/providers/chat_provider.dart';
import 'package:cuqter/providers/theme_provider.dart';
import 'package:cuqter/utils/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

    return MaterialApp(
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
          surface: AppColors.background,
          onSurface: AppColors.text,
          primaryContainer: AppColors.secondary,
          onPrimaryContainer: AppColors.text,
          surfaceContainerHighest: AppColors.card,
          onSurfaceVariant: AppColors.text,
          secondaryContainer: AppColors.accent,
          onSecondaryContainer: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        const double scale = 0.90;
        final mediaQuery = MediaQuery.of(context);
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
              return const NavigationScreen();
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Loginpage();
        },
      ),
    );
  }
}
