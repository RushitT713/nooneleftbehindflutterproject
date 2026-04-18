import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'firebase_options.dart';
import 'constants.dart';
import 'providers/trip_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/battery_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize port for communication between TaskHandler and UI
  FlutterForegroundTask.initCommunicationPort();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable offline persistence
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseDatabase.instance.setPersistenceCacheSizeBytes(52428800); // 50MB

  // Initialize Battery monitor
  final batteryService = BatteryService();
  await batteryService.init();

  // Initialize Notification service
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermission();

  // Initial battery update for already running service
  LocationService.updateBatteryLevel(batteryService.isLowBattery);

  // Subscribe to changes
  batteryService.onBatteryLevelChanged.listen((level) {
    LocationService.updateBatteryLevel(batteryService.isLowBattery);
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const NoOneLeftBehindApp(),
    ),
  );
}



class NoOneLeftBehindApp extends StatelessWidget {
  const NoOneLeftBehindApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NoOneLeftBehind',

      // ── Theme mode ──
      themeMode: themeProvider.themeMode,

      // ── LIGHT THEME ──
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: kBackground,
        fontFamily: 'Thicccboi',

        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: kBackground,
          foregroundColor: kTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: kTextPrimary,
          ),
        ),

        // Bottom sheets
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: kSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),

        // Cards
        cardTheme: CardThemeData(
          color: kBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kSurfaceBorder, width: 1),
          ),
        ),

        // Elevated button
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),

        // --- GLOBAL TEXT THEME ---
        textTheme: const TextTheme(
          displayMedium: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: kTextPrimary,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: kTextPrimary,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.1,
            color: kTextPrimary,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: kTextSecondary,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w400,
            fontSize: 12,
            color: kTextTertiary,
          ),
        ),
      ),

      // ── DARK THEME (Night Driving) ──
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          brightness: Brightness.dark,
          surface: kDarkSurface,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: kDarkBackground,
        fontFamily: 'Thicccboi',

        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: kDarkBackground,
          foregroundColor: kDarkTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: kDarkTextPrimary,
          ),
        ),

        // Bottom sheets
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: kDarkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),

        // Cards
        cardTheme: CardThemeData(
          color: kDarkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kDarkSurfaceBorder, width: 1),
          ),
        ),

        // Elevated button
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),

        // --- GLOBAL TEXT THEME (dark) ---
        textTheme: const TextTheme(
          displayMedium: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: kDarkTextPrimary,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: kDarkTextPrimary,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.1,
            color: kDarkTextPrimary,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: kDarkTextSecondary,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w400,
            fontSize: 12,
            color: kDarkTextTertiary,
          ),
        ),

        // Drawer
        drawerTheme: const DrawerThemeData(
          backgroundColor: kDarkSurface,
        ),

        // Dialogs
        dialogTheme: const DialogThemeData(
          backgroundColor: kDarkSurface,
        ),

        // Snackbar
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: kDarkSurface,
          contentTextStyle: TextStyle(
            fontFamily: 'Thicccboi',
            color: kDarkTextPrimary,
          ),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}