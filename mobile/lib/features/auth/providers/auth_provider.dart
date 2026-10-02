
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/di/providers.dart';
import '../../../shared/services/username_service.dart';
import '../../../shared/services/widget_service.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/utils/email_validator.dart';
import '../../history/providers/pharmacy_provider.dart';
import '../../home/providers/recent_scans_provider.dart';
import '../../reminders/providers/reminders_provider.dart';
import '../../home/providers/health_stats_provider.dart';
import '../../home/providers/credits_provider.dart';
import '../../chat/providers/chat_provider.dart';

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
      // Any authenticated user has completed onboarding
      await ref.read(sharedPrefsServiceProvider).setOnboardingCompleted(true);
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
        final errStr = authErr.toString().toLowerCase();
        if (errStr.contains('canceled') || errStr.contains('cancelled') || errStr.contains('sign_in_canceled') || errStr.contains('12501')) {
          // User cancelled
          state = const AsyncValue.data(null);
          return;
        }
        throw Exception("Échec de connexion Google. Veuillez vérifier votre connexion ou réessayer.");
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
      // 1. Génération cryptographiquement sécurisée du rawNonce (32 caractères)
      final rawNonce = _generateRandomNonce(32);
      // Apple attend le SHA-256 hexadécimal du rawNonce
      final sha256Nonce = _sha256ofString(rawNonce);

      // 2. Appel natif AuthenticationServices (iOS 13+)
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256Nonce,
      );

      // 3. Décodage sécurisé des claims du JWT Apple (sans exposer de token secret)
      String? appleSub;
      String? appleTransferSub;
      String? jwtEmail;
      bool? emailVerified;
      String? jwtIss;
      String? jwtAud;

      if (appleCredential.identityToken != null) {
        try {
          final parts = appleCredential.identityToken!.split('.');
          if (parts.length >= 2) {
            final normalized = base64Url.normalize(parts[1]);
            final payloadString = utf8.decode(base64Url.decode(normalized));
            final Map<String, dynamic> payload = json.decode(payloadString);
            appleSub = payload['sub'] as String?;
            appleTransferSub = payload['transfer_sub'] as String?;
            jwtEmail = payload['email'] as String?;
            emailVerified = payload['email_verified'] == true || payload['email_verified'] == 'true';
            jwtIss = payload['iss'] as String?;
            jwtAud = payload['aud'] as String?;
          }
        } catch (jwtErr) {
          debugPrint('⚠️ [Apple Auth] Erreur non-bloquante décodage JWT: $jwtErr');
        }
      }

      // 4. Logs de diagnostic non-sensibles (tailles, flags de présence, aucun token complet)
      debugPrint('🍏 [Apple Auth Diagnostic] :');
      debugPrint('   - identityToken: ${appleCredential.identityToken != null ? "Présent (${appleCredential.identityToken!.length} octets)" : "ABSENT ❌"}');
      debugPrint('   - authorizationCode: ${appleCredential.authorizationCode.isNotEmpty ? "Présent (${appleCredential.authorizationCode.length} octets)" : "Vide"}');
      debugPrint('   - rawNonce: Présent (${rawNonce.length} chars)');
      debugPrint('   - userIdentifier: ${appleCredential.userIdentifier != null ? "Présent" : "Absent"}');
      debugPrint('   - givenName: ${appleCredential.givenName != null ? "Présent" : "(Non renvoyé par Apple - connexion subséquente)"}');
      debugPrint('   - familyName: ${appleCredential.familyName != null ? "Présent" : "(Non renvoyé par Apple - connexion subséquente)"}');
      debugPrint('   - scopes email: ${appleCredential.email != null ? "Présent" : "(Non renvoyé par Apple - connexion subséquente)"}');
      debugPrint('   - JWT claims: iss=$jwtIss, aud=$jwtAud, email_verified=$emailVerified');
      debugPrint('   - sub: ${appleSub != null ? "${appleSub.substring(0, min(8, appleSub.length))}..." : "Absent"}');
      debugPrint('   - transfer_sub: ${appleTransferSub != null ? "DÉTECTÉ (${appleTransferSub.substring(0, min(8, appleTransferSub.length))}...)" : "Non présent"}');

      // 5. Création du Credential Firebase Auth
      //
      // EXPLICATION ARCHITECTURALE CRUCIALE :
      // Sur iOS natif, le credential (idToken: identityToken, rawNonce: rawNonce)
      // valide directement la signature cryptographique du jeton Apple via les clés publiques
      // d'Apple (https://appleid.apple.com/auth/keys) et vérifie le nonce SHA-256.
      //
      // Si l'on transmet accessToken: appleCredential.authorizationCode, Firebase tente un échange
      // OAuth serveur-à-serveur avec https://appleid.apple.com/auth/token qui requiert impérativement
      // la clé privée .p8 configurée dans la console Firebase. Si cette clé est absente ou invalide,
      // Firebase rejette la requête avec :
      // [firebase_auth/invalid-user-token] accessToken or refreshToken is nil.
      //
      // En utilisant idToken + rawNonce en premier, la connexion est 100% fiable,
      // cryptographiquement sécurisée et ne dépend pas d'un échange serveur de clé .p8 !
      // 5. Création du Credential Firebase Auth (Standard iOS Natif)
      //
      // Sur iOS natif, le credential (idToken: identityToken, rawNonce: rawNonce)
      // valide cryptographiquement le jeton d'identité Apple via les clés publiques d'Apple.
      // On ne transmet PAS accessToken (qui est un authorizationCode) pour éviter de déclencher
      // un échange OAuth serveur-à-serveur qui requiert une configuration Web/Service ID.
      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        signInMethod: 'apple.com',
      );

      final userCredential = await _auth!.signInWithCredential(credential);

      final firebaseUser = userCredential.user;
      final prefs = ref.read(sharedPrefsServiceProvider);

      // 6. Sauvegarde et préservation du Nom / Prénom (fournis uniquement à la 1ère connexion)
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      String? computedDisplayName;
      if (givenName != null || familyName != null) {
        computedDisplayName = [givenName, familyName].where((n) => n != null && n.isNotEmpty).join(' ');
      }

      if (firebaseUser != null) {
        if (computedDisplayName != null && computedDisplayName.isNotEmpty) {
          try {
            await firebaseUser.updateDisplayName(computedDisplayName);
            await firebaseUser.reload();
            await prefs.setLocalName(computedDisplayName);
          } catch (e) {
            debugPrint('Update displayName non-blocking: $e');
          }
        } else if (firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty) {
          await prefs.setLocalName(firebaseUser.displayName!);
        }

        // Récupérer le nom d'utilisateur existant si déjà réclamé
        final existingUsername = await usernameService.lookupUsernameByUid(firebaseUser.uid);
        if (existingUsername != null && existingUsername.isNotEmpty) {
          await prefs.setLocalUsername(existingUsername);
        }

        // 7. Sauvegarde locale des identifiants Apple (sub & transfer_sub)
        if (appleSub != null) {
          await prefs.setString('apple_sub', appleSub);
        }
        if (appleTransferSub != null) {
          await prefs.setString('apple_transfer_sub', appleTransferSub);
        }

        // 8. Synchronisation Firestore et détection / journalisation de la migration transfer_sub
        try {
          final userDoc = FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
          // Déterminer l'email le plus propre (prioriser le vrai email sur le relais privé si disponible)
          String? cleanEmail = appleCredential.email ?? jwtEmail;
          for (final p in firebaseUser.providerData) {
            final pe = p.email;
            if (pe != null && pe.isNotEmpty && !pe.contains('@privaterelay')) {
              cleanEmail = pe;
              break;
            }
          }
          if (cleanEmail == null || cleanEmail.isEmpty) {
            cleanEmail = firebaseUser.email;
          }

          final Map<String, dynamic> userData = {
            'uid': firebaseUser.uid,
            'email': cleanEmail,
            'last_sign_in': FieldValue.serverTimestamp(),
            'auth_provider': 'apple.com',
          };
          if (appleSub != null) userData['apple_sub'] = appleSub;
          if (appleTransferSub != null) userData['apple_transfer_sub'] = appleTransferSub;
          if (computedDisplayName != null && computedDisplayName.isNotEmpty) {
            userData['display_name'] = computedDisplayName;
          }

          await userDoc.set(userData, SetOptions(merge: true));

          // Si un transfer_sub est présent (suite au transfert de compte Apple Developer),
          // rechercher l'ancien compte utilisateur pour tracer la continuité
          if (appleTransferSub != null && appleTransferSub.isNotEmpty) {
            final prevDocs = await FirebaseFirestore.instance
                .collection('users')
                .where('apple_sub', isEqualTo: appleTransferSub)
                .limit(1)
                .get();
            if (prevDocs.docs.isNotEmpty) {
              final prevUid = prevDocs.docs.first.id;
              debugPrint('🔄 [Apple Migration] transfer_sub détecté: ancien compte $prevUid rattaché au nouveau ${firebaseUser.uid}');
              await userDoc.set({
                'migrated_from_uid': prevUid,
                'apple_transfer_sub_linked_at': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          }
        } catch (fsErr) {
          debugPrint('Firestore Apple user sync non-blocking: $fsErr');
        }
      }

      // 9. Sauvegarde du jeton d'authentification pour l'API backend
      try {
        await _saveToken();
      } catch (tokenErr) {
        debugPrint('Apple saveToken erreur non-bloquante: $tokenErr');
      }

      state = AsyncValue.data(_auth!.currentUser);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = const AsyncValue.data(null);
        return;
      }
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } catch (e, stack) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('canceled') || errStr.contains('cancelled') || errStr.contains('1001')) {
        state = const AsyncValue.data(null);
        return;
      }
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ── Profile update ────────────────────────────────────────────

  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    if (_auth == null) return;
    final user = _auth!.currentUser;
    if (user != null) {
      if (displayName != null) {
        try {
          await user.updateDisplayName(displayName);
        } catch (e) {
          debugPrint('updateDisplayName non-blocking: $e');
        }
      }
      if (photoURL != null) {
        try {
          await user.updatePhotoURL(photoURL);
        } catch (e) {
          debugPrint('updatePhotoURL non-blocking: $e');
        }
      }
      try {
        await user.reload();
      } catch (_) {}
      try {
        await _saveToken();
      } catch (_) {}

      try {
        final Map<String, dynamic> updateData = {
          'updated_at': FieldValue.serverTimestamp(),
        };
        if (photoURL != null) updateData['photo_url'] = photoURL;
        if (displayName != null) updateData['display_name'] = displayName;
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          updateData,
          SetOptions(merge: true),
        );
      } catch (fsErr) {
        debugPrint('Firestore updateProfile non-blocking: $fsErr');
      }

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
      await prefs.clearLocalAvatar();
      await prefs.setAvatarCompleted(false);
      await prefs.clearTrialScans();
    } catch (_) {}

    // 1. Clear secure storage auth token FIRST
    try {
      await ref.read(secureStorageServiceProvider).clearAuthToken();
    } catch (_) {}

    // 2. Invalidate all user state providers so no data leaks in memory
    try {
      ref.invalidate(pharmacyProvider);
      ref.invalidate(recentScansProvider);
      ref.invalidate(remindersProvider);
      ref.invalidate(healthStatsProvider);
      ref.invalidate(creditsProvider);
      ref.invalidate(chatProvider);
    } catch (_) {}

    // 3. Cancel scheduled notifications
    try {
      NotificationService.cancelAll();
    } catch (_) {}

    // 4. Sign out from Firebase and Google
    try {
      await _auth?.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
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
