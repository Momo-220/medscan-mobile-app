import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/di/providers.dart';

// Stream of Firebase Auth State (Safe guarded if Firebase is not initialized)
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (e) {
    debugPrint('Firebase not initialized for authStateChanges: $e');
    return Stream.value(null);
  }
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref _ref;
  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthNotifier(this._ref) : super(const AsyncValue.data(null)) {
    // Sync current user state on launch safely
    try {
      _auth = FirebaseAuth.instance;
      state = AsyncValue.data(_auth?.currentUser);
    } catch (e) {
      debugPrint('Firebase Auth initialization failed for AuthNotifier: $e');
      state = const AsyncValue.data(null);
    }
  }

  // Register Token to secure storage
  Future<void> _saveToken() async {
    if (_auth == null) return;
    final user = _auth!.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) {
        await _ref.read(secureStorageServiceProvider).setAuthToken(token);
      }
    }
  }

  // Sign In with Email & Password
  Future<void> signIn(String email, String password) async {
    if (_auth == null) {
      throw Exception("Le service d'authentification Firebase n'est pas configuré.");
    }
    state = const AsyncValue.loading();
    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveToken();
      state = AsyncValue.data(credential.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // Sign Up / Register with Email & Password
  Future<void> signUp(String email, String password, String displayName) async {
    if (_auth == null) {
      throw Exception("Le service d'authentification Firebase n'est pas configuré.");
    }
    state = const AsyncValue.loading();
    try {
      UserCredential credential;
      try {
        credential = await _auth!.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (err) {
        // Handle email-already-in-use by logging in instead (matches Next.js auth logic exactly)
        if (err is FirebaseAuthException && err.code == 'email-already-in-use') {
          credential = await _auth!.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }

      // Update user display name
      if (credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
        // Reload to apply changes
        await credential.user!.reload();
      }

      await _saveToken();
      state = AsyncValue.data(_auth!.currentUser);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // Sign In Anonymously (Trial mode)
  Future<void> signInAnonymously() async {
    if (_auth == null) {
      throw Exception("Le service d'authentification Firebase n'est pas configuré.");
    }
    state = const AsyncValue.loading();
    try {
      final credential = await _auth!.signInAnonymously();
      await _saveToken();
      state = AsyncValue.data(credential.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // Sign In with Google
  Future<void> signInWithGoogle() async {
    if (_auth == null) {
      throw Exception("Le service d'authentification Firebase n'est pas configuré.");
    }
    state = const AsyncValue.loading();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = const AsyncValue.data(null);
        return; // Sign-in cancelled
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth!.signInWithCredential(credential);
      await _saveToken();
      state = AsyncValue.data(userCredential.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // Update profile attributes
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    if (_auth == null) return;
    final user = _auth!.currentUser;
    if (user != null) {
      if (displayName != null) await user.updateDisplayName(displayName);
      if (photoURL != null) await user.updatePhotoURL(photoURL);
      await user.reload();
      await _saveToken();
      state = AsyncValue.data(_auth!.currentUser);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    final user = _auth?.currentUser;
    final prefs = _ref.read(sharedPrefsServiceProvider);
    
    if (user != null && !user.isAnonymous) {
      await prefs.clearUserSession(user.uid);
    }
    
    try {
      await prefs.clearLocalName();
    } catch (_) {}
    
    try {
      await _auth?.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    // Always clear stored token (covers both Firebase and trial JWT tokens)
    try {
      await _ref.read(secureStorageServiceProvider).clearAuthToken();
    } catch (_) {}
    state = const AsyncValue.data(null);
  }
}

// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref);
});
