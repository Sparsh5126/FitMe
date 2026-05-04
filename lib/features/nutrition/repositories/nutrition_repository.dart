import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_item.dart';

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
    return _logs
        .where('dateString', isEqualTo: dateString)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<List<FoodItem>> getLogsForDate(String dateString) async {
    final snap = await _logs
        .where('dateString', isEqualTo: dateString)
        .orderBy('timestamp', descending: false)
        .get();
    return snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Future<void> addLog(FoodItem food) async {
    await _logs.doc(food.id).set(food.toMap());
    await _saveToRecents(food);
  }

  /// Like [addLog] but skips the recents side-effect.
  /// Use this for recipe-sourced logs so they go to `logs` (for stats/home)
  /// without appearing in the Recents tab (they live in Customs instead).
  Future<void> addLogOnly(FoodItem food) async {
    await _logs.doc(food.id).set(food.toMap());
  }

  Future<void> updateLog(FoodItem food) async {
    await _logs.doc(food.id).update(food.toMap());
  }

  Future<void> deleteLog(String id) async {
    await _logs.doc(id).delete();
  }

  // Copy yesterday's meals to today
  Future<void> copyYesterdayLogs() async {
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
    final sunday = monday.add(const Duration(days: 6));
    final snap = await _logs
        .where('dateString', isGreaterThanOrEqualTo: FoodItem.dateFor(monday))
        .where('dateString', isLessThanOrEqualTo: FoodItem.dateFor(sunday))
        .get();
    return snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  // ─────────────────────────────────────────
  // RECENTS (last 30, auto-managed)
  // ─────────────────────────────────────────
  Future<List<FoodItem>> getRecents() async {
    final snap = await _recents.orderBy('timestamp', descending: true).limit(30).get();
    return snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Future<void> _saveToRecents(FoodItem food) async {
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
    return _favorites
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addFavorite(FoodItem food) async {
    final key = food.name.toLowerCase().replaceAll(' ', '_');
    await _favorites.doc(key).set(food.copyWith(isFavorite: true).toMap());
  }

  Future<void> removeFavorite(String foodName) async {
    final key = foodName.toLowerCase().replaceAll(' ', '_');
    await _favorites.doc(key).delete();
  }

  // ─────────────────────────────────────────
  // CUSTOM MEALS
  // ─────────────────────────────────────────
  Stream<List<FoodItem>> watchCustomMeals() {
    return _customs
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FoodItem.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> saveCustomMeal(FoodItem food) async {
    final key = food.name.toLowerCase().replaceAll(' ', '_');
    await _customs.doc(key).set(food.toMap());
  }

  Future<void> deleteCustomMeal(String foodName) async {
    final key = foodName.toLowerCase().replaceAll(' ', '_');
    await _customs.doc(key).delete();
  }
}