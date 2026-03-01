import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user_profile.dart';

final userProfileProvider = StreamProvider<UserProfile>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  
  if (uid == null) {
    return Stream.value(UserProfile.defaultProfile());
  }

  final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

  return docRef.snapshots().map((snapshot) {
    if (!snapshot.exists || snapshot.data() == null) {
      // If user document doesn't exist yet, create it with defaults
      final defaultProfile = UserProfile.defaultProfile();
      docRef.set(defaultProfile.toMap());
      return defaultProfile;
    }
    return UserProfile.fromMap(snapshot.data()!);
  });
});