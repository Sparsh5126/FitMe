import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_item.dart';
import '../repositories/nutrition_repository.dart';
import '../services/food_search_service.dart';
import '../../dashboard/providers/user_provider.dart';
import '../../recipes/models/recipe_model.dart';

final _repo = NutritionRepository();

// ─────────────────────────────────────────
// SELECTED DATE
// ─────────────────────────────────────────
class _SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDate(DateTime date) => state = date;
  void changeBy(int days) => state = state.add(Duration(days: days));
}

final selectedDateProvider = NotifierProvider<_SelectedDateNotifier, DateTime>(_SelectedDateNotifier.new);

String _dateStr(DateTime d) => FoodItem.dateFor(d);

// ─────────────────────────────────────────
// DAILY LOGS (reactive to selected date)
// ─────────────────────────────────────────
final nutritionProvider = StreamProvider<List<FoodItem>>((ref) {
  final date = ref.watch(selectedDateProvider);
  return _repo.watchLogsForDate(_dateStr(date));
});

// ─────────────────────────────────────────
// RECENTS
// ─────────────────────────────────────────
final recentsProvider = FutureProvider<List<FoodItem>>((ref) async {
  return _repo.getRecents();
});

// ─────────────────────────────────────────
// FAVORITES
// ─────────────────────────────────────────
final favoritesProvider = StreamProvider<List<FoodItem>>((ref) {
  return _repo.watchFavorites();
});

// ─────────────────────────────────────────
// CUSTOM MEALS
// ─────────────────────────────────────────
final customMealsProvider = StreamProvider<List<FoodItem>>((ref) {
  return _repo.watchCustomMeals();
});

// ─────────────────────────────────────────
// COMMON FOODS (loaded once from JSON)
// ─────────────────────────────────────────
final commonFoodsProvider = FutureProvider<List<FoodItem>>((ref) async {
  return FoodSearchService.loadCommonFoods();
});

// ─────────────────────────────────────────
// FOOD ACTIONS NOTIFIER
// ─────────────────────────────────────────
final foodActionsProvider = Provider<FoodActions>((ref) => FoodActions(ref));

class FoodActions {
  final Ref _ref;
  FoodActions(this._ref);

  Future<void> logFood(FoodItem food) async {
    await _repo.addLog(food);
    // Invalidate recents so they refresh
    _ref.invalidate(recentsProvider);
  }

  /// Log a recipe: writes to `logs` (stats/home) and upserts to `custom_meals`
  /// (so it appears in the Customs tab with its full ingredient list).
  /// Does NOT write to recents — recipes are reused from Customs, not Recents.
  Future<void> logRecipe(RecipeModel recipe) async {
    final logEntry = recipe.toFoodItem(); // unique ID tied to this log event
    final customTemplate = recipe.toCustomMealTemplate(); // stable ID for customs

    // Write to logs collection so home screen / stats see it immediately
    await _repo.addLogOnly(logEntry);

    // Upsert into custom_meals so user can re-log with ingredients visible
    await _repo.saveCustomMeal(customTemplate);

    // Refresh the customs tab
    _ref.invalidate(customMealsProvider);
  }

  Future<void> deleteFood(String id) async {
    await _repo.deleteLog(id);
  }

  Future<void> updateFood(FoodItem food) async {
    await _repo.updateLog(food);
  }

  Future<void> copyYesterdayMeals() async {
    await _repo.copyYesterdayLogs();
  }

  Future<void> addFavorite(FoodItem food) async {
    await _repo.addFavorite(food);
  }

  Future<void> removeFavorite(String foodName) async {
    await _repo.removeFavorite(foodName);
  }

  Future<void> toggleFavorite(FoodItem food) async {
    final favs = _ref.read(favoritesProvider).value ?? [];
    final isFav = favs.any(
        (f) => f.name.toLowerCase() == food.name.toLowerCase());
    if (isFav) {
      await _repo.removeFavorite(food.name);
    } else {
      await _repo.addFavorite(food);
    }
  }

  Future<void> saveCustomMeal(FoodItem food) async {
    await _repo.saveCustomMeal(food);
  }

  Future<void> deleteCustomMeal(String name) async {
    await _repo.deleteCustomMeal(name);
  }

  // Increment smart logger daily counter
  Future<void> incrementSmartLoggerCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final today = _dateStr(DateTime.now());
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await ref.get();
    final data = doc.data() ?? {};
    final lastReset = data['smartLoggerLastResetDate'] ?? '';
    final currentCount = lastReset == today ? (data['smartLoggerUsedToday'] ?? 0) : 0;

    await ref.update({
      'smartLoggerUsedToday': currentCount + 1,
      'smartLoggerLastResetDate': today,
    });

    _ref.invalidate(userProfileProvider);
  }
}

// ─────────────────────────────────────────
// DAILY TOTALS (derived)
// ─────────────────────────────────────────
final dailyTotalsProvider = Provider<Map<String, int>>((ref) {
  final mealsAsync = ref.watch(nutritionProvider);
  final meals = mealsAsync.value ?? [];
  
  int cals = 0, pro = 0, carbs = 0, fats = 0;
  for (final m in meals) {
    cals += m.calories;
    pro += m.protein;
    carbs += m.carbs;
    fats += m.fats;
  }
  return {'calories': cals, 'protein': pro, 'carbs': carbs, 'fats': fats};
});