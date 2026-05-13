import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitme/core/models/user_profile.dart';

import 'package:fitme/features/auth/providers/auth_provider.dart';
import 'package:fitme/features/nutrition/services/local_nutrition_service.dart';

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final isGuest = ref.watch(isGuestProvider);

  if (uid == null) {
    if (isGuest) {
      return Stream.fromFuture(
        LocalNutritionService.getProfile().then((profile) {
          if (profile != null) return profile;
          return UserProfile.fromOnboarding(
            uid: '',
            name: 'Guest',
            age: 25,
            weight: 70,
            height: 170,
            gender: 'male',
            goalWeight: 70,
            activityLevel: 'moderate',
            dietType: 'nonveg',
            appUse: 'both',
            mantra: '',
          );
        }),
      );
    }
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return UserProfile.fromMap(snapshot.data()!);
      });
});
