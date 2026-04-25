import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_navigation.dart';
import 'core/services/notification_service.dart';
import 'data/providers/sync_provider.dart';
import 'core/utils/firebase_platform_support.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable offline persistence with extra safety for web/platforms
    if (!kIsWeb) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint('✅ Offline persistence enabled');
      } catch (e) {
        debugPrint('ℹ️ Persistence setup skipped: $e');
      }
    }

    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Firebase initialization failed: $e');
  }

  // Initialize push notifications
  try {
    if (supportsFirebaseMessagingClient) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      debugPrint('✅ Push notifications configured');
    } else {
      debugPrint('ℹ️ Push notifications are not supported on this platform');
    }
  } catch (e) {
    debugPrint('⚠️ Push notifications setup failed: $e');
  }

  // Lock orientation to portrait and landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const ProviderScope(child: ScadaAlarmApp()));
}

class ScadaAlarmApp extends ConsumerStatefulWidget {
  const ScadaAlarmApp({super.key});

  @override
  ConsumerState<ScadaAlarmApp> createState() => _ScadaAlarmAppState();
}

class _ScadaAlarmAppState extends ConsumerState<ScadaAlarmApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scheduleServiceInitialization());
    });
  }

  Future<void> _scheduleServiceInitialization() async {
    unawaited(_initializeNotificationsAfterDelay());
    unawaited(_initializeSyncAfterDelay());
  }

  Future<void> _initializeNotificationsAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    try {
      await ref.read(notificationServiceProvider).initialize();
    } catch (e) {
      debugPrint('⚠️ Notification initialization failed: $e');
    }
  }

  Future<void> _initializeSyncAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    try {
      await ref.read(firebaseSyncServiceProvider).initialize();
    } catch (e) {
      debugPrint('⚠️ Sync initialization failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    // Set system UI overlay style based on theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeMode == ThemeMode.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: themeMode == ThemeMode.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'SCADA Alarm Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AppNavigation(),
    );
  }
}
