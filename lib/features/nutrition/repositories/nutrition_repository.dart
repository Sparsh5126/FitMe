import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW
import '../models/food_item.dart';

class NutritionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // NEW
  
  // THE FIX: Grab the actual user's unique ID dynamically
  String get _userId => _auth.currentUser?.uid ?? 'fallback_id'; 

  String get _today => DateTime.now().toIso8601String().split('T')[0];

  // Uses the dynamic _userId instead of the hardcoded test user
  CollectionReference get _mealsRef => _db.collection('users').doc(_userId).collection('logged_meals');
  // 1. FETCH TODAY'S MEALS
  Future<List<FoodItem>> getTodayMeals() async {
    final snapshot = await _mealsRef.where('dateString', isEqualTo: _today).get();
    
    // Convert the raw Firebase data into our Flutter Objects
    return snapshot.docs.map((doc) => FoodItem.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  // 2. ADD MEAL
  Future<void> addMeal(FoodItem meal) async {
    await _mealsRef.doc(meal.id).set(meal.toMap());
  }

  // 3. UPDATE MEAL
  Future<void> updateMeal(FoodItem meal) async {
    await _mealsRef.doc(meal.id).update(meal.toMap());
  }

  // 4. DELETE MEAL
  Future<void> deleteMeal(String id) async {
    await _mealsRef.doc(id).delete();
  }
}