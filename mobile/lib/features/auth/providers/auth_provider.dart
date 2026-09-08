import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/di/providers.dart';
import '../../../shared/services/username_service.dart';
import '../../../shared/services/widget_service.dart';
import '../../../shared/utils/email_validator.dart';

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
      final prefs = ref.read(sharedPrefsServiceProvider);
      final cleanInput = emailOrUsername.trim();
      String resolvedEmail = cleanInput;
      String? foundUsername;

      // If input is a username (starts with @ or doesn't have an email domain)
      final isEmail = cleanInput.contains('@') && cleanInput.contains('.');
      if (!isEmail) {
        final usernameToLookup = cleanInput.startsWith('@') ? cleanInput.substring(1).trim() : cleanInput;
        foundUsername = usernameToLookup;
        final lookedUp = await usernameService.lookupEmail(usernameToLookup);
        if (lookedUp == null) {
          state = AsyncValue.error(
            Exception('Nom d\'utilisateur introuvable. Essayez avec votre adresse e-mail.'),
            StackTrace.current,
          );
          throw Exception('Nom d\'utilisateur introuvable. Essayez avec votre adresse e-mail.');
        }
        resolvedEmail = lookedUp;
      }

      final credential = await _auth!.signInWithEmailAndPassword(
        email: resolvedEmail,
        password: password,
      );

      if (credential.user != null) {
        if (foundUsername != null && foundUsername.isNotEmpty) {
          await prefs.setLocalUsername(foundUsername);
        } else {
          final lookedUpUsername = await usernameService.lookupUsernameByUid(credential.user!.uid);
          if (lookedUpUsername != null && lookedUpUsername.isNotEmpty) {
            await prefs.setLocalUsername(lookedUpUsername);
          }
        }
        if (credential.user!.displayName != null) {
          await prefs.setLocalName(credential.user!.displayName!);
        }
      }

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
      final prefs = ref.read(sharedPrefsServiceProvider);

      // Validate email format and block fake/disposable domains
      final cleanEmail = EmailValidator.normalize(email);
      final emailError = EmailValidator.validate(cleanEmail);
      if (emailError != null) {
        state = AsyncValue.error(Exception(emailError), StackTrace.current);
        throw Exception(emailError);
      }

      // Validate & claim username before creating account
      final cleanUsername = username?.startsWith('@') == true
          ? username!.substring(1).trim()
          : username?.trim();

      if (cleanUsername != null && cleanUsername.isNotEmpty) {
        final validationError = UsernameService.validate(cleanUsername);
        if (validationError != null) {
          state = AsyncValue.error(Exception(validationError), StackTrace.current);
          throw Exception(validationError);
        }
        final available = await usernameService.isAvailable(cleanUsername);
        if (!available) {
          state = AsyncValue.error(
            Exception('Ce nom d\'utilisateur est déjà pris. Veuillez en choisir un autre.'),
            StackTrace.current,
          );
          throw Exception('Ce nom d\'utilisateur est déjà pris. Veuillez en choisir un autre.');
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
        await prefs.setLocalName(displayName);

        // Save username to Firestore & local preferences if provided
        if (cleanUsername != null && cleanUsername.isNotEmpty) {
          await usernameService.claimUsername(
            username: cleanUsername,
            uid: credential.user!.uid,
            email: email,
          );
          await prefs.setLocalUsername(cleanUsername);
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
      GoogleSignInAccount? account;
      try {
        account = await GoogleSignIn.instance.authenticate();
      } catch (authErr) {
        debugPrint('GoogleSignIn.instance.authenticate error: $authErr');
      }

      if (account == null) {
        // User cancelled
        state = const AsyncValue.data(null);
        return;
      }

      final String? idToken = account.authentication.idToken;
      String? accessToken;

      try {
        final authorization = await account.authorizationClient.authorizeScopes([
          'email',
          'profile',
          'openid',
        ]);
        accessToken = authorization.accessToken;
      } catch (scopeErr) {
        debugPrint('Scope authorization non-critical error: $scopeErr');
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      final userCredential = await _auth!.signInWithCredential(credential);
      await _saveToken();
      state = AsyncValue.data(userCredential.user);
    } catch (e, stack) {
      debugPrint('signInWithGoogle failed: $e\n$stack');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Generates a cryptographically secure random nonce.
  String _generateRandomNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Returns the SHA-256 digest of a string in hexadecimal format.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ── Apple Sign‑In (required by Apple Guideline 4.8) ──────────

  Future<void> signInWithApple() async {
    if (_auth == null) {
      throw Exception("Le service d'authentification Firebase n'est pas configuré.");
    }
    state = const AsyncValue.loading();
    try {
      final rawNonce = _generateRandomNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
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
      await prefs.clearLocalUsername();
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

    // Clear Home Widget state so no data leaks to the next user
    try {
      await WidgetService.clearWidget();
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
