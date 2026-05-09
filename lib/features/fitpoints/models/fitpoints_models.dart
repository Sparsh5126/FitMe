import 'package:flutter/foundation.dart';
import '../../nutrition/models/food_item.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum StreakTier {
  lightDumbbell, // 1x
  heavyDumbbell, // 1.5x
  ironBeast, // 2.5x
  titan, // 3.5x
  legendary, // 5x
}

extension StreakTierExtension on StreakTier {
  String get displayName => switch (this) {
        StreakTier.lightDumbbell => 'Bronze Efficiency',
        StreakTier.heavyDumbbell => 'Silver Efficiency',
        StreakTier.ironBeast => 'Gold Efficiency',
        StreakTier.titan => 'Platinum Efficiency',
        StreakTier.legendary => 'Diamond Efficiency',
      };

  double get multiplier => switch (this) {
        StreakTier.lightDumbbell => 1.0,
        StreakTier.heavyDumbbell => 1.5,
        StreakTier.ironBeast => 2.5,
        StreakTier.titan => 3.5,
        StreakTier.legendary => 5.0,
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

  factory FitPointsRecord.fromJson(Map<String, dynamic> json) =>
      FitPointsRecord(
        userId: json['userId'] as String,
        lifetimePoints: (json['lifetimePoints'] as num).toDouble(),
        currentBalance: (json['currentBalance'] as num).toDouble(),
        currentTier: StreakTier.values.byName(json['currentTier'] as String),
        streakDays: json['streakDays'] as int,
        momentumScore: (json['momentumScore'] as num).toDouble(),
        lastActiveDate: DateTime.parse(json['lastActiveDate'] as String),
        dailyEarnings: Map<String, double>.from(
          (json['dailyEarnings'] as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ),
        ),
        isGuest: json['isGuest'] as bool,
      );

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
    required this.consistencyTier,
    required this.hitDays,
    required this.lastCalculated,
  });

  static ConsistencySnapshot empty() => ConsistencySnapshot(
        currentStreak: 0,
        longestStreak: 0,
        weeklyActiveDays: 0,
        monthlyActiveDays: 0,
        momentum: 0,
        fitPoints: 0,
        consistencyTier: StreakTier.lightDumbbell,
        hitDays: {},
        lastCalculated: DateTime.now(),
      );

  double get levelProgress {
    final thresholds = [0, 8, 22, 45, 90, 180];
    final idx = consistencyTier.index;
    final current = currentStreak;
    final start = thresholds[idx];
    final end = idx + 1 < thresholds.length ? thresholds[idx + 1] : 365;
    return ((current - start) / (end - start)).clamp(0.0, 1.0);
  }

  String get nextLevelLabel {
    final labels = ['Light Dumbbell', 'Heavy Dumbbell', 'Barbell', '1-Plate Barbell', '2-Plate Barbell', '4-Plate Barbell'];
    final idx = consistencyTier.index;
    return idx + 1 < labels.length ? labels[idx + 1] : 'Max Level';
  }

  int get daysToNextLevel {
    final thresholds = [0, 8, 22, 45, 90, 180];
    final idx = consistencyTier.index;
    if (idx + 1 >= thresholds.length) return 0;
    return thresholds[idx + 1] - currentStreak;
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
  /// A day is active if it has:
  /// - Meaningful nutrition logging (cumulative calories + sufficient logs), OR
  /// - Meaningful workout activity, OR
  /// - Meaningful adherence completion
  ///
  /// NOT:
  /// - App opens
  /// - Tiny spam logs (micro-calories)
  /// - Random edits
  static bool isActiveDay(List<FoodItem> logs) {
    if (logs.isEmpty) return false;

    // Filter out spam/junk logs
    final meaningfulLogs = logs.where((item) {
      final name = item.name.toLowerCase();
      // Exclude pure water/hydration-only items
      if (name == 'water' || name.contains('hydration')) {
        return false;
      }
      // Exclude micro-spam (very low calorie items)
      if (item.calories < _minCaloriesPerLog) {
        return false;
      }
      return true;
    }).toList();

    // Path 1: Meaningful nutrition logging
    if (meaningfulLogs.length >= _minLogsForActivity) {
      final totalCalories = meaningfulLogs.fold<double>(0, (s, item) => s + item.calories);
      if (totalCalories >= _minDailyCalories) {
        debugPrint('[ActiveDayEvaluator] Active via nutrition: ${meaningfulLogs.length} logs, ${totalCalories.toStringAsFixed(0)} cals');
        return true;
      }
    }

    // Path 2: TODO - Meaningful workout activity (when workouts are logged)
    // if (workouts.isNotEmpty && _hasCompletedWorkout(workouts)) {
    //   debugPrint('[ActiveDayEvaluator] Active via workout');
    //   return true;
    // }

    // Path 3: TODO - Meaningful adherence completion (when adherence tracking is active)
    // if (adherence.completionScore >= 0.7) {
    //   debugPrint('[ActiveDayEvaluator] Active via adherence');
    //   return true;
    // }

    return false;
  }

  /// Helper: check if a day has meaningful exercise activity
  /// (not just a walk, must be structured workout)
  static bool _hasCompletedWorkout(List<dynamic> workouts) {
    // TODO: Implement once workout structure is available
    return false;
  }

  /// Helper: check if adherence completion is meaningful
  static bool _hasCompletedAdherence(Map<String, dynamic>? adherenceData) {
    // TODO: Implement based on your adherence completion rules
    return false;
  }
}