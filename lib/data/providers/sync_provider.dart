import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firebase_sync_service.dart';
import '../../core/utils/firebase_platform_support.dart';

final firebaseSyncServiceProvider = Provider<FirebaseSyncService>((ref) {
  final service = FirebaseSyncService(
    firestore: FirebaseFirestore.instance,
    messaging: firebaseMessagingOrNull,
  );

  ref.onDispose(() => service.dispose());

  return service;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(firebaseSyncServiceProvider);
  return syncService.syncStatus;
});

final isOnlineProvider = Provider<bool>((ref) {
  final syncStatus = ref.watch(syncStatusProvider);
  return syncStatus.maybeWhen(
    data: (status) => status.isOnline,
    orElse: () => false,
  );
});
