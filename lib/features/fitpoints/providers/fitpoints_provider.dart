import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:fitme/features/fitpoints/services/fitpoints_service.dart';
import 'package:fitme/features/fitpoints/models/fitpoints_models.dart';
import 'package:fitme/features/auth/providers/auth_provider.dart';
import 'package:fitme/features/nutrition/providers/nutrition_provider.dart';
import 'package:fitme/features/dashboard/providers/user_provider.dart';
import 'package:fitme/features/fitpoints/services/consistency_engine.dart';

import 'package:fitme/features/nutrition/repositories/nutrition_repository.dart';
import 'package:fitme/features/nutrition/models/food_item.dart';
import 'package:fitme/features/workout/repositories/workout_repository.dart';
import 'package:fitme/core/models/workout.dart';

final consistencyEngineProvider = Provider<ConsistencyEngine>((ref) {
  return ConsistencyEngine();
});

final fitPointsServiceProvider = Provider<FitPointsService>((ref) {
  final engine = ref.watch(consistencyEngineProvider);
  return FitPointsService(consistencyEngine: engine);
});

final consistencySnapshotProvider = FutureProvider<ConsistencySnapshot>((
  ref,
) async {
  final authState = ref.watch(authStateProvider);
  final isGuest = ref.watch(isGuestProvider);
  final service = ref.watch(fitPointsServiceProvider);
  final engine = ref.watch(consistencyEngineProvider);
  final userProfile = ref.watch(userProfileProvider).value;

  // Re-calculate when nutrition logs or FitPoints balance change
  ref.watch(nutritionProvider);
  ref.watch(fitPointsProvider);

  final userId = authState.value?.uid ?? (isGuest ? 'guest_user' : '');
  if (userId.isEmpty && !isGuest) {
    debugPrint(
      '[ConsistencySnapshot] No userId and not guest, returning empty',
    );
    return ConsistencySnapshot.empty();
  }

  debugPrint(
    '[ConsistencySnapshot] Starting snapshot calculation for userId=$userId, isGuest=$isGuest',
  );

  // 1. Fetch current FP record
  final record = await service.getRecord(userId, isGuest);
  double currentFP = record.currentBalance;
  double lifetimeFP = record.lifetimePoints;

  // FALLBACK: If record shows 0 but we aren't a fresh guest, check for transactions
  if (currentFP == 0 && userId.isNotEmpty) {
    try {
      final txs = await service.getRecentTransactions(userId, 500);
      if (txs.isNotEmpty) {
        currentFP = txs.fold(0.0, (sum, t) => sum + t.finalPoints);
        // Also update lifetimeFP from transactions if it's also 0
        if (lifetimeFP == 0) {
          lifetimeFP = currentFP;
        }
        debugPrint(
          '[ConsistencySnapshot] Fallback balance recovered from ${txs.length} transactions: $currentFP',
        );
      }
    } catch (e) {
      debugPrint('[ConsistencySnapshot] Fallback recovery failed: $e');
    }
  }

  debugPrint(
    '[ConsistencySnapshot] Fetched record: balance=$currentFP, lifetime=$lifetimeFP, tier=${record.currentTier.displayName}',
  );

  // 2. Fetch historical logs & workouts (last 90 days)
  final repo = NutritionRepository();
  final workoutRepo = WorkoutRepository();
  final now = DateTime.now();
  final historicalLogs = <String, List<FoodItem>>{};
  final historicalWorkouts = <String, List<Workout>>{};

  final startDate = now.subtract(const Duration(days: 89));

  debugPrint('[ConsistencySnapshot] Fetching historical logs & workouts...');
  final allLogs = await repo.getLogsForRange(startDate, now);

  List<Workout> allWorkouts = [];
  try {
    allWorkouts = await workoutRepo.getWorkoutsForRange(startDate, now);
  } catch (e) {
    debugPrint(
      '[ConsistencySnapshot] Error fetching workouts: $e. Continuing with logs only.',
    );
  }

  for (final log in allLogs) {
    if (!historicalLogs.containsKey(log.dateString)) {
      historicalLogs[log.dateString] = [];
    }
    historicalLogs[log.dateString]!.add(log);
  }

  for (final w in allWorkouts) {
    if (!historicalWorkouts.containsKey(w.dateString)) {
      historicalWorkouts[w.dateString] = [];
    }
    historicalWorkouts[w.dateString]!.add(w);
  }

  debugPrint(
    '[ConsistencySnapshot] Data fetched: ${allLogs.length} logs, ${allWorkouts.length} workouts',
  );

  // 3. Prepare goals
  final goals = <String, Map<String, double>>{};
  if (userProfile != null) {
    // Simplified: Use current profile goals for all days
    // In a mature app, we'd use historical profile snapshots
    for (var key in historicalLogs.keys) {
      goals[key] = {
        'calories': userProfile.dynamicCalories.toDouble(),
        'protein': userProfile.dynamicProtein.toDouble(),
      };
    }
    debugPrint(
      '[ConsistencySnapshot] Using goals: calories=${userProfile.dynamicCalories}, protein=${userProfile.dynamicProtein}',
    );
  }

  // 4. Calculate Snapshot
  debugPrint('[ConsistencySnapshot] Calling engine.calculateSnapshot...');
  final snapshot = await engine.calculateSnapshot(
    userId: userId,
    isGuest: isGuest,
    historicalLogs: historicalLogs,
    historicalWorkouts: historicalWorkouts,
    dailyGoals: goals,
    currentFitPoints: currentFP,
    lifetimePoints: lifetimeFP,
    currentMomentum: record.momentumScore,
  );

  debugPrint(
    '[ConsistencySnapshot] ✓ Provider complete: streak=${snapshot.currentStreak}, fitPoints=${snapshot.fitPoints.toInt()}',
  );

  return snapshot;
});

// Backward compatibility or legacy wrapper
final fitPointsProvider = StreamProvider<FitPointsRecord>((ref) {
  final authState = ref.watch(authStateProvider);
  final isGuest = ref.watch(isGuestProvider);
  final service = ref.watch(fitPointsServiceProvider);
  final userId = authState.value?.uid ?? '';
  return service.getRecordStream(userId, isGuest);
});
