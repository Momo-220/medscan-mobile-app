import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/di/providers.dart';
import '../../../data/models/doctor_profile.dart';

class DoctorNotifier extends Notifier<DoctorProfile> {
  @override
  DoctorProfile build() {
    try {
      final doctorId = ref.read(sharedPrefsServiceProvider).getSelectedDoctorId();
      return getDoctorById(doctorId);
    } catch (_) {
      return getDoctorById('dr_sarah');
    }
  }

  Future<void> selectDoctor(String doctorId) async {
    final doctor = getDoctorById(doctorId);
    state = doctor;

    // 1. Save locally in SharedPrefs
    try {
      final prefs = ref.read(sharedPrefsServiceProvider);
      await prefs.setSelectedDoctorId(doctorId);
      await prefs.setDoctorCompleted(true);
    } catch (e) {
      debugPrint('Error saving doctor locally: $e');
    }

    // 2. Non-blocking sync with Firestore user document
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'doctor_id': doctorId,
          'doctor_name': doctor.name,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Non-blocking firestore doctor update: $e');
    }
  }

  void refreshFromPrefs() {
    try {
      final doctorId = ref.read(sharedPrefsServiceProvider).getSelectedDoctorId();
      state = getDoctorById(doctorId);
    } catch (_) {
      state = getDoctorById('dr_sarah');
    }
  }
}

final doctorProvider = NotifierProvider<DoctorNotifier, DoctorProfile>(() {
  return DoctorNotifier();
});
