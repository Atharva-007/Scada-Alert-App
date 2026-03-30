import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_navigation.dart';
import 'core/services/notification_service.dart';
import 'core/services/firebase_sync_service.dart';
import 'data/providers/sync_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Enable offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    print('✅ Firebase initialized successfully');
    print('✅ Offline persistence enabled');
  } catch (e) {
    print('⚠️ Firebase initialization failed: $e');
    print('📱 App will run in offline mode with mock data');
  }
  
  // Initialize push notifications
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print('✅ Push notifications configured');
  } catch (e) {
    print('⚠️ Push notifications setup failed: $e');
  }
  
  // Lock orientation to portrait and landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Set system UI overlay style for industrial dark mode
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

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
    // Initialize services when Firebase is enabled
    Future.microtask(() async {
      try {
        // Initialize notification service
        await ref.read(notificationServiceProvider).initialize();
        print('✅ Notification service initialized');
        
        // Initialize Firebase sync service
        await ref.read(firebaseSyncServiceProvider).initialize();
        print('✅ Firebase sync service initialized');
      } catch (e) {
        print('⚠️ Service initialization failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCADA Alarm Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppNavigation(),
    );
  }
}
