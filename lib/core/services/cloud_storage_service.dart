import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class CloudStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Upload alert attachment to Firebase Storage
  Future<String?> uploadAlertAttachment({
    required String alertId,
    required File file,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child('alert_attachments/$alertId/$fileName');
      final uploadTask = ref.putFile(file);
      
      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });
      
      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }
  
  /// Upload shift report to Firebase Storage
  Future<String?> uploadShiftReport({
    required String reportId,
    required String content,
    required String fileName,
  }) async {
    try {
      final ref = _storage.ref().child('shift_reports/$reportId/$fileName');
      await ref.putString(content);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading shift report: $e');
      return null;
    }
  }
  
  /// Download file from Firebase Storage
  Future<File?> downloadFile({
    required String downloadUrl,
    required String localPath,
  }) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      final file = File(localPath);
      await ref.writeToFile(file);
      return file;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return null;
    }
  }
  
  /// Delete file from Firebase Storage
  Future<bool> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }
  
  /// List all attachments for an alert
  Future<List<String>> listAlertAttachments(String alertId) async {
    try {
      final ref = _storage.ref().child('alert_attachments/$alertId');
      final result = await ref.listAll();
      
      final urls = <String>[];
      for (final item in result.items) {
        final url = await item.getDownloadURL();
        urls.add(url);
      }
      return urls;
    } catch (e) {
      debugPrint('Error listing attachments: $e');
      return [];
    }
  }
}

final cloudStorageServiceProvider = Provider<CloudStorageService>((ref) {
  return CloudStorageService();
});
