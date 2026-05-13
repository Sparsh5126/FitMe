import 'package:flutter/foundation.dart';
import '../../nutrition/models/food_item.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum StreakTier {
  lightDumbbell, // 1x
  heavyDumbbell, // 1.5x
  barbell, // 2x
  onePlateBarbell, // 3x
  twoPlateBarbell, // 5x
  fourPlateBarbell; // 8x

  static const maxLevel = StreakTier.fourPlateBarbell;
}

typedef ConsistencyTier = StreakTier;
typedef StreakLevel = StreakTier;

extension StreakTierExtension on StreakTier {
  /// Displayed on the Streak Page (Weight-based)
  String get streakLabel => switch (this) {
        StreakTier.lightDumbbell => 'Light Dumbbell',
        StreakTier.heavyDumbbell => 'Heavy Dumbbell',
        StreakTier.barbell => 'Barbell',
        StreakTier.onePlateBarbell => '1 Plate Barbell',
        StreakTier.twoPlateBarbell => '2 Plate Barbell',
        StreakTier.fourPlateBarbell => '4 Plate Barbell',
      };

  /// Displayed on Insights & Award Popups (Metal-based)
  String get efficiencyLabel => switch (this) {
        StreakTier.lightDumbbell => 'Bronze Efficiency',
        StreakTier.heavyDumbbell => 'Silver Efficiency',
        StreakTier.barbell => 'Gold Efficiency',
        StreakTier.onePlateBarbell => 'Platinum Efficiency',
        StreakTier.twoPlateBarbell => 'Diamond Efficiency',
        StreakTier.fourPlateBarbell => 'Diamond Efficiency',
      };

  /// Legacy display name for backward compatibility
  String get displayName => efficiencyLabel;

  double get multiplier => switch (this) {
        StreakTier.lightDumbbell => 1.0,
        StreakTier.heavyDumbbell => 1.5,
        StreakTier.barbell => 2.0,
        StreakTier.onePlateBarbell => 3.0,
        StreakTier.twoPlateBarbell => 5.0,
        StreakTier.fourPlateBarbell => 5.0,
      };
}

enum LoggingQuality { poor, normal, high }

extension LoggingQualityExtension on LoggingQuality {
  double get modifier => switch (this) {
        LoggingQuality.poor => 0.5,
        LoggingQuality.normal => 1.0,
        LoggingQuality.high => 1.25,
      };
}

enum FitPointAction {
  // Nutrition
  logMeal,
  completeDailyLogging,
  hitProteinGoal,
  hitCalorieTarget,
  hitMacroAdherence,
  completeHydrationGoal,
  // Fitness
  completeThreeExercises,
  completeWorkout,
  hitStepGoal,
  completeActiveRecovery,
  createCustomWorkoutPlan,
  followGeneratedWorkoutPlan,
  completeWorkoutPlanAnalysis,
  shareWorkoutWithFriend,
  shareAppOnSocial,
  // Intelligence / Planning
  createUsefulCustomMeal,
  createRecipe,
  completeDietAnalysis,
  followGeneratedDietPlanDay,
}

extension FitPointActionExtension on FitPointAction {
  double get basePoints => switch (this) {
        FitPointAction.logMeal => 1,
        FitPointAction.completeDailyLogging => 2,
        FitPointAction.hitProteinGoal => 1,
        FitPointAction.hitCalorieTarget => 1,
        FitPointAction.hitMacroAdherence => 1,
        FitPointAction.completeHydrationGoal => 1,
        FitPointAction.completeThreeExercises => 1,
        FitPointAction.completeWorkout => 2,
        FitPointAction.hitStepGoal => 1,
        FitPointAction.completeActiveRecovery => 1,
        FitPointAction.createCustomWorkoutPlan => 2,
        FitPointAction.followGeneratedWorkoutPlan => 2,
        FitPointAction.completeWorkoutPlanAnalysis => 2,
        FitPointAction.shareWorkoutWithFriend => 2,
        FitPointAction.shareAppOnSocial => 10,
        FitPointAction.createUsefulCustomMeal => 1,
        FitPointAction.createRecipe => 2,
        FitPointAction.completeDietAnalysis => 2,
        FitPointAction.followGeneratedDietPlanDay => 2,
      };

