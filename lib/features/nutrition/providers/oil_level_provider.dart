import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_item.dart';

// ─────────────────────────────────────────
// OIL LEVEL ENUM
// ─────────────────────────────────────────
enum OilLevel { light, normal, heavy }

extension OilLevelExt on OilLevel {
  String get label {
    switch (this) {
      case OilLevel.light:  return 'Light';
      case OilLevel.normal: return 'Normal';
      case OilLevel.heavy:  return 'Heavy';
    }
  }

  String get emoji {
    switch (this) {
      case OilLevel.light:  return '🥗';
      case OilLevel.normal: return '🍛';
      case OilLevel.heavy:  return '🧈';
    }
  }

  /// Fat multiplier relative to the base "normal" value.
  double get fatMultiplier {
    switch (this) {
      case OilLevel.light:  return 0.65;
      case OilLevel.normal: return 1.00;
      case OilLevel.heavy:  return 1.45;
    }
  }

  int get index2 {
    switch (this) {
      case OilLevel.light:  return 0;
      case OilLevel.normal: return 1;
      case OilLevel.heavy:  return 2;
    }
  }

  static OilLevel fromIndex(int i) {
    switch (i) {
      case 0:  return OilLevel.light;
      case 2:  return OilLevel.heavy;
      default: return OilLevel.normal;
    }
  }

  static OilLevel fromString(String s) {
    switch (s) {
      case 'light':  return OilLevel.light;
      case 'heavy':  return OilLevel.heavy;
      default:       return OilLevel.normal;
    }
  }
}

// ─────────────────────────────────────────
// OILY INDIAN FOOD DETECTION
// ─────────────────────────────────────────
const _oilyIndianKeywords = {
  'chole', 'bhature', 'poha', 'paneer', 'bhurji', 'sabzi', 'fried rice',
  'rajma', 'dal', 'tadka', 'paratha', 'biryani', 'halwa', 'puri', 'aloo',
  'matar', 'korma', 'curry', 'masala', 'samosa', 'pakora', 'kachori',
  'chana', 'palak', 'navratan', 'pav bhaji', 'upma', 'dosa', 'uttapam',
  'khichdi', 'pulao', 'thali', 'naan', 'tikka', 'butter chicken', 'keema',
  'nihari', 'haleem', 'kadhi', 'baingan', 'lauki', 'methi', 'bhindi',
  'sabji', 'tarka', 'ghee', 'makhan',
};

bool isOilyIndianFood(String name) {
  final lower = name.toLowerCase();
  return _oilyIndianKeywords.any((kw) => lower.contains(kw));
}

/// Returns a new FoodItem with fat & calories adjusted for the given oil level.
/// Protein and carbs remain unchanged.
FoodItem applyOilLevel(FoodItem food, OilLevel level) {
  final baseProtein = food.protein;
  final baseCarbs = food.carbs;
  final baseFats = food.fats;

  int newProtein = baseProtein;
  int newCarbs = baseCarbs;
  int newFats = baseFats;

  switch (level) {
    case OilLevel.light:
      // Slightly less carbs, much less oil
      newCarbs = (baseCarbs * 0.97).round();
      newFats = (baseFats * 0.70).round();
      break;

    case OilLevel.normal:
      newCarbs = baseCarbs;
      newFats = baseFats;
      break;

    case OilLevel.heavy:
      // Slightly more carbs + more oil/ghee
      newCarbs = (baseCarbs * 1.05).round();
      newFats = (baseFats * 1.40).round();
      break;
  }

  final newCalories =
      (newProtein * 4) +
      (newCarbs * 4) +
      (newFats * 9);

  return food.copyWith(
    protein: newProtein,
    carbs: newCarbs,
    fats: newFats,
    calories: newCalories,
  );
}

// ─────────────────────────────────────────
// PREFERENCE NOTIFIER (persisted via shared_preferences)
// Key: "oil_pref_<food_name_lowercased>"
// ─────────────────────────────────────────
class OilPreferenceNotifier extends Notifier<Map<String, OilLevel>> {
  static const _prefix = 'oil_pref_';

  @override
  Map<String, OilLevel> build() {
    _loadAll();
    return {};
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    final map = <String, OilLevel>{};
    for (final k in keys) {
      final raw = prefs.getString(k);
      if (raw != null) {
        map[k.substring(_prefix.length)] = OilLevelExt.fromString(raw);
      }
    }
    state = map;
  }

  OilLevel get(String foodName) =>
      state[foodName.toLowerCase()] ?? OilLevel.normal;

  Future<void> set(String foodName, OilLevel level) async {
    final key = foodName.toLowerCase();
    state = {...state, key: level};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', level.name);
  }
}

final oilPreferenceProvider =
    NotifierProvider<OilPreferenceNotifier, Map<String, OilLevel>>(
  OilPreferenceNotifier.new,
);
