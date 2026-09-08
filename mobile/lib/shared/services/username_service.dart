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

  /// Username rules: 2-30 chars, allow letters (uppercase & lowercase), numbers,
  /// accents, underscores, dots, hyphens and special characters. No spaces or slashes.
  static String? validate(String username) {
    final clean = username.startsWith('@') ? username.substring(1).trim() : username.trim();
    if (clean.isEmpty) return 'Nom d\'utilisateur requis';
    if (clean.length < 2) return 'Le nom d\'utilisateur doit contenir au moins 2 caractères.';
    if (clean.length > 30) return 'Le nom d\'utilisateur ne doit pas dépasser 30 caractères.';
    if (clean.contains(' ') || clean.contains('/') || clean.contains('\\')) {
      return 'Le nom d\'utilisateur ne doit pas contenir d\'espaces ni de barres obliques.';
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
    final rawKey = username.startsWith('@') ? username.substring(1).trim() : username.trim();
    final key = rawKey.toLowerCase();
    final ref = _db.collection(_collection).doc(key);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) throw Exception('username_taken');
        tx.set(ref, {
          'uid': uid,
          'email': email,
          'username': rawKey, // store with original casing
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
      final rawKey = username.startsWith('@') ? username.substring(1).trim() : username.trim();
      final key = rawKey.toLowerCase();
      final doc = await _db.collection(_collection).doc(key).get();
      if (!doc.exists) return null;
      return doc.data()?['email'] as String?;
    } catch (e) {
      debugPrint('UsernameService.lookupEmail error: $e');
      return null;
    }
  }

  /// Returns the username associated with a user UID, or null if not found.
  Future<String?> lookupUsernameByUid(String uid) async {
    try {
      final snap = await _db.collection(_collection).where('uid', isEqualTo: uid).limit(1).get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data()['username'] as String?;
    } catch (e) {
      debugPrint('UsernameService.lookupUsernameByUid error: $e');
      return null;
    }
  }

  // ── Check availability ─────────────────────────────────────────

  Future<bool> isAvailable(String username) async {
    try {
      final rawKey = username.startsWith('@') ? username.substring(1) : username;
      final key = rawKey.toLowerCase().trim();
      final doc = await _db.collection(_collection).doc(key).get();
      return !doc.exists;
    } catch (e) {
      return true; // assume available on error
    }
  }

  // ── Delete ─────────────────────────────────────────────────────

  Future<void> releaseUsername(String username) async {
    try {
      final rawKey = username.startsWith('@') ? username.substring(1) : username;
      await _db
          .collection(_collection)
          .doc(rawKey.toLowerCase().trim())
          .delete();
    } catch (e) {
      debugPrint('UsernameService.releaseUsername error: $e');
    }
  }
}

final usernameService = UsernameService();