  /// Max times this action earns FP per day (null = no cap beyond daily total)
  int? get dailyActionCap => switch (this) {
        FitPointAction.logMeal => 8,
        FitPointAction.shareAppOnSocial => null, // monthly cap handled separately
        FitPointAction.shareWorkoutWithFriend => 5,
        _ => 1,
      };
}

enum ChallengeStatus { pending, active, completed, cancelled, disputed }

enum ChallengeType { goalWeight, accountability, custom }

// ─── Core Models ─────────────────────────────────────────────────────────────

@immutable
class FitPointsRecord {
  final String userId;
  final double lifetimePoints;
  final double currentBalance;
  final StreakTier currentTier;
  final int streakDays;
  final double momentumScore; // 0–100
  final DateTime lastActiveDate;
  final Map<String, double> dailyEarnings; // date string → points earned
  final bool isGuest;

  const FitPointsRecord({
    required this.userId,
    required this.lifetimePoints,
    required this.currentBalance,
    required this.currentTier,
    required this.streakDays,
    required this.momentumScore,
    required this.lastActiveDate,
    required this.dailyEarnings,
    required this.isGuest,
  });

  FitPointsRecord copyWith({
    double? lifetimePoints,
    double? currentBalance,
    StreakTier? currentTier,
    int? streakDays,
    double? momentumScore,
    DateTime? lastActiveDate,
    Map<String, double>? dailyEarnings,
    bool? isGuest,
  }) {
    return FitPointsRecord(
      userId: userId,
      lifetimePoints: lifetimePoints ?? this.lifetimePoints,
      currentBalance: currentBalance ?? this.currentBalance,
      currentTier: currentTier ?? this.currentTier,
      streakDays: streakDays ?? this.streakDays,
      momentumScore: momentumScore ?? this.momentumScore,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      dailyEarnings: dailyEarnings ?? this.dailyEarnings,
      isGuest: isGuest ?? this.isGuest,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'lifetimePoints': lifetimePoints,
        'currentBalance': currentBalance,
        'currentTier': currentTier.name,
        'streakDays': streakDays,
        'momentumScore': momentumScore,
        'lastActiveDate': lastActiveDate.toIso8601String(),
        'dailyEarnings': dailyEarnings,
        'isGuest': isGuest,
      };

  factory FitPointsRecord.fromJson(Map<String, dynamic> json) {
    try {
      return FitPointsRecord(
        userId: json['userId'] as String? ?? '',
        lifetimePoints: (json['lifetimePoints'] as num? ??
                json['currentBalance'] as num? ??
                0.0)
            .toDouble(),
        currentBalance: (json['currentBalance'] as num? ?? 0.0).toDouble(),
        currentTier: json['currentTier'] != null
            ? StreakTier.values.byName(json['currentTier'] as String)
            : StreakTier.lightDumbbell,
        streakDays: json['streakDays'] as int? ?? 0,
        momentumScore: (json['momentumScore'] as num? ?? 0.0).toDouble(),
        lastActiveDate: json['lastActiveDate'] != null
            ? DateTime.parse(json['lastActiveDate'] as String)
            : DateTime.now(),
        dailyEarnings: json['dailyEarnings'] != null
            ? Map<String, double>.from(
                (json['dailyEarnings'] as Map).map(
                  (k, v) => MapEntry(k as String, (v as num).toDouble()),
                ),
              )
            : {},
        isGuest: json['isGuest'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('[FitPointsRecord] Error parsing JSON: $e');
      // Return a basic record as fallback instead of crashing the migration
      return FitPointsRecord.newGuest(json['userId'] as String? ?? 'error');
    }
  }

  factory FitPointsRecord.newGuest(String guestId) => FitPointsRecord(
        userId: guestId,
        lifetimePoints: 0,
        currentBalance: 0,
        currentTier: StreakTier.lightDumbbell,
        streakDays: 0,
        momentumScore: 0,
        lastActiveDate: DateTime.now(),
        dailyEarnings: {},
        isGuest: true,
      );
}

@immutable
class FitPointTransaction {
  final String id;
  final String userId;
  final FitPointAction action;
  final double basePoints;
  final double streakMultiplier;
  final double qualityModifier;
  final double finalPoints;
  final DateTime timestamp;
  final String? metadata; // JSON string for extra context

  const FitPointTransaction({
    required this.id,
    required this.userId,
    required this.action,
    required this.basePoints,
    required this.streakMultiplier,
    required this.qualityModifier,
    required this.finalPoints,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'action': action.name,
        'basePoints': basePoints,
        'streakMultiplier': streakMultiplier,
        'qualityModifier': qualityModifier,
        'finalPoints': finalPoints,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  factory FitPointTransaction.fromJson(Map<String, dynamic> json) =>
      FitPointTransaction(
        id: json['id'] as String,
        userId: json['userId'] as String,
        action: FitPointAction.values.byName(json['action'] as String),
        basePoints: (json['basePoints'] as num).toDouble(),
        streakMultiplier: (json['streakMultiplier'] as num).toDouble(),
        qualityModifier: (json['qualityModifier'] as num).toDouble(),
        finalPoints: (json['finalPoints'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        metadata: json['metadata'] as String?,
      );
}

@immutable
class MealLogEntry {
  final String id;
  final String userId;
  final String mealName;
  final List<String> ingredients;
  final double calories;
  final double proteinGrams;
  final double carbGrams;
  final double fatGrams;
  final DateTime loggedAt;

  const MealLogEntry({
    required this.id,
    required this.userId,
    required this.mealName,
    required this.ingredients,
    required this.calories,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
    required this.loggedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'mealName': mealName,
        'ingredients': ingredients,
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbGrams': carbGrams,
        'fatGrams': fatGrams,
        'loggedAt': loggedAt.toIso8601String(),
      };

  factory MealLogEntry.fromJson(Map<String, dynamic> json) => MealLogEntry(
        id: json['id'] as String,
        userId: json['userId'] as String,
        mealName: json['mealName'] as String,
        ingredients: List<String>.from(json['ingredients'] as List),
        calories: (json['calories'] as num).toDouble(),
        proteinGrams: (json['proteinGrams'] as num).toDouble(),
        carbGrams: (json['carbGrams'] as num).toDouble(),
        fatGrams: (json['fatGrams'] as num).toDouble(),
        loggedAt: DateTime.parse(json['loggedAt'] as String),
      );
}

@immutable
class ConsistencyMetrics {
  final String userId;
  final double adherenceScore; // 0–100
  final double loggingQualityScore; // 0–100
  final double goalCompletionRate; // 0–1
  final double activeDayFrequency; // active days / total days observed
  final int consecutiveQualityDays;
  final DateTime calculatedAt;

  const ConsistencyMetrics({
    required this.userId,
    required this.adherenceScore,
    required this.loggingQualityScore,
    required this.goalCompletionRate,
    required this.activeDayFrequency,
    required this.consecutiveQualityDays,
    required this.calculatedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'adherenceScore': adherenceScore,
        'loggingQualityScore': loggingQualityScore,
        'goalCompletionRate': goalCompletionRate,
        'activeDayFrequency': activeDayFrequency,
        'consecutiveQualityDays': consecutiveQualityDays,
        'calculatedAt': calculatedAt.toIso8601String(),
      };
}

@immutable
class Challenge {
  final String id;
  final ChallengeType type;
  final ChallengeStatus status;
  final List<String> participantIds;
  final Map<String, double> stakes; // userId → FP staked
  final double bonusPool; // FitMe contributed bonus
  final DateTime createdAt;
  final DateTime startsAt;
  final DateTime endsAt;
  final Map<String, dynamic> goalConfig; // type-specific config
  final Map<String, ChallengeProgress> progress;
  final String? winnerId; // null for accountability challenges

  const Challenge({
    required this.id,
    required this.type,
    required this.status,
    required this.participantIds,
    required this.stakes,
    required this.bonusPool,
    required this.createdAt,
    required this.startsAt,
    required this.endsAt,
    required this.goalConfig,
    required this.progress,
    this.winnerId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'status': status.name,
        'participantIds': participantIds,
        'stakes': stakes,
        'bonusPool': bonusPool,
        'createdAt': createdAt.toIso8601String(),
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'goalConfig': goalConfig,
        'progress': progress.map((k, v) => MapEntry(k, v.toJson())),
        'winnerId': winnerId,
      };
}

@immutable
class ChallengeProgress {
  final String userId;
  final double completionPercent; // 0–100
  final double consistencyScore;
  final double adherenceScore;
  final List<DateTime> activeDays;
  final Map<String, dynamic> goalSpecificData;

  const ChallengeProgress({
    required this.userId,
    required this.completionPercent,
    required this.consistencyScore,
    required this.adherenceScore,
    required this.activeDays,
    required this.goalSpecificData,
  });

  /// Composite score used for ranking (not raw goal change)
  double get rankingScore =>
      (completionPercent * 0.5) +
      (consistencyScore * 0.3) +
      (adherenceScore * 0.2);

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'completionPercent': completionPercent,
        'consistencyScore': consistencyScore,
        'adherenceScore': adherenceScore,
        'activeDays': activeDays.map((d) => d.toIso8601String()).toList(),
        'goalSpecificData': goalSpecificData,
      };
}

@immutable
class FpAwardResult {
  final bool awarded;
  final double pointsEarned;
  final String reason; // human-readable explanation
  final bool cappedByDaily;
  final bool reducedByDuplicate;
  final bool reducedByQuality;

  const FpAwardResult({
    required this.awarded,
    required this.pointsEarned,
    required this.reason,
    this.cappedByDaily = false,
    this.reducedByDuplicate = false,
    this.reducedByQuality = false,
  });

  static const FpAwardResult spam = FpAwardResult(
    awarded: false,
    pointsEarned: 0,
    reason: 'Spam detected — no FP awarded.',
    reducedByDuplicate: true,
  );
}

@immutable
class ConsistencySnapshot {
  final int currentStreak;
  final int longestStreak;
  final int weeklyActiveDays;
  final int monthlyActiveDays;
  final double momentum;
  final double fitPoints;
  final double lifetimePoints;
  final StreakTier consistencyTier;
  final Set<String> hitDays;
  final DateTime lastCalculated;

  const ConsistencySnapshot({
    required this.currentStreak,
    required this.longestStreak,
    required this.weeklyActiveDays,
    required this.monthlyActiveDays,
    required this.momentum,
    required this.fitPoints,
    required this.lifetimePoints,
    required this.consistencyTier,
    required this.hitDays,
    required this.lastCalculated,
  });

  StreakLevel get streakLevel => consistencyTier;

  static ConsistencySnapshot empty() => ConsistencySnapshot(
        currentStreak: 0,
        longestStreak: 0,
        weeklyActiveDays: 0,
        monthlyActiveDays: 0,
        momentum: 0,
        fitPoints: 0,
        lifetimePoints: 0,
        consistencyTier: StreakTier.lightDumbbell,
        hitDays: {},
        lastCalculated: DateTime.now(),
      );

  double get levelProgress {
    final thresholds = [0, 8, 22, 45, 90, 150, 180];
    final idx = consistencyTier.index;
    final current = currentStreak;
    final start = thresholds[idx];
    final end = idx + 1 < thresholds.length ? thresholds[idx + 1] : thresholds.last;
    return ((current - start) / (end - start)).clamp(0.0, 1.0);
  }

  String get nextLevelLabel {
    if (consistencyTier == StreakTier.maxLevel) return 'Max Efficiency';
    final nextTier = StreakTier.values[consistencyTier.index + 1];
    return nextTier.efficiencyLabel;
  }

  int get daysToNextLevel {
    final thresholds = [0, 8, 22, 45, 90, 150, 180];
    final idx = consistencyTier.index;
    if (idx + 1 >= thresholds.length) return 0;
    return thresholds[idx + 1] - currentStreak;
  }
}

// ─────────────────────────────────────────────
// ADHERENCE EVALUATOR
// ─────────────────────────────────────────────

enum AdherenceLevel {
  perfect, // ±10% cals, ±15% protein
  good, // ±20% cals
  fair, // Logged meaningful cals but missed targets
  poor, // Very few cals or no logs
}

class AdherenceEvaluator {
  static AdherenceLevel evaluate({
    required List<MealLogEntry> logs,
    required double calorieTarget,
    required double proteinTarget,
  }) {
    if (logs.isEmpty) return AdherenceLevel.poor;

    final totalCals = logs.fold<double>(0, (s, m) => s + m.calories);
    final totalPro = logs.fold<double>(0, (s, m) => s + m.proteinGrams);

    final calDiff = (totalCals - calorieTarget).abs() / calorieTarget;
    final proDiff = (totalPro - proteinTarget).abs() / proteinTarget;

    if (calDiff <= 0.1 && proDiff <= 0.15) return AdherenceLevel.perfect;
    if (calDiff <= 0.2) return AdherenceLevel.good;
    if (totalCals >= 300) return AdherenceLevel.fair;
    return AdherenceLevel.poor;
  }
}

/// Unified central logic for active day evaluation.
/// The ONLY place where we define what makes a day "active" for consistency/streak purposes.
class ActiveDayEvaluator {
  /// Min calories per log to count as "meaningful" (excludes water, micro-spam)
  static const double _minCaloriesPerLog = 20.0;

  /// Min total calories per day to count as "meaningful nutrition logging"
  static const double _minDailyCalories = 300.0;

  /// Min logs per day to count as "meaningful logging"
  static const int _minLogsForActivity = 1;

  /// Unified logic to determine if a day was "active" for consistency purposes.
  static bool isActiveDay(List<FoodItem> logs, {List<dynamic>? workouts}) {
    // Path 1: Meaningful nutrition logging
    if (logs.isNotEmpty) {
      final meaningfulLogs = logs.where((item) {
        final name = item.name.toLowerCase();
        if (name == 'water' || name.contains('hydration')) return false;
        if (item.calories < _minCaloriesPerLog) return false;
        return true;
      }).toList();

      if (meaningfulLogs.length >= _minLogsForActivity) {
        final totalCalories = meaningfulLogs.fold<double>(0, (s, item) => s + item.calories);
        if (totalCalories >= _minDailyCalories) {
          debugPrint('[ActiveDayEvaluator] Active via nutrition: ${meaningfulLogs.length} logs, ${totalCalories.toStringAsFixed(0)} cals');
          return true;
        }
      }
    }

    // Path 2: Meaningful workout activity
    if (workouts != null && workouts.isNotEmpty) {
      if (_hasCompletedWorkout(workouts)) {
        debugPrint('[ActiveDayEvaluator] Active via workout: ${workouts.length} sessions');
        return true;
      }
    }

    return false;
  }

  /// Helper: check if a day has meaningful exercise activity
  static bool _hasCompletedWorkout(List<dynamic> workouts) {
    for (final w in workouts) {
      // Duck typing or explicit check depending on model availability
      // Assuming w has 'isCompleted' or similar
      try {
        if (w.isCompleted == true) return true;
        if (w.totalVolume > 0) return true;
        if (w.totalSets > 0) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Helper: check if adherence completion is meaningful
  static bool _hasCompletedAdherence(Map<String, dynamic>? adherenceData) {
    // TODO: Implement based on your adherence completion rules
    return false;
  }
}