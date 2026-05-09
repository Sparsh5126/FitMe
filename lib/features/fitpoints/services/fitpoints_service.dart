import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/fitpoints_models.dart';
import 'consistency_engine.dart';
import '../../nutrition/services/local_nutrition_service.dart';

/// Central service for all FitPoint calculations.
/// Handles: base points, multipliers, quality modifier, duplicate detection,
/// daily caps, and transaction creation.
class FitPointsService {
  final ConsistencyEngine _consistencyEngine;

  FitPointsService({ConsistencyEngine? consistencyEngine})
      : _consistencyEngine = consistencyEngine ?? ConsistencyEngine();

  static const _uuid = Uuid();
  static final _db = FirebaseFirestore.instance;

  // ─── Record Retrieval ─────────────────────────────────────────────────────

  /// Returns a stream of the user's FitPointsRecord.
  /// Handles both authenticated and guest users.
  Stream<FitPointsRecord> getRecordStream(String userId, bool isGuest) {
    if (isGuest || userId.isEmpty) {
      return Stream.fromFuture(getRecord(userId, isGuest));
    }

    return _db.collection('users').doc(userId).collection('gamification').doc('fitpoints').snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return FitPointsRecord.newGuest(userId);
      }
      return FitPointsRecord.fromJson(snap.data()!);
    });
  }

  /// Returns the user's current FitPointsRecord as a Future.
  Future<FitPointsRecord> getRecord(String userId, bool isGuest) async {
    if (isGuest || userId.isEmpty) {
      final local = await LocalNutritionService.getFitPointsRecord();
      if (local != null) return FitPointsRecord.fromJson(local);
      return FitPointsRecord.newGuest(userId.isEmpty ? 'guest_user' : userId);
    }

    final doc = await _db.collection('users').doc(userId).collection('gamification').doc('fitpoints').get();
    if (!doc.exists || doc.data() == null) {
      return FitPointsRecord.newGuest(userId);
    }
    return FitPointsRecord.fromJson(doc.data()!);
  }

  /// Saves or updates the FitPointsRecord.
  Future<void> saveRecord(FitPointsRecord record) async {
    if (record.isGuest) {
      await LocalNutritionService.saveFitPointsRecord(record.toJson());
      return;
    }

    await _db.collection('users').doc(record.userId).collection('gamification').doc('fitpoints').set(record.toJson());
  }

  // ─── Daily Caps ───────────────────────────────────────────────────────────

  /// Max base FP (before multipliers) per day
  static const double _dailyBaseCap = 20.0;

  /// Hard cap including multipliers (Legendary tier max)
  static const double _dailyAbsoluteCap = 125.0;

  // ─── Duplicate Detection ─────────────────────────────────────────────────

  static const double _spamSimilarityThreshold = 0.85;
  static const int _fullFpOccurrences = 2; // first 2 same-meal logs = full FP
  static const int _reducedFpOccurrences = 3; // 3rd = reduced
  // 4th+ = zero

  // ─── Monthly Caps ────────────────────────────────────────────────────────

  static const int _socialShareMonthlyCap = 1;

  // ─── Award FitPoints ──────────────────────────────────────────────────────

  /// Main entry point for awarding FP for any action.
  ///
  /// [todayTransactions] — all FP transactions for current day (to enforce caps).
  /// [todayLogs] — all meal logs for today (for duplicate detection).
  /// [targetMeal] — only for [FitPointAction.logMeal]; the meal being logged.
  FpAwardResult awardPoints({
    required String userId,
    required FitPointAction action,
    required FitPointsRecord record,
    required List<FitPointTransaction> todayTransactions,
    List<MealLogEntry> todayLogs = const [],
    MealLogEntry? targetMeal,
    List<FitPointTransaction> monthlyTransactions = const [],
  }) {
    _log('Evaluating action: ${action.name} for user $userId');

    // ── Monthly cap check (social share) ─────────────────────────────────
    if (action == FitPointAction.shareAppOnSocial) {
      final monthlyShares = monthlyTransactions
          .where((t) => t.action == FitPointAction.shareAppOnSocial)
          .length;
      if (monthlyShares >= _socialShareMonthlyCap) {
        _log('Monthly social share cap reached');
        return const FpAwardResult(
          awarded: false,
          pointsEarned: 0,
          reason: 'Social share reward limited to once per month.',
        );
      }
    }

    // ── Daily action cap check ────────────────────────────────────────────
    final actionCap = action.dailyActionCap;
    if (actionCap != null) {
      final todayActionCount =
          todayTransactions.where((t) => t.action == action).length;
      if (todayActionCount >= actionCap) {
        _log('Daily action cap reached for ${action.name}');
        return FpAwardResult(
          awarded: false,
          pointsEarned: 0,
          reason: 'Daily cap for ${action.name} reached ($actionCap/day).',
          cappedByDaily: true,
        );
      }
    }

    // ── Daily total base-points cap ───────────────────────────────────────
    final todayBaseTotal = todayTransactions.fold<double>(
      0,
      (sum, t) => sum + (t.finalPoints / t.streakMultiplier / t.qualityModifier),
    );
    if (todayBaseTotal >= _dailyBaseCap) {
      _log('Daily base cap reached (${todayBaseTotal.toStringAsFixed(1)} FP)');
      return const FpAwardResult(
        awarded: false,
        pointsEarned: 0,
        reason: 'Daily FitPoints cap reached. Come back tomorrow!',
        cappedByDaily: true,
      );
    }

    // ── Duplicate detection (meal logs only) ─────────────────────────────
    double duplicateModifier = 1.0;
    if (action == FitPointAction.logMeal && targetMeal != null) {
      final dupResult = _detectDuplicate(
        newMeal: targetMeal,
        existingLogs: todayLogs,
      );
      if (dupResult == _DuplicateLevel.spam) {
        _log('Spam meal log detected — zero FP');
        return FpAwardResult.spam;
      }
      duplicateModifier = dupResult == _DuplicateLevel.reduced ? 0.4 : 1.0;
      if (duplicateModifier < 1.0) {
        _log('Duplicate meal — reduced FP modifier: $duplicateModifier');
      }
    }

    // ── Calculate points ─────────────────────────────────────────────────
    final basePoints = action.basePoints * duplicateModifier;
    final streakMultiplier = record.currentTier.multiplier;
    final qualityModifier = _resolveQualityModifier(
      action: action,
      todayLogs: todayLogs,
      record: record,
    );

    double finalPoints = basePoints * streakMultiplier * qualityModifier;

    // Ensure daily absolute cap not exceeded
    final todayFinalTotal =
        todayTransactions.fold<double>(0, (s, t) => s + t.finalPoints);
    final remaining = _dailyAbsoluteCap - todayFinalTotal;
    finalPoints = min(finalPoints, remaining);

    if (finalPoints <= 0) {
      return const FpAwardResult(
        awarded: false,
        pointsEarned: 0,
        reason: 'Daily absolute FP limit reached.',
        cappedByDaily: true,
      );
    }

    _log(
      'Awarded ${finalPoints.toStringAsFixed(2)} FP '
      '(base=$basePoints × streak=${streakMultiplier}x × quality=${qualityModifier}x)',
    );

    return FpAwardResult(
      awarded: true,
      pointsEarned: finalPoints,
      reason: _buildAwardReason(
        action: action,
        finalPoints: finalPoints,
        multiplier: streakMultiplier,
        quality: qualityModifier,
      ),
      reducedByDuplicate: duplicateModifier < 1.0,
    );
  }

  // ─── Transaction Builder ──────────────────────────────────────────────────

  /// Creates a FitPointTransaction from an FpAwardResult.
  FitPointTransaction buildTransaction({
    required String userId,
    required FitPointAction action,
    required FpAwardResult result,
    required StreakTier tier,
    String? metadata,
  }) {
    assert(result.awarded, 'Do not build transactions for non-awarded results');

    final qualityMod = result.reducedByQuality ? LoggingQuality.poor.modifier : 1.0;

    return FitPointTransaction(
      id: _uuid.v4(),
      userId: userId,
      action: action,
      basePoints: action.basePoints,
      streakMultiplier: tier.multiplier,
      qualityModifier: qualityMod,
      finalPoints: result.pointsEarned,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  // ─── Record Update ────────────────────────────────────────────────────────

  /// Applies an award result to a FitPointsRecord.
  FitPointsRecord applyAward({
    required FitPointsRecord record,
    required FpAwardResult result,
  }) {
    if (!result.awarded) return record;

    final dateKey = _dateKey(DateTime.now());
    final updatedDailyEarnings = Map<String, double>.from(record.dailyEarnings);
    updatedDailyEarnings[dateKey] =
        (updatedDailyEarnings[dateKey] ?? 0) + result.pointsEarned;

    return record.copyWith(
      lifetimePoints: record.lifetimePoints + result.pointsEarned,
      currentBalance: record.currentBalance + result.pointsEarned,
      dailyEarnings: updatedDailyEarnings,
      lastActiveDate: DateTime.now(),
    );
  }

  // ─── Guest → Account Migration ────────────────────────────────────────────

  /// Safely merges guest FP record into authenticated account record.
  FitPointsRecord migrateGuestToAccount({
    required FitPointsRecord guestRecord,
    required FitPointsRecord accountRecord,
  }) {
    assert(guestRecord.isGuest, 'Source must be a guest record');

    // Merge daily earnings maps
    final mergedDailyEarnings =
        Map<String, double>.from(accountRecord.dailyEarnings);
    for (final entry in guestRecord.dailyEarnings.entries) {
      mergedDailyEarnings[entry.key] =
          (mergedDailyEarnings[entry.key] ?? 0) + entry.value;
    }

    // Take best tier and highest streak
    final bestTier = guestRecord.currentTier.multiplier > accountRecord.currentTier.multiplier
        ? guestRecord.currentTier
        : accountRecord.currentTier;

    _log(
      'Guest migration: +${guestRecord.lifetimePoints} FP, '
      'streak ${guestRecord.streakDays} days merged',
    );

    return FitPointsRecord(
      userId: accountRecord.userId,
      lifetimePoints: accountRecord.lifetimePoints + guestRecord.lifetimePoints,
      currentBalance: accountRecord.currentBalance + guestRecord.currentBalance,
      currentTier: bestTier,
      streakDays: max(accountRecord.streakDays, guestRecord.streakDays),
      momentumScore:
          max(accountRecord.momentumScore, guestRecord.momentumScore),
      lastActiveDate: accountRecord.lastActiveDate.isAfter(guestRecord.lastActiveDate)
          ? accountRecord.lastActiveDate
          : guestRecord.lastActiveDate,
      dailyEarnings: mergedDailyEarnings,
      isGuest: false,
    );
  }

  // ─── Duplicate Detection ─────────────────────────────────────────────────

  _DuplicateLevel _detectDuplicate({
    required MealLogEntry newMeal,
    required List<MealLogEntry> existingLogs,
  }) {
    final similarMeals = existingLogs
        .where((m) => _similarity(newMeal, m) >= _spamSimilarityThreshold)
        .toList();

    _log('Similar existing meal logs today: ${similarMeals.length}');

    if (similarMeals.length >= _reducedFpOccurrences) return _DuplicateLevel.spam;
    if (similarMeals.length >= _fullFpOccurrences) return _DuplicateLevel.reduced;
    return _DuplicateLevel.full;
  }

  double _similarity(MealLogEntry a, MealLogEntry b) {
    double score = 0.0;

    // Calorie proximity (0.4 weight)
    final calDiff = (a.calories - b.calories).abs();
    score += (calDiff <= 50 ? 1.0 : calDiff <= 150 ? 0.5 : 0.0) * 0.4;

    // Ingredient overlap (0.4 weight)
    final aI = a.ingredients.map((s) => s.toLowerCase()).toSet();
    final bI = b.ingredients.map((s) => s.toLowerCase()).toSet();
    if (aI.isNotEmpty && bI.isNotEmpty) {
      final overlap = aI.intersection(bI).length / aI.union(bI).length;
      score += overlap * 0.4;
    }

    // Name match (0.2 weight)
    score +=
        (a.mealName.toLowerCase() == b.mealName.toLowerCase() ? 1.0 : 0.0) * 0.2;

    return score;
  }

  // ─── Quality Modifier Resolution ─────────────────────────────────────────

  double _resolveQualityModifier({
    required FitPointAction action,
    required List<MealLogEntry> todayLogs,
    required FitPointsRecord record,
  }) {
    // Quality only meaningfully applies to nutrition actions
    const nutritionActions = {
      FitPointAction.logMeal,
      FitPointAction.completeDailyLogging,
      FitPointAction.hitProteinGoal,
      FitPointAction.hitCalorieTarget,
      FitPointAction.hitMacroAdherence,
    };

    if (!nutritionActions.contains(action)) return 1.0;
    if (todayLogs.isEmpty) return LoggingQuality.normal.modifier;

    // Approximate goals from record context (caller can override via subclass if needed)
    const defaultCalorieTarget = 2000.0;
    const defaultProteinTarget = 150.0;

    final quality = _consistencyEngine.evaluateLoggingQuality(
      todayLogs: todayLogs,
      dailyCalorieTarget: defaultCalorieTarget,
      dailyProteinTarget: defaultProteinTarget,
    );

    return quality.modifier;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _buildAwardReason({
    required FitPointAction action,
    required double finalPoints,
    required double multiplier,
    required double quality,
  }) {
    final base = '${finalPoints.toStringAsFixed(1)} FP for ${action.name}';
    final mods = <String>[];
    if (multiplier > 1.0) mods.add('${multiplier}x streak');
    if (quality != 1.0) mods.add('${quality}x quality');
    return mods.isEmpty ? base : '$base (${mods.join(', ')})';
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _log(String message) {
    // ignore: avoid_print
    debugPrint('[FitPointsService] $message');
  }
}

enum _DuplicateLevel { full, reduced, spam }
