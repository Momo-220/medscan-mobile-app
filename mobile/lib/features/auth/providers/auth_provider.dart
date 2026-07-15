import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/di/providers.dart';
import '../../../shared/services/username_service.dart';

// ─────────────────────────────────────────────────────────────────
// Firebase Auth State Stream (Riverpod 3.x: StreamProvider)
// ─────────────────────────────────────────────────────────────────
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (e) {
    debugPrint('Firebase not initialized for authStateChanges: $e');
    return Stream.value(null);
  }
});

// ─────────────────────────────────────────────────────────────────
// AuthNotifier — migrated from StateNotifier to Notifier (Riverpod 3.x)
// ─────────────────────────────────────────────────────────────────
class AuthNotifier extends Notifier<AsyncValue<User?>> {
  FirebaseAuth? _auth;

  // build() replaces the old StateNotifier constructor
  @override
  AsyncValue<User?> build() {
    try {
      _auth = FirebaseAuth.instance;
      return AsyncValue.data(_auth?.currentUser);
    } catch (e) {
      debugPrint('Firebase Auth initialization failed for AuthNotifier: $e');
      return const AsyncValue.data(null);
    }
  }

  // ── Token helpers ──────────────────────────────────────────────

  Future<void> _saveToken() async {
    if (_auth == null) return;
    final user = _auth!.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) {
        await ref.read(secureStorageServiceProvider).setAuthToken(token);
      }
    }
  }

  // ── Email / Password ──────────────────────────────────────────

  /// Sign In — accepts email OR @username.
  Future<void> signIn(String emailOrUsername, String password) async {
    if (_auth == null) {
      throw Exception("Le service d'authentification Firebase n'est pas configuré.");
    }
    state = const AsyncValue.loading();
    try {
      // Resolve username → email if no @ detected
      String resolvedEmail = emailOrUsername.trim();
      if (!resolvedEmail.contains('@')) {
        final lookedUp = await usernameService.lookupEmail(resolvedEmail);
        if (lookedUp == null) {
          state = AsyncValue.error(
            Exception('Nom d\'utilisateur introuvable.'),
            StackTrace.current,
          );
          throw Exception('Nom d\'utilisateur introuvable.');
        }
        resolvedEmail = lookedUp;
      }

      final credential = await _auth!.signInWithEmailAndPassword(
        email: resolvedEmail,
        password: password,
      );
      await _saveToken();
      state = AsyncValue.data(credential.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Register with email, password, displayName and optional username.
  /// Falls back to signIn if the email is already in use.
  Future<void> signUp(
    String email,
    String password,
    String displayName, {
    String? username,
  }) async {
    if (_auth == null) {
      throw Exception("Le service d'authentification Firebase n'est pas configuré.");
    }
    state = const AsyncValue.loading();
    try {
      // Validate & claim username before creating account
      if (username != null && username.isNotEmpty) {
        final validationError = UsernameService.validate(username);
        if (validationError != null) {
          state = AsyncValue.error(Exception(validationError), StackTrace.current);
          throw Exception(validationError);
        }
        final available = await usernameService.isAvailable(username);
        if (!available) {
          state = AsyncValue.error(
            Exception('Ce nom d\'utilisateur est déjà pris.'),
            StackTrace.current,
          );
          throw Exception('Ce nom d\'utilisateur est déjà pris.');
        }
      }

      UserCredential credential;
      try {
        credential = await _auth!.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (err) {
        if (err.code == 'email-already-in-use') {
          credential = await _auth!.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }

      if (credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
        await credential.user!.reload();

        // Save username to Firestore if provided
        if (username != null && username.isNotEmpty) {
          await usernameService.claimUsername(
            username: username,
            uid: credential.user!.uid,
            email: email,
          );
        }
      }

      await _saveToken();
      state = AsyncValue.data(_auth!.currentUser);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ── Anonymous (Trial mode) ────────────────────────────────────

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

  // ── Google Sign‑In (google_sign_in v7.x API) ─────────────────

  Future<void> signInWithGoogle() async {
    if (_auth == null) {
      throw Exception("Le service d'authentification Firebase n'est pas configuré.");
    }
    state = const AsyncValue.loading();
    try {
      // google_sign_in v7.x: use singleton + authenticate()
      final GoogleSignInAccount? account =
          await GoogleSignIn.instance.authenticate();
      if (account == null) {
        // User cancelled
        state = const AsyncValue.data(null);
        return;
      }

      // idToken is a sync getter on the account (v7.x change)
      final String? idToken = account.authentication.idToken;

      // accessToken requires explicit authorization (v7.x change)
      final authorization =
          await account.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: authorization.accessToken,
      );

      final userCredential = await _auth!.signInWithCredential(credential);
      await _saveToken();
      state = AsyncValue.data(userCredential.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ── Apple Sign‑In (required by Apple Guideline 4.8) ──────────

  Future<void> signInWithApple() async {
    if (_auth == null) {
      throw Exception("Le service d'authentification Firebase n'est pas configuré.");
    }
    state = const AsyncValue.loading();
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth!.signInWithCredential(credential);

      // Apple returns displayName only on the first sign-in
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      if (givenName != null || familyName != null) {
        final displayName =
            [givenName, familyName].where((n) => n != null).join(' ');
        if (displayName.isNotEmpty && userCredential.user != null) {
          await userCredential.user!.updateDisplayName(displayName);
          await userCredential.user!.reload();
        }
      }

      await _saveToken();
      state = AsyncValue.data(_auth!.currentUser);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = const AsyncValue.data(null);
        return;
      }
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ── Profile update ────────────────────────────────────────────

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

  // ── Sign Out ──────────────────────────────────────────────────

  Future<void> signOut() async {
    final user = _auth?.currentUser;
    final prefs = ref.read(sharedPrefsServiceProvider);

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
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await ref.read(secureStorageServiceProvider).clearAuthToken();
    } catch (_) {}

    state = const AsyncValue.data(null);
  }
}

// ─────────────────────────────────────────────────────────────────
// Riverpod 3.x: NotifierProvider (replaces StateNotifierProvider)
// ─────────────────────────────────────────────────────────────────
final authProvider =
    NotifierProvider<AuthNotifier, AsyncValue<User?>>(() {
  return AuthNotifier();
});
