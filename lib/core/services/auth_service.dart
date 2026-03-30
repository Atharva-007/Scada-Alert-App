import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Authentication Service
/// Handles user login, registration, and session management
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login timestamp
      await _updateUserSession(credential.user!);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Register new user
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    String role = 'operator',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user profile
      await credential.user!.updateDisplayName(displayName);

      // Create user document in Firestore
      await _createUserDocument(
        uid: credential.user!.uid,
        email: email,
        displayName: displayName,
        role: role,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in anonymously (for monitoring displays)
  Future<UserCredential> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      await _updateUserSession(credential.user!);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (currentUser != null) {
        await _endUserSession(currentUser!.uid);
      }
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Get user role from Firestore
  Future<String> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['role'] ?? 'operator';
      }
      return 'operator';
    } catch (e) {
      return 'operator';
    }
  }

  /// Check if user is admin
  Future<bool> isAdmin(String uid) async {
    final role = await getUserRole(uid);
    return role == 'admin';
  }

  /// Check if user is operator or admin
  Future<bool> isOperator(String uid) async {
    final role = await getUserRole(uid);
    return role == 'operator' || role == 'admin';
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument({
    required String uid,
    required String email,
    required String displayName,
    required String role,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }

  /// Update user session
  Future<void> _updateUserSession(User user) async {
    try {
      // Update user's last login
      await _firestore.collection('users').doc(user.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      // Create session document
      await _firestore.collection('sessions').doc(user.uid).set({
        'userId': user.uid,
        'loginAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'deviceInfo': {
          'platform': 'Flutter',
        },
      }, SetOptions(merge: true));
    } catch (e) {
      // Non-critical, log but don't throw
      print('Failed to update session: $e');
    }
  }

  /// End user session
  Future<void> _endUserSession(String uid) async {
    try {
      await _firestore.collection('sessions').doc(uid).update({
        'isActive': false,
        'logoutAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to end session: $e');
    }
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed: ${e.message ?? e.code}';
    }
  }
}

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider for current user
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Provider for user role
final userRoleProvider = FutureProvider.family<String, String>((ref, uid) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getUserRole(uid);
});

/// Provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});
