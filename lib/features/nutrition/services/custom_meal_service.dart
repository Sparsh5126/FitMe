import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_item.dart';
import '../models/custom_meal_ingredient.dart';

/// Handles CRUD for user-created custom recipes / meals stored in Firestore.
///
/// Writes to users/{uid}/custom_meals — the same collection watched by
/// NutritionRepository.watchCustomMeals() — with an extra [ingredientItems]
/// array for full round-trip ingredient data.
class CustomMealService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _col() {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');
    return _db.collection('users').doc(uid).collection('custom_meals');
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Stream of all custom meals as [FoodItem]s, ordered by timestamp desc.
  static Stream<List<FoodItem>> stream() {
    return _col()
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _foodFromDoc(d)).toList());
  }

  /// One-shot fetch of all custom meals.
  static Future<List<FoodItem>> fetchAll() async {
    final snap = await _col().orderBy('timestamp', descending: true).get();
    return snap.docs.map(_foodFromDoc).toList();
  }

  /// Fetches the full ingredient list for a given custom meal id.
  static Future<List<CustomMealIngredient>> fetchIngredients(String id) async {
    final doc = await _col().doc(id).get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    final raw = data['ingredientItems'] as List<dynamic>? ?? [];
    return raw
        .map((e) =>
            CustomMealIngredient.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Create a new custom meal. Returns the generated document id.
  static Future<String> create(CustomMealDraft draft) async {
    final doc = _col().doc();
    await doc.set(_toMap(doc.id, draft));
    return doc.id;
  }

  /// Update an existing custom meal.
  static Future<void> update(String id, CustomMealDraft draft) async {
    await _col().doc(id).set(_toMap(id, draft));
  }

  /// Delete a custom meal.
  static Future<void> delete(String id) => _col().doc(id).delete();

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Builds the Firestore map. Stores FoodItem-compatible fields AND the full
  /// ingredient list so the form can reload them in edit mode.
  static Map<String, dynamic> _toMap(String id, CustomMealDraft draft) {
    final totalCal =
        draft.ingredients.fold<int>(0, (s, i) => s + i.calories);
    final totalPro =
        draft.ingredients.fold<int>(0, (s, i) => s + i.protein);
    final totalCarb =
        draft.ingredients.fold<int>(0, (s, i) => s + i.carbs);
    final totalFat =
        draft.ingredients.fold<int>(0, (s, i) => s + i.fats);

    final servings = draft.servings > 0 ? draft.servings : 1;
    final calPerServing = (totalCal / servings).round();
    final proPerServing = (totalPro / servings).round();
    final carbPerServing = (totalCarb / servings).round();
    final fatPerServing = (totalFat / servings).round();

    return {
      // FoodItem-compatible fields (used by NutritionRepository.watchCustomMeals)
      'id': id,
      'name': draft.name,
      'calories': calPerServing,
      'protein': proPerServing,
      'carbs': carbPerServing,
      'fats': fatPerServing,
      'consumedAmount': 1.0,
      'consumedUnit': 'serving',
      'isAiLogged': false,
      'isFavorite': false,
      'dateString': FoodItem.dateFor(DateTime.now()),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      // Extended fields
      'servings': servings,
      'notes': draft.notes,
      'ingredientItems':
          draft.ingredients.map((i) => i.toMap()).toList(),
    };
  }

  static FoodItem _foodFromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return FoodItem.fromMap(doc.data()!, doc.id);
  }
}

// ── Draft DTO ─────────────────────────────────────────────────────────────────

class CustomMealDraft {
  final String name;
  final int servings;
  final List<CustomMealIngredient> ingredients;
  final String notes;

  const CustomMealDraft({
    required this.name,
    this.servings = 1,
    required this.ingredients,
    this.notes = '',
  });
}