import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user_profile.dart';
import '../../nutrition/models/food_item.dart';
import '../../nutrition/repositories/nutrition_repository.dart';

class FitPointsService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Points per action ─────────────────────
  static const int _pointsPerMacroHit = 10;      // all 4 macros within range
  static const int _pointsPerProteinHit = 5;     // just protein goal hit
  static const int _pointsPerFoodLogged = 1;     // any food logged
  static const int _pointsPerStreakDay = 3;       // streak bonus per day
  static const int _pointsPerWorkout = 20;        // full workout completed
  static const int _pointsPerPR = 15;             // personal record hit

  // ─────────────────────────────────────────
  // EVALUATE DAILY POINTS
  // Call once per day (midnight or on app open)
  // ─────────────────────────────────────────
  static Future<void> evaluateDay(UserProfile profile) async {
    final today = FoodItem.dateFor(DateTime.now());
    final doc = await _db.collection('users').doc(_uid).get();
    final data = doc.data() ?? {};

    final lastEvaluated = data['fitPointsLastEvaluated'] as String? ?? '';
    if (lastEvaluated == today) return;

    final repo = NutritionRepository();
    final logs = await repo.getLogsForDate(today);

    int earned = 0;

    // Points for logging any food
    if (logs.isNotEmpty) earned += _pointsPerFoodLogged * logs.length.clamp(0, 5);

    // Macro totals
    int cals = 0, pro = 0, carbs = 0, fats = 0;
    for (final l in logs) {
      cals += l.calories; pro += l.protein; carbs += l.carbs; fats += l.fats;
    }

    // Points for hitting protein
    final proteinHit = _withinRange(pro, profile.dynamicProtein);
    if (proteinHit) earned += _pointsPerProteinHit;

    // Points for hitting all macros
    final allHit = proteinHit &&
        _withinRange(carbs, profile.dynamicCarbs) &&
        _withinRange(fats, profile.dynamicFats) &&
        _withinRange(cals, profile.dynamicCalories);
    if (allHit) earned += _pointsPerMacroHit;

    // Streak bonus
    final streak = data['currentStreak'] as int? ?? 0;
    if (streak > 0 && logs.isNotEmpty) earned += (_pointsPerStreakDay * (streak / 7).ceil()).clamp(0, 20);

    // Add to total
    final current = data['fitPoints'] as int? ?? 0;
    final history = List<Map>.from(data['fitPointsHistory'] as List? ?? []);
    history.add({'date': today, 'points': earned, 'reason': _buildReason(proteinHit, allHit, logs.length)});

    await _db.collection('users').doc(_uid).update({
      'fitPoints': current + earned,
      'fitPointsHistory': history.length > 180 ? history.sublist(history.length - 180) : history,
      'fitPointsLastEvaluated': today,
    });
  }

  // Call when a workout is completed
  static Future<void> awardWorkout({bool isPR = false}) async {
    final points = _pointsPerWorkout + (isPR ? _pointsPerPR : 0);
    await _addPoints(points, isPR ? 'Workout + PR!' : 'Workout completed');
  }

  // ─────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────
  static Future<int> getTotalPoints() async {
    final doc = await _db.collection('users').doc(_uid).get();
    return (doc.data()?['fitPoints'] as int?) ?? 0;
  }

  static Future<List<Map>> getHistory() async {
    final doc = await _db.collection('users').doc(_uid).get();
    return List<Map>.from(doc.data()?['fitPointsHistory'] as List? ?? []);
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────

  // Within ±10% of goal counts as a hit
  static bool _withinRange(int actual, int goal) {
    final min = (goal * 0.85).round();
    final max = (goal * 1.10).round();
    return actual >= min && actual <= max;
  }

  static Future<void> _addPoints(int points, String reason) async {
    final today = FoodItem.dateFor(DateTime.now());
    final doc = await _db.collection('users').doc(_uid).get();
    final current = (doc.data()?['fitPoints'] as int?) ?? 0;
    final history = List<Map>.from(doc.data()?['fitPointsHistory'] as List? ?? []);
    history.add({'date': today, 'points': points, 'reason': reason});

    await _db.collection('users').doc(_uid).update({
      'fitPoints': current + points,
      'fitPointsHistory': history,
    });
  }

  static String _buildReason(bool proteinHit, bool allHit, int meals) {
    if (allHit) return 'All macros hit!';
    if (proteinHit) return 'Protein goal hit';
    if (meals > 0) return 'Logged $meals meals';
    return 'Daily check-in';
  }
}