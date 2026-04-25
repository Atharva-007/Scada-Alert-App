import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

bool get supportsFirebaseMessagingClient {
  if (kIsWeb) return true;

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.fuchsia:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return false;
  }
}

FirebaseMessaging? get firebaseMessagingOrNull =>
    supportsFirebaseMessagingClient ? FirebaseMessaging.instance : null;
