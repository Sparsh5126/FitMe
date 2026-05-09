import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_item.dart';
import '../services/local_nutrition_service.dart';

class NutritionRepository {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Shortcuts ─────────────────────────────
  CollectionReference get _logs => _db.collection('users').doc(_uid).collection('logs');
  CollectionReference get _recents => _db.collection('users').doc(_uid).collection('recents');
  CollectionReference get _favorites => _db.collection('users').doc(_uid).collection('favorites');
  CollectionReference get _customs => _db.collection('users').doc(_uid).collection('custom_meals');

  // ─────────────────────────────────────────
  // DAILY LOGS
  // ─────────────────────────────────────────
  Stream<List<FoodItem>> watchLogsForDate(String dateString) {
    if (_uid.isEmpty) {
      // Local fallback for guest mode (simple version)
      return Stream.fromFuture(LocalNutritionService.getLogs()).map((logs) =>
          logs.where((l) => l.dateString == dateString).toList());
    }
    return _logs
        .where('dateString', isEqualTo: dateString)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<List<FoodItem>> getLogsForDate(String dateString) async {
    if (_uid.isEmpty) {
      final logs = await LocalNutritionService.getLogs();
      return logs.where((l) => l.dateString == dateString).toList();
    }
    final snap = await _logs
        .where('dateString', isEqualTo: dateString)
        .orderBy('timestamp', descending: false)
        .get();
    return snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Future<void> addLog(FoodItem food) async {
    if (_uid.isEmpty) {
      await LocalNutritionService.addLog(food);
      return;
    }
    await _logs.doc(food.id).set(food.toMap());
    await _saveToRecents(food);
  }

  /// Like [addLog] but skips the recents side-effect.
  /// Use this for recipe-sourced logs so they go to `logs` (for stats/home)
  /// without appearing in the Recents tab (they live in Customs instead).
  Future<void> addLogOnly(FoodItem food) async {
    if (_uid.isEmpty) {
      await LocalNutritionService.addLog(food);
      return;
    }
    await _logs.doc(food.id).set(food.toMap());
  }

  Future<void> updateLog(FoodItem food) async {
    if (_uid.isEmpty) {
      await LocalNutritionService.addLog(food); // simple overwrite
      return;
    }
    await _logs.doc(food.id).update(food.toMap());
  }

  Future<void> deleteLog(String id) async {
    if (_uid.isEmpty) {
      await LocalNutritionService.deleteLog(id);
      return;
    }
    await _logs.doc(id).delete();
  }

  // Copy yesterday's meals to today
  Future<void> copyYesterdayLogs() async {
    if (_uid.isEmpty) return; // Not supported for guest
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = FoodItem.dateFor(yesterday);
    final todayStr = FoodItem.dateFor(DateTime.now());

    final snap = await _logs.where('dateString', isEqualTo: yesterdayStr).get();
    final batch = _db.batch();

    for (final doc in snap.docs) {
      final food = FoodItem.fromMap(doc.data() as Map<String, dynamic>);
      final newFood = food.copyWith(
        id: '${food.id}_copy_${DateTime.now().millisecondsSinceEpoch}',
        dateString: todayStr,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      batch.set(_logs.doc(newFood.id), newFood.toMap());
    }
    await batch.commit();
  }

  // Fetch logs for a week (for re-balancer)
  Future<List<FoodItem>> getLogsForWeek(DateTime monday) async {
    if (_uid.isEmpty) {
      final logs = await LocalNutritionService.getLogs();
      final sunday = monday.add(const Duration(days: 6));
      return logs.where((l) {
        final d = DateTime.tryParse(l.dateString);
        if (d == null) return false;
        return !d.isBefore(monday) && !d.isAfter(sunday);
      }).toList();
    }
    final sunday = monday.add(const Duration(days: 6));
    final snap = await _logs
        .where('dateString', isGreaterThanOrEqualTo: FoodItem.dateFor(monday))
        .where('dateString', isLessThanOrEqualTo: FoodItem.dateFor(sunday))
        .get();
    return snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  /// Batch fetch logs for a date range to avoid N+1 query problems
  Future<List<FoodItem>> getLogsForRange(DateTime start, DateTime end) async {
    if (_uid.isEmpty) {
      final logs = await LocalNutritionService.getLogs();
      return logs.where((l) {
        final d = DateTime.tryParse(l.dateString);
        if (d == null) return false;
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();
    }
    final snap = await _logs
        .where('dateString', isGreaterThanOrEqualTo: FoodItem.dateFor(start))
        .where('dateString', isLessThanOrEqualTo: FoodItem.dateFor(end))
        .get();
    return snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  // ─────────────────────────────────────────
  // RECENTS (last 30, auto-managed)
  // ─────────────────────────────────────────
  Future<List<FoodItem>> getRecents() async {
    if (_uid.isEmpty) {
      return LocalNutritionService.getRecents();
    }
    final snap = await _recents.orderBy('timestamp', descending: true).limit(30).get();
    return snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Future<void> _saveToRecents(FoodItem food) async {
    if (_uid.isEmpty) {
      await LocalNutritionService.saveToRecents(food);
      return;
    }
    // Use name as key so same food doesn't duplicate
    final key = food.name.toLowerCase().replaceAll(' ', '_');
    await _recents.doc(key).set(food.copyWith(timestamp: DateTime.now().millisecondsSinceEpoch).toMap());

    // Trim to 30 items
    final snap = await _recents.orderBy('timestamp', descending: true).get();
    if (snap.docs.length > 30) {
      final batch = _db.batch();
      for (final doc in snap.docs.skip(30)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ─────────────────────────────────────────
  // FAVORITES
  // ─────────────────────────────────────────
  Stream<List<FoodItem>> watchFavorites() {
    if (_uid.isEmpty) {
      return Stream.fromFuture(LocalNutritionService.getFavorites());
    }
    return _favorites
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addFavorite(FoodItem food) async {
    if (_uid.isEmpty) {
      await LocalNutritionService.toggleFavorite(food);
      return;
    }
    final key = food.name.toLowerCase().replaceAll(' ', '_');
    await _favorites.doc(key).set(food.copyWith(isFavorite: true).toMap());
  }

  Future<void> removeFavorite(String foodName) async {
    if (_uid.isEmpty) {
      // In guest mode, we pass a dummy FoodItem with the name to toggle it off
      await LocalNutritionService.toggleFavorite(FoodItem(
        id: 'dummy', name: foodName, calories: 0, protein: 0, carbs: 0, fats: 0));
      return;
    }
    final key = foodName.toLowerCase().replaceAll(' ', '_');
    await _favorites.doc(key).delete();
  }

  // ─────────────────────────────────────────
  // CUSTOM MEALS
  // ─────────────────────────────────────────
  Stream<List<FoodItem>> watchCustomMeals() {
    if (_uid.isEmpty) {
      return Stream.fromFuture(LocalNutritionService.getCustomMeals());
    }
    return _customs
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> saveCustomMeal(FoodItem food) async {
    if (_uid.isEmpty) {
      await LocalNutritionService.saveCustomMeal(food);
      return;
    }
    final key = food.name.toLowerCase().replaceAll(' ', '_');
    await _customs.doc(key).set(food.toMap());
  }

  Future<void> deleteCustomMeal(String foodName) async {
    if (_uid.isEmpty) {
      await LocalNutritionService.deleteCustomMeal(foodName);
      return;
    }
    final key = foodName.toLowerCase().replaceAll(' ', '_');
    await _customs.doc(key).delete();
  }
}