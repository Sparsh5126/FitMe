import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitme/features/nutrition/models/food_item.dart';
import 'package:fitme/core/models/user_profile.dart';

class LocalNutritionService {
  static const _kLogsKey = 'guest_nutrition_logs';
  static const _kCustomsKey = 'guest_custom_meals';
  static const _kFavoritesKey = 'guest_favorites';
  static const _kRecentsKey = 'guest_recents';
  static const _kProfileKey = 'guest_profile';
  static const _kFitPointsKey = 'guest_fitpoints';

  // ── Profile ─────────────────────────────────────────
  static Future<UserProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_kProfileKey);
    if (data == null) return null;
    return UserProfile.fromMap(jsonDecode(data));
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfileKey, jsonEncode(profile.toMap()));
  }

  // ── FitPoints ───────────────────────────────────────
  static Future<Map<String, dynamic>?> getFitPointsRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_kFitPointsKey);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  static Future<void> saveFitPointsRecord(Map<String, dynamic> record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFitPointsKey, jsonEncode(record));
  }

  // ── Logs ────────────────────────────────────────────
  static Future<List<FoodItem>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kLogsKey) ?? [];
    return list.map((s) => FoodItem.fromMap(jsonDecode(s))).toList();
  }

  static Future<void> addLog(FoodItem food) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getLogs();
    logs.add(food);
    await prefs.setStringList(
      _kLogsKey,
      logs.map((f) => jsonEncode(f.toMap())).toList(),
    );
  }

  static Future<void> deleteLog(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getLogs();
    logs.removeWhere((f) => f.id == id);
    await prefs.setStringList(
      _kLogsKey,
      logs.map((f) => jsonEncode(f.toMap())).toList(),
    );
  }

  // ── Recents ─────────────────────────────────────────
  static Future<List<FoodItem>> getRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecentsKey) ?? [];
    return list.map((s) => FoodItem.fromMap(jsonDecode(s))).toList();
  }

  static Future<void> saveToRecents(FoodItem food) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = await getRecents();
    final key = food.name.toLowerCase();
    recents.removeWhere((f) => f.name.toLowerCase() == key);
    recents.insert(0, food);
    if (recents.length > 30) recents.removeLast();
    await prefs.setStringList(
      _kRecentsKey,
      recents.map((f) => jsonEncode(f.toMap())).toList(),
    );
  }

  // ── Favorites ───────────────────────────────────────
  static Future<List<FoodItem>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kFavoritesKey) ?? [];
    return list.map((s) => FoodItem.fromMap(jsonDecode(s))).toList();
  }

  static Future<void> toggleFavorite(FoodItem food) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = await getFavorites();
    final key = food.name.toLowerCase();
    final index = favs.indexWhere((f) => f.name.toLowerCase() == key);
    if (index >= 0) {
      favs.removeAt(index);
    } else {
      favs.add(food.copyWith(isFavorite: true));
    }
    await prefs.setStringList(
      _kFavoritesKey,
      favs.map((f) => jsonEncode(f.toMap())).toList(),
    );
  }

  // ── Custom Meals ────────────────────────────────────
  static Future<List<FoodItem>> getCustomMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kCustomsKey) ?? [];
    return list.map((s) => FoodItem.fromMap(jsonDecode(s))).toList();
  }

  static Future<void> saveCustomMeal(FoodItem food) async {
    final prefs = await SharedPreferences.getInstance();
    final customs = await getCustomMeals();
    final key = food.name.toLowerCase();
    customs.removeWhere((f) => f.name.toLowerCase() == key);
    customs.add(food);
    await prefs.setStringList(
      _kCustomsKey,
      customs.map((f) => jsonEncode(f.toMap())).toList(),
    );
  }

  static Future<void> deleteCustomMeal(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final customs = await getCustomMeals();
    customs.removeWhere((f) => f.name.toLowerCase() == name.toLowerCase());
    await prefs.setStringList(
      _kCustomsKey,
      customs.map((f) => jsonEncode(f.toMap())).toList(),
    );
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLogsKey);
    await prefs.remove(_kCustomsKey);
    await prefs.remove(_kFavoritesKey);
    await prefs.remove(_kRecentsKey);
    await prefs.remove(_kProfileKey);
    await prefs.remove(_kFitPointsKey);
  }
}
