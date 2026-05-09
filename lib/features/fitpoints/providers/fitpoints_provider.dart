import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/fitpoints_service.dart';
import '../models/fitpoints_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../nutrition/providers/nutrition_provider.dart';
import '../../dashboard/providers/user_provider.dart';
import '../services/consistency_engine.dart';

import '../../nutrition/repositories/nutrition_repository.dart';
import '../../nutrition/models/food_item.dart';

final consistencyEngineProvider = Provider<ConsistencyEngine>((ref) {
  return ConsistencyEngine();
});

final fitPointsServiceProvider = Provider<FitPointsService>((ref) {
  final engine = ref.watch(consistencyEngineProvider);
  return FitPointsService(consistencyEngine: engine);
});

final consistencySnapshotProvider = FutureProvider<ConsistencySnapshot>((ref) async {
  final authState = ref.watch(authStateProvider);
  final isGuest = ref.watch(isGuestProvider);
  final service = ref.watch(fitPointsServiceProvider);
  final engine = ref.watch(consistencyEngineProvider);
  final userProfile = ref.watch(userProfileProvider).value;
  
  // Re-calculate when nutrition logs change
  ref.watch(nutritionProvider);

  final userId = authState.value?.uid ?? (isGuest ? 'guest_user' : '');
  if (userId.isEmpty && !isGuest) {
    debugPrint('[ConsistencySnapshot] No userId and not guest, returning empty');
    return ConsistencySnapshot.empty();
  }

  debugPrint('[ConsistencySnapshot] Starting snapshot calculation for userId=$userId, isGuest=$isGuest');

  // 1. Fetch current FP record
  final record = await service.getRecord(userId, isGuest);
  debugPrint('[ConsistencySnapshot] Fetched record: balance=${record.currentBalance}, tier=${record.currentTier.displayName}');

  // 2. Fetch historical logs (last 200 days for safety)
  final repo = NutritionRepository();
  final now = DateTime.now();
  final historicalLogs = <String, List<FoodItem>>{};
  
  // Optimization: Fetch all logs in one query for the last 90 days
  debugPrint('[ConsistencySnapshot] Fetching historical logs for last 90 days in batch...');
  final startDate = now.subtract(const Duration(days: 89));
  final allLogs = await repo.getLogsForRange(startDate, now);
  
  for (final log in allLogs) {
    if (!historicalLogs.containsKey(log.dateString)) {
      historicalLogs[log.dateString] = [];
    }
    historicalLogs[log.dateString]!.add(log);
  }
  debugPrint('[ConsistencySnapshot] Fetched ${allLogs.length} logs across ${historicalLogs.keys.length} days');

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
    debugPrint('[ConsistencySnapshot] Using goals: calories=${userProfile.dynamicCalories}, protein=${userProfile.dynamicProtein}');
  }

  // 4. Calculate Snapshot
  debugPrint('[ConsistencySnapshot] Calling engine.calculateSnapshot...');
  final snapshot = await engine.calculateSnapshot(
    userId: userId,
    isGuest: isGuest,
    historicalLogs: historicalLogs,
    dailyGoals: goals,
    currentFitPoints: record.currentBalance,
    currentMomentum: record.momentumScore,
  );
  
  debugPrint('[ConsistencySnapshot] ✓ Provider complete: streak=${snapshot.currentStreak}, fitPoints=${snapshot.fitPoints.toInt()}');
  
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
