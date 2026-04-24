import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user_profile.dart';
 
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
 
  if (uid == null) return Stream.value(null);
 
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists || snapshot.data() == null) return null;
    return UserProfile.fromMap(snapshot.data()!);
  });
});
 