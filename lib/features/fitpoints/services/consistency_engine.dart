import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/fitpoints_models.dart';
import '../../nutrition/models/food_item.dart';

/// Calculates adherence scoring, logging quality, consistency metrics,
/// and multiplier tier eligibility. Central source of truth for "how well
/// is the user actually performing?"
class ConsistencyEngine {
  // ─── Logging Quality ───────────────────────────────────────────────────────

  /// Evaluates the quality of today's meal logs collectively.
  LoggingQuality evaluateLoggingQuality({
    required List<MealLogEntry> todayLogs,
    required double dailyCalorieTarget,
    required double dailyProteinTarget,
  }) {
    if (todayLogs.isEmpty) return LoggingQuality.poor;

    final qualityScore = _computeLoggingQualityScore(
      logs: todayLogs,
      calorieTarget: dailyCalorieTarget,
      proteinTarget: dailyProteinTarget,
    );

    _log('Logging quality score: ${qualityScore.toStringAsFixed(2)}');

    if (qualityScore >= 0.75) return LoggingQuality.high;
    if (qualityScore >= 0.4) return LoggingQuality.normal;
    return LoggingQuality.poor;
  }

  double _computeLoggingQualityScore({
    required List<MealLogEntry> logs,
    required double calorieTarget,
    required double proteinTarget,
  }) {
    double score = 0.0;

    // 1. Calorie coverage (max 0.3)
    final totalCals = logs.fold<double>(0, (s, m) => s + m.calories);
    final calRatio = (totalCals / calorieTarget).clamp(0.0, 1.0);
    score += calRatio * 0.3;

    // 2. Protein coverage (max 0.2)
    final totalProtein = logs.fold<double>(0, (s, m) => s + m.proteinGrams);
    final proteinRatio = (totalProtein / proteinTarget).clamp(0.0, 1.0);
    score += proteinRatio * 0.2;

    // 3. Log count realism: 3–8 logs is healthy range (max 0.2)
    final logCount = logs.length;
    final countScore = logCount >= 3 ? (logCount <= 8 ? 1.0 : 0.6) : logCount / 3.0;
    score += countScore * 0.2;

    // 4. Time spread: prefer logs spread across day (max 0.15)
    score += _timeSpreadScore(logs) * 0.15;

    // 5. Meal uniqueness: penalise identical duplicates (max 0.15)
    score += _uniquenessScore(logs) * 0.15;

    return score.clamp(0.0, 1.0);
  }

  /// Returns 0–1. 1 = logs spread across multiple hours, 0 = all same timestamp.
  double _timeSpreadScore(List<MealLogEntry> logs) {
    if (logs.length < 2) return 0.5;
    final hours = logs.map((l) => l.loggedAt.hour).toSet();
    // Spread across ≥4 distinct hours = perfect
    return (hours.length / 4.0).clamp(0.0, 1.0);
  }

  /// Returns 0–1. Penalises if >60% of logs are near-identical.
  double _uniquenessScore(List<MealLogEntry> logs) {
    if (logs.length < 2) return 1.0;
    int duplicatePairs = 0;
    final total = logs.length * (logs.length - 1) / 2;
    for (int i = 0; i < logs.length; i++) {
      for (int j = i + 1; j < logs.length; j++) {
        if (_mealSimilarity(logs[i], logs[j]) > 0.85) duplicatePairs++;
      }
    }
    final dupRatio = duplicatePairs / total;
    return (1.0 - dupRatio).clamp(0.0, 1.0);
  }

  // ─── Daily Logging Completion ──────────────────────────────────────────────

  /// Returns true if user's logs qualify as "complete daily logging."
  /// Intentionally flexible — supports night-loggers, IFers, frequent snackers.
  bool isDailyLoggingComplete({
    required List<MealLogEntry> todayLogs,
    required double dailyCalorieTarget,
  }) {
    if (todayLogs.isEmpty) return false;

    final totalCals = todayLogs.fold<double>(0, (s, m) => s + m.calories);
    final calCoverage = totalCals / dailyCalorieTarget;

    // Path A: 5+ meaningful logs (each ≥80 kcal to exclude micro-spam)
    final meaningfulLogs = todayLogs.where((m) => m.calories >= 80).toList();
    if (meaningfulLogs.length >= 5) {
      _log('Daily logging: complete via 5+ meaningful logs');
      return true;
    }

    // Path B: calorie coverage ≥ 75% of target with uniqueness check
    if (calCoverage >= 0.75 && _uniquenessScore(todayLogs) > 0.5) {
      _log('Daily logging: complete via calorie coverage ($calCoverage)');
      return true;
    }

    _log('Daily logging: incomplete (cals=$totalCals, meaningful=${meaningfulLogs.length})');
    return false;
  }

  // ─── Consistency Metrics ───────────────────────────────────────────────────

  /// Computes full ConsistencyMetrics over a rolling window of daily data.
  ///
  /// [dailyLogs] keys are 'yyyy-MM-dd' strings.
  /// [dailyGoals] maps date → {'calories': x, 'protein': x, 'steps': x, 'hydration': x}
  ConsistencyMetrics computeMetrics({
    required String userId,
    required Map<String, List<MealLogEntry>> dailyLogs,
    required Map<String, Map<String, double>> dailyGoals,
    required int windowDays,
  }) {
    final now = DateTime.now();
    final dates = List.generate(
      windowDays,
      (i) => _dateKey(now.subtract(Duration(days: i))),
    );

    double totalAdherence = 0;
    double totalLoggingQuality = 0;
    double totalGoalCompletion = 0;
    int activeDays = 0;
    int consecutiveQuality = 0;
    bool qualityStreakBroken = false;

    for (final date in dates) {
      final logs = dailyLogs[date] ?? [];
      final goals = dailyGoals[date];

      if (logs.isEmpty) {
        if (!qualityStreakBroken) qualityStreakBroken = true;
        continue;
      }

      activeDays++;

      // Adherence: did user hit calorie + protein goals?
      if (goals != null) {
        final calTarget = goals['calories'] ?? 2000;
        final proteinTarget = goals['protein'] ?? 150;
        final totalCals = logs.fold<double>(0, (s, m) => s + m.calories);
        final totalProtein = logs.fold<double>(0, (s, m) => s + m.proteinGrams);
        final calAdherence = _adherenceRatio(totalCals, calTarget);
        final proteinAdherence = _adherenceRatio(totalProtein, proteinTarget);
        totalAdherence += (calAdherence + proteinAdherence) / 2;

        // Goal completion: 1.0 if both goals within 10%
        if (calAdherence >= 0.9 && proteinAdherence >= 0.9) totalGoalCompletion += 1.0;
        else totalGoalCompletion += (calAdherence + proteinAdherence) / 2;

        // Logging quality
        final quality = evaluateLoggingQuality(
          todayLogs: logs,
          dailyCalorieTarget: calTarget,
          dailyProteinTarget: proteinTarget,
        );
        totalLoggingQuality += quality == LoggingQuality.high
            ? 1.0
            : quality == LoggingQuality.normal
                ? 0.6
                : 0.2;

        if (!qualityStreakBroken && quality != LoggingQuality.poor) {
          consecutiveQuality++;
        } else {
          qualityStreakBroken = true;
        }
      }
    }

    final daysWithData = max(activeDays, 1);
    final metrics = ConsistencyMetrics(
      userId: userId,
      adherenceScore: (totalAdherence / daysWithData * 100).clamp(0, 100),
      loggingQualityScore: (totalLoggingQuality / daysWithData * 100).clamp(0, 100),
      goalCompletionRate: (totalGoalCompletion / daysWithData).clamp(0, 1),
      activeDayFrequency: activeDays / windowDays,
      consecutiveQualityDays: consecutiveQuality,
      calculatedAt: now,
    );

    _log(
      'ConsistencyMetrics for $userId: '
      'adherence=${metrics.adherenceScore.toStringAsFixed(1)}, '
      'logQuality=${metrics.loggingQualityScore.toStringAsFixed(1)}, '
      'goalRate=${metrics.goalCompletionRate.toStringAsFixed(2)}, '
      'activeDayFreq=${metrics.activeDayFrequency.toStringAsFixed(2)}',
    );

    return metrics;
  }

  // ─── Tier Eligibility ──────────────────────────────────────────────────────

  /// Determines correct StreakTier based on holistic metrics (not raw streak days alone).
  StreakTier computeTier({
    required int streakDays,
    required ConsistencyMetrics metrics,
  }) {
    final tierScore = _tierScore(streakDays: streakDays, metrics: metrics);

    final tier = tierScore >= 90
        ? StreakTier.legendary
        : tierScore >= 72
            ? StreakTier.titan
            : tierScore >= 52
                ? StreakTier.ironBeast
                : tierScore >= 30
                    ? StreakTier.heavyDumbbell
                    : StreakTier.lightDumbbell;

    _log(
      'Tier score: ${tierScore.toStringAsFixed(1)} → ${tier.displayName} (${tier.multiplier}x)',
    );
    return tier;
  }

  /// THE ONE SOURCE OF TRUTH: Calculates full consistency state.
  Future<ConsistencySnapshot> calculateSnapshot({
    required String userId,
    required bool isGuest,
    required Map<String, List<FoodItem>> historicalLogs,
    required Map<String, Map<String, double>> dailyGoals,
    required double currentFitPoints,
    required double currentMomentum,
  }) async {
    final now = DateTime.now();
    final hitDays = <String>{};
    
    // Window: 90 days for grid, 30 days for metrics
    const gridWindow = 90;
    const metricsWindow = 30;

    // 1. Calculate Hit Days & Streak
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;
    int weeklyHits = 0;
    int monthlyHits = 0;

    final monday = now.subtract(Duration(days: now.weekday - 1));
    final firstOfMonth = DateTime(now.year, now.month, 1);

    debugPrint('[Consistency] Starting streak calculation for user=$userId, isGuest=$isGuest');

    bool streakBroken = false;
    for (int i = 0; i < 200; i++) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      final logs = historicalLogs[key] ?? [];
      
      final active = ActiveDayEvaluator.isActiveDay(logs.cast<FoodItem>());
      
      if (active) {
        hitDays.add(key);
        tempStreak++;
        
        // Update stats
        if (!date.isBefore(monday)) {
          weeklyHits++;
          debugPrint('[Consistency] Weekly hit: day=$key, weeklyTotal=$weeklyHits');
        }
        if (!date.isBefore(firstOfMonth)) {
          monthlyHits++;
        }
        
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
      } else {
        // If we hit a gap...
        if (i == 0) {
          // Today is not active yet. We don't break the streak run, 
          // but we also haven't incremented tempStreak.
          debugPrint('[Consistency] Today (i=0) is not active yet. Run continues from yesterday.');
        } else {
          // A gap occurred on a day that IS NOT today. The current run ends.
          if (!streakBroken) {
            currentStreak = tempStreak;
            streakBroken = true;
            debugPrint('[Consistency] Gap found at i=$i ($key). Streak run ends at $currentStreak');
          }
          tempStreak = 0;
        }
      }
    }
    // If we never hit a gap in 200 days (unlikely but possible)
    if (!streakBroken) currentStreak = tempStreak;

    debugPrint('[Consistency] Final streak stats: current=$currentStreak, longest=$longestStreak, weeklyHits=$weeklyHits, monthlyHits=$monthlyHits');

    // 2. Compute Metrics (30d window)
    final metrics = computeMetrics(
      userId: userId,
      dailyLogs: historicalLogs.map((k, v) => MapEntry(k, v.map((f) {
        final item = f as FoodItem;
        return MealLogEntry(
          id: item.id,
          userId: userId,
          mealName: item.name,
          ingredients: item.ingredients ?? [item.name],
          calories: item.calories.toDouble(),
          proteinGrams: item.protein.toDouble(),
          carbGrams: item.carbs.toDouble(),
          fatGrams: item.fats.toDouble(),
          loggedAt: DateTime.fromMillisecondsSinceEpoch(item.timestamp),
        );
      }).toList())),
      dailyGoals: dailyGoals,
      windowDays: metricsWindow,
    );

    // 3. Compute Tier
    final tier = computeTier(streakDays: currentStreak, metrics: metrics);

    final snapshot = ConsistencySnapshot(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      weeklyActiveDays: weeklyHits,
      monthlyActiveDays: monthlyHits,
      momentum: currentMomentum,
      fitPoints: currentFitPoints,
      consistencyTier: tier,
      hitDays: hitDays,
      lastCalculated: now,
    );

    debugPrint('[Consistency] ✓ Snapshot complete: streak=${snapshot.currentStreak}, tier=${snapshot.consistencyTier.displayName}, fp=${snapshot.fitPoints}');

    return snapshot;
  }

  double _tierScore({
    required int streakDays,
    required ConsistencyMetrics metrics,
  }) {
    // Streak days contribute up to 30 points (capped at 60 days for scoring)
    final streakScore = (min(streakDays, 60) / 60) * 30;
    // Adherence contributes up to 25 points
    final adherenceScore = (metrics.adherenceScore / 100) * 25;
    // Logging quality contributes up to 20 points
    final qualityScore = (metrics.loggingQualityScore / 100) * 20;
    // Goal completion contributes up to 15 points
    final goalScore = metrics.goalCompletionRate * 15;
    // Active day frequency contributes up to 10 points
    final activityScore = metrics.activeDayFrequency * 10;

    return streakScore + adherenceScore + qualityScore + goalScore + activityScore;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Similarity between two meal logs (0.0 = totally different, 1.0 = identical).
  double _mealSimilarity(MealLogEntry a, MealLogEntry b) {
    double score = 0.0;

    // Calorie proximity
    final calDiff = (a.calories - b.calories).abs();
    final calSim = calDiff <= 50 ? 1.0 : calDiff <= 150 ? 0.5 : 0.0;
    score += calSim * 0.4;

    // Ingredient overlap
    final aIngredients = a.ingredients.map((s) => s.toLowerCase()).toSet();
    final bIngredients = b.ingredients.map((s) => s.toLowerCase()).toSet();
    if (aIngredients.isNotEmpty && bIngredients.isNotEmpty) {
      final intersection = aIngredients.intersection(bIngredients).length;
      final union = aIngredients.union(bIngredients).length;
      score += (intersection / union) * 0.4;
    }

    // Name similarity (simple)
    final nameSim = a.mealName.toLowerCase() == b.mealName.toLowerCase() ? 1.0 : 0.0;
    score += nameSim * 0.2;

    return score;
  }

  double _adherenceRatio(double actual, double target) {
    if (target <= 0) return 1.0;
    final ratio = actual / target;
    // 90–110% of target = 1.0, outside tapers
    if (ratio >= 0.9 && ratio <= 1.1) return 1.0;
    if (ratio < 0.9) return ratio / 0.9;
    return max(0, 1 - (ratio - 1.1) / 0.4);
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _log(String message) {
    // ignore: avoid_print
    debugPrint('[ConsistencyEngine] $message');
  }
}
