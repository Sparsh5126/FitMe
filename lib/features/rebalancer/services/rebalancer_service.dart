import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user_profile.dart';
import '../../nutrition/models/food_item.dart';
import '../../nutrition/repositories/nutrition_repository.dart';

class RebalancerService {
  static final _db = FirebaseFirestore.instance;
  static final _repo = NutritionRepository();

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ─────────────────────────────────────────
  // CALL THIS ON APP OPEN
  // Checks if rebalance is due and runs it
  // ─────────────────────────────────────────
  static Future<void> runIfDue() async {
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final profile = UserProfile.fromMap(data);
    final today = _dateStr(DateTime.now());
    final lastRun = data['rebalancerLastRun'] as String? ?? '';

    // Already ran today — skip
    if (lastRun == today) return;

    final now = DateTime.now();

    // Monday reset: restore dynamic goals to base goals
    if (now.weekday == DateTime.monday) {
      await _resetToBase(profile, today);
      return;
    }

    // Any other day: calculate adjusted goals
    await _rebalance(profile, today);
  }

  // ─────────────────────────────────────────
  // MONDAY RESET
  // ─────────────────────────────────────────
  static Future<void> _resetToBase(UserProfile profile, String today) async {
    await _db.collection('users').doc(_uid).update({
      'dynamicCalories': profile.dailyCalories,
      'dynamicProtein': profile.dailyProtein,
      'dynamicCarbs': profile.dailyCarbs,
      'dynamicFats': profile.dailyFats,
      'rebalancerLastRun': today,
    });
  }

  // ─────────────────────────────────────────
  // REBALANCE LOGIC
  // ─────────────────────────────────────────
  static Future<void> _rebalance(UserProfile profile, String today) async {
    final now = DateTime.now();

    // Find start of current week (Monday)
    final monday = now.subtract(Duration(days: now.weekday - 1));

    // Fetch all logs from Monday to yesterday
    final logs = await _repo.getLogsForWeek(monday);

    // Days elapsed this week (not counting today)
    final daysElapsed = now.weekday - 1; // Mon=1, so today - 1
    final daysRemaining = 7 - now.weekday; // days left after today

    if (daysElapsed == 0 || daysRemaining == 0) {
      await _db.collection('users').doc(_uid).update({'rebalancerLastRun': today});
      return;
    }

    // Target for days elapsed (excluding today)
    final targetCalories = profile.dailyCalories * daysElapsed;
    final targetProtein = profile.dailyProtein * daysElapsed;
    final targetCarbs = profile.dailyCarbs * daysElapsed;
    final targetFats = profile.dailyFats * daysElapsed;

    // Actual consumed Mon–yesterday
    double actualCalories = 0, actualProtein = 0, actualCarbs = 0, actualFats = 0;
    for (final log in logs) {
      // Only count logs before today
      final logDate = DateTime.parse(log.dateString);
      if (logDate.isBefore(DateTime(now.year, now.month, now.day))) {
        actualCalories += log.calories;
        actualProtein += log.protein;
        actualCarbs += log.carbs;
        actualFats += log.fats;
      }
    }

    // Debt/credit: positive = under-consumed (need more), negative = over-consumed
    final debtCalories = targetCalories - actualCalories;
    final debtProtein = targetProtein - actualProtein;
    final debtCarbs = targetCarbs - actualCarbs;
    final debtFats = targetFats - actualFats;

    // Spread debt across remaining days
    final adjustCalories = (debtCalories / daysRemaining).round();
    final adjustProtein = (debtProtein / daysRemaining).round();
    final adjustCarbs = (debtCarbs / daysRemaining).round();
    final adjustFats = (debtFats / daysRemaining).round();

    // New dynamic goals
    final newCalories = profile.dailyCalories + adjustCalories;
    final newProtein = profile.dailyProtein + adjustProtein;
    final newCarbs = profile.dailyCarbs + adjustCarbs;
    final newFats = profile.dailyFats + adjustFats;

    // Apply ±20% safety cap
    final cappedCalories = _cap(newCalories, profile.dailyCalories);
    final cappedProtein = _cap(newProtein, profile.dailyProtein);
    final cappedCarbs = _cap(newCarbs, profile.dailyCarbs);
    final cappedFats = _cap(newFats, profile.dailyFats);

    await _db.collection('users').doc(_uid).update({
      'dynamicCalories': cappedCalories,
      'dynamicProtein': cappedProtein,
      'dynamicCarbs': cappedCarbs,
      'dynamicFats': cappedFats,
      'rebalancerLastRun': today,
    });
  }

  // ±20% cap — clamps new goal between 80% and 120% of base
  static int _cap(int newGoal, int baseGoal) {
    final min = (baseGoal * 0.8).round();
    final max = (baseGoal * 1.2).round();
    return newGoal.clamp(min, max);
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}