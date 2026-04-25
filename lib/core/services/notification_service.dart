import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/firebase_platform_support.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('Background message: ${message.messageId}');
  }
}

class NotificationService {
  final FirebaseMessaging? _messaging = firebaseMessagingOrNull;

  // Use dynamic for the plugin to avoid web compilation issues with missing platform methods
  late final dynamic _localNotifications;
  bool _initialized = false;
  bool _listenersRegistered = false;

  NotificationService() {
    if (!kIsWeb) {
      _localNotifications = FlutterLocalNotificationsPlugin();
    }
  }

  // High Importance Channel for SCADA Alarms (Android only)
  static const _alarmChannelId = 'critical_alerts';
  static const _alarmChannelName = 'Critical SCADA Alarms';

  Future<void> initialize() async {
    if (_initialized) return;

    final messaging = _messaging;
    if (messaging == null) {
      if (kDebugMode) {
        debugPrint('ℹ️ Firebase Messaging is not available on this platform');
      }
      return;
    }

    // 1. Request Firebase Permissions
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      if (kDebugMode) {
        debugPrint(
          'ℹ️ Notification permission not granted: ${settings.authorizationStatus}',
        );
      }
      return;
    }

    await _initializeLocalNotifications();
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _registerMessageListeners();
    _initialized = true;

    unawaited(_completeMessagingSetup(messaging));
  }

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;

    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle tap
      },
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _alarmChannelId,
            _alarmChannelName,
            description: 'Used for mission-critical industrial alerts',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );
      }
    }
  }

  void _registerMessageListeners() {
    if (_listenersRegistered) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });
    _listenersRegistered = true;
  }

  Future<void> _completeMessagingSetup(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (kDebugMode) {
        debugPrint('FCM Token: $token');
      }
    } catch (e) {
      debugPrint('⚠️ Unable to fetch FCM token: $e');
    }

    if (kIsWeb) return;

    try {
      await messaging.subscribeToTopic('scada_alerts');
      await messaging.subscribeToTopic('critical_alerts');
      await messaging.subscribeToTopic('warning_alerts');
    } catch (e) {
      debugPrint('⚠️ Topic subscription failed: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    if (kIsWeb) return;

    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _alarmChannelId,
            _alarmChannelName,
            channelDescription: 'Used for mission-critical industrial alerts',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFFFF0000),
            playSound: true,
            fullScreenIntent: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
        payload:
            message.data['alert_id'] ??
            message.data['alertId'] ??
            message.data['id'],
      );
    }
  }

  Future<void> subscribeToAlertTopics({
    bool critical = true,
    bool warning = true,
  }) async {
    final messaging = _messaging;
    if (kIsWeb || messaging == null) return;
    if (critical) await messaging.subscribeToTopic('critical_alerts');
    if (warning) await messaging.subscribeToTopic('warning_alerts');
  }

  Stream<RemoteMessage> get onMessageStream =>
      _messaging != null ? FirebaseMessaging.onMessage : const Stream.empty();
  Stream<RemoteMessage> get onMessageOpenedAppStream => _messaging != null
      ? FirebaseMessaging.onMessageOpenedApp
      : const Stream.empty();
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
