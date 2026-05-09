import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/fitpoints_models.dart';

/// Manages momentum score (0–100): gradual rise on active days,
/// graceful decay on missed days. Protects users from full collapse
/// after one bad day, while still demanding consistent effort at top tiers.
class MomentumService {
  // ─── Constants ────────────────────────────────────────────────────────────

  static const double _maxMomentum = 100.0;
  static const double _minMomentum = 0.0;

  /// Points gained per active, quality day
  static const double _baseGainPerDay = 6.0;

  /// Base decay per missed day (before tier modifiers)
  static const double _baseMissedDayDecay = 4.0;

  /// Below this momentum, user is at risk of tier drop
  static const double _tierProtectionThreshold = 20.0;

  // ─── Core: Daily Recalculation ────────────────────────────────────────────

  /// Called once per day for each user. Adjusts momentum based on
  /// whether they had an active, quality day yesterday.
  double recalculate({
    required double currentMomentum,
    required bool hadActiveDay,
    required LoggingQuality loggingQuality,
    required double adherenceScore, // 0–100
    required StreakTier currentTier,
  }) {
    final previous = currentMomentum;
    double updated;

    if (hadActiveDay) {
      updated = _applyGain(
        current: currentMomentum,
        loggingQuality: loggingQuality,
        adherenceScore: adherenceScore,
      );
    } else {
      updated = _applyDecay(
        current: currentMomentum,
        tier: currentTier,
      );
    }

    updated = updated.clamp(_minMomentum, _maxMomentum);

    _log(
      hadActiveDay
          ? 'Gain: $previous → $updated (quality=${loggingQuality.name}, adherence=${adherenceScore.toStringAsFixed(1)})'
          : 'Decay: $previous → $updated (tier=${currentTier.displayName})',
    );

    return updated;
  }

  // ─── Gain ─────────────────────────────────────────────────────────────────

  double _applyGain({
    required double current,
    required LoggingQuality loggingQuality,
    required double adherenceScore,
  }) {
    // Quality modifier: poor=0.5, normal=1.0, high=1.4
    final qualityMod = loggingQuality == LoggingQuality.high
        ? 1.4
        : loggingQuality == LoggingQuality.normal
            ? 1.0
            : 0.5;

    // Adherence boost: linear scale 0–1.2x over 0–100 adherence
    final adherenceMod = (adherenceScore / 100) * 1.2;

    final gain = _baseGainPerDay * qualityMod * adherenceMod;

    // Logarithmic slow-down near max: harder to gain when already high
    final slowdown = 1.0 - (current / _maxMomentum) * 0.4;
    return current + gain * slowdown;
  }

  // ─── Decay ────────────────────────────────────────────────────────────────

  double _applyDecay({
    required double current,
    required StreakTier tier,
  }) {
    // Higher tiers decay more slowly (they've earned protection)
    final tierProtectionFactor = switch (tier) {
      StreakTier.legendary => 0.4,
      StreakTier.titan => 0.55,
      StreakTier.ironBeast => 0.7,
      StreakTier.heavyDumbbell => 0.85,
      StreakTier.lightDumbbell => 1.0,
    };

    final decay = _baseMissedDayDecay * tierProtectionFactor;

    // Exponential floor protection: decay slows near zero
    final floorProtection = max(0.3, current / _maxMomentum);
    return current - decay * floorProtection;
  }

  // ─── Streak Weakening ────────────────────────────────────────────────────

  /// Call after multiple consecutive missed days. Returns new streak day count
  /// and momentum after multi-day absence.
  StreakWeakeningResult applyAbsence({
    required double currentMomentum,
    required int currentStreakDays,
    required int missedDays,
    required StreakTier currentTier,
  }) {
    double momentum = currentMomentum;
    int streak = currentStreakDays;

    for (int i = 0; i < missedDays; i++) {
      momentum = _applyDecay(current: momentum, tier: currentTier);
      momentum = momentum.clamp(_minMomentum, _maxMomentum);

      // Streak resets after 2 consecutive misses
      if (i >= 1) streak = 0;
    }

    _log(
      'Absence of $missedDays days: momentum $currentMomentum → $momentum, '
      'streak $currentStreakDays → $streak',
    );

    return StreakWeakeningResult(
      updatedMomentum: momentum,
      updatedStreakDays: streak,
      tierAtRisk: momentum < _tierProtectionThreshold,
    );
  }

  // ─── Recovery Projection ─────────────────────────────────────────────────

  /// Returns estimated days needed to reach target momentum at expected quality.
  int estimateDaysToMomentum({
    required double currentMomentum,
    required double targetMomentum,
    required LoggingQuality expectedQuality,
    required double expectedAdherence,
  }) {
    double sim = currentMomentum;
    int days = 0;
    const maxSimDays = 180;

    while (sim < targetMomentum && days < maxSimDays) {
      sim = _applyGain(
        current: sim,
        loggingQuality: expectedQuality,
        adherenceScore: expectedAdherence,
      );
      sim = sim.clamp(_minMomentum, _maxMomentum);
      days++;
    }

    return days;
  }

  // ─── Tier Downgrade Guard ─────────────────────────────────────────────────

  /// Returns the new tier after checking if momentum drop justifies a demotion.
  /// Demotions are delayed — user must be below threshold for 3+ consecutive days.
  StreakTier evaluateTierAfterMomentum({
    required double momentum,
    required StreakTier currentTier,
    required int consecutiveLowMomentumDays,
  }) {
    // No demotion unless sustained low momentum
    if (consecutiveLowMomentumDays < 3) {
      _log('Tier protected — only $consecutiveLowMomentumDays low-momentum days');
      return currentTier;
    }

    final eligible = _tierFromMomentum(momentum);
    if (eligible.index < currentTier.index) {
      _log('Tier drop: ${currentTier.displayName} → ${eligible.displayName}');
      return eligible;
    }

    return currentTier;
  }

  StreakTier _tierFromMomentum(double momentum) {
    if (momentum >= 85) return StreakTier.legendary;
    if (momentum >= 65) return StreakTier.titan;
    if (momentum >= 45) return StreakTier.ironBeast;
    if (momentum >= 25) return StreakTier.heavyDumbbell;
    return StreakTier.lightDumbbell;
  }

  void _log(String message) {
    // ignore: avoid_print
    debugPrint('[MomentumService] $message');
  }
}

class StreakWeakeningResult {
  final double updatedMomentum;
  final int updatedStreakDays;
  final bool tierAtRisk;

  const StreakWeakeningResult({
    required this.updatedMomentum,
    required this.updatedStreakDays,
    required this.tierAtRisk,
  });
}
