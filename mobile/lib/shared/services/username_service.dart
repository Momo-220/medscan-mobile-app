import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore collection: usernames/{username} → { uid, email, created_at }
/// Allows login with @username instead of email.
class UsernameService {
  static const _collection = 'usernames';

  final FirebaseFirestore _db;

  UsernameService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  // ── Validation ─────────────────────────────────────────────────

  /// Username rules: 3-20 chars, letters/digits/underscores only, no spaces
  static String? validate(String username) {
    if (username.isEmpty) return 'Nom d\'utilisateur requis';
    if (username.length < 3) return 'Minimum 3 caractères';
    if (username.length > 20) return 'Maximum 20 caractères';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Lettres, chiffres et _ uniquement';
    }
    return null;
  }

  // ── Save ───────────────────────────────────────────────────────

  /// Called on signup — registers the username → uid/email mapping.
  /// Returns false if the username is already taken.
  Future<bool> claimUsername({
    required String username,
    required String uid,
    required String email,
  }) async {
    final key = username.toLowerCase().trim();
    final ref = _db.collection(_collection).doc(key);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) throw Exception('username_taken');
        tx.set(ref, {
          'uid': uid,
          'email': email,
          'username': key,
          'created_at': FieldValue.serverTimestamp(),
        });
      });
      return true;
    } on Exception catch (e) {
      if (e.toString().contains('username_taken')) return false;
      debugPrint('UsernameService.claimUsername error: $e');
      return false;
    }
  }

  // ── Lookup ─────────────────────────────────────────────────────

  /// Returns the email associated with a username, or null if not found.
  Future<String?> lookupEmail(String username) async {
    try {
      final key = username.toLowerCase().trim();
      final doc = await _db.collection(_collection).doc(key).get();
      if (!doc.exists) return null;
      return doc.data()?['email'] as String?;
    } catch (e) {
      debugPrint('UsernameService.lookupEmail error: $e');
      return null;
    }
  }

  // ── Check availability ─────────────────────────────────────────

  Future<bool> isAvailable(String username) async {
    try {
      final key = username.toLowerCase().trim();
      final doc = await _db.collection(_collection).doc(key).get();
      return !doc.exists;
    } catch (e) {
      return true; // assume available on error
    }
  }

  // ── Delete ─────────────────────────────────────────────────────

  Future<void> releaseUsername(String username) async {
    try {
      await _db
          .collection(_collection)
          .doc(username.toLowerCase().trim())
          .delete();
    } catch (e) {
      debugPrint('UsernameService.releaseUsername error: $e');
    }
  }
}

final usernameService = UsernameService();
