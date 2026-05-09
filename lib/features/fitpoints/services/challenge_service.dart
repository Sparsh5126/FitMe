import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/fitpoints_models.dart';

/// Manages the full challenge lifecycle: creation, scoring,
/// stake handling, payout, and anti-abuse enforcement.
class ChallengeService {
  static const _uuid = Uuid();

  // ─── Anti-Abuse Constants ─────────────────────────────────────────────────

  /// Max active challenges per user at a time
  static const int _maxActiveChallenges = 3;

  /// Cooldown period between two users challenging each other again (days)
  static const int _opponentCooldownDays = 14;

  /// Max challenges completed with same opponent before cooldown kicks in
  static const int _maxChallengesPerOpponent = 2;

  /// FitMe bonus added to prize pool (percentage of total stakes)
  static const double _fitmeBonusFactor = 0.25;

  // ─── Challenge Durations ─────────────────────────────────────────────────

  static const List<int> _validDurations = [30, 60, 90]; // days

  // ─── Create Challenge ────────────────────────────────────────────────────

  /// Creates a new challenge after all validation passes.
  ChallengeCreateResult createChallenge({
    required String initiatorId,
    required String opponentId,
    required ChallengeType type,
    required int durationDays,
    required double initiatorStake,
    required double opponentStake,
    required Map<String, dynamic> goalConfig,
    required FitPointsRecord initiatorRecord,
    required List<Challenge> existingChallenges,
    required List<Challenge> challengeHistory,
  }) {
    // ── Validation ────────────────────────────────────────────────────────

    if (!_validDurations.contains(durationDays)) {
      return ChallengeCreateResult.failed(
        'Invalid duration. Must be 30, 60, or 90 days.',
      );
    }

    if (initiatorId == opponentId) {
      return ChallengeCreateResult.failed('Cannot challenge yourself.');
    }

    // Sufficient balance
    if (initiatorRecord.currentBalance < initiatorStake) {
      return ChallengeCreateResult.failed(
        'Insufficient FitPoints balance (need $initiatorStake, have ${initiatorRecord.currentBalance.toStringAsFixed(1)}).',
      );
    }

    // Active challenge cap
    final userActiveChallenges = existingChallenges
        .where((c) =>
            c.status == ChallengeStatus.active &&
            c.participantIds.contains(initiatorId))
        .length;
    if (userActiveChallenges >= _maxActiveChallenges) {
      return ChallengeCreateResult.failed(
        'Maximum of $_maxActiveChallenges active challenges reached.',
      );
    }

    // Opponent cooldown / repeat detection
    final abuseCheck = _checkOpponentAbuse(
      initiatorId: initiatorId,
      opponentId: opponentId,
      history: challengeHistory,
    );
    if (!abuseCheck.allowed) {
      _log('Anti-abuse block: ${abuseCheck.reason}');
      return ChallengeCreateResult.failed(abuseCheck.reason);
    }

    // Goal-weight challenge safety check
    if (type == ChallengeType.goalWeight) {
      final safetyCheck = _validateGoalWeightConfig(goalConfig);
      if (!safetyCheck.safe) {
        return ChallengeCreateResult.failed(safetyCheck.reason);
      }
    }

    // ── Build Challenge ───────────────────────────────────────────────────

    final totalStake = initiatorStake + opponentStake;
    final bonusPool = totalStake * _fitmeBonusFactor;
    final now = DateTime.now();

    final challenge = Challenge(
      id: _uuid.v4(),
      type: type,
      status: ChallengeStatus.pending,
      participantIds: [initiatorId, opponentId],
      stakes: {initiatorId: initiatorStake, opponentId: opponentStake},
      bonusPool: bonusPool,
      createdAt: now,
      startsAt: now,
      endsAt: now.add(Duration(days: durationDays)),
      goalConfig: goalConfig,
      progress: {
        initiatorId: ChallengeProgress(
          userId: initiatorId,
          completionPercent: 0,
          consistencyScore: 0,
          adherenceScore: 0,
          activeDays: [],
          goalSpecificData: {},
        ),
        opponentId: ChallengeProgress(
          userId: opponentId,
          completionPercent: 0,
          consistencyScore: 0,
          adherenceScore: 0,
          activeDays: [],
          goalSpecificData: {},
        ),
      },
    );

    _log(
      'Challenge created: ${challenge.id} | type=${type.name} | '
      'duration=${durationDays}d | stake=$totalStake | bonus=$bonusPool',
    );

    return ChallengeCreateResult.success(challenge);
  }

  // ─── Progress Update ──────────────────────────────────────────────────────

  /// Updates one participant's progress in a challenge.
  Challenge updateProgress({
    required Challenge challenge,
    required String userId,
    required ChallengeProgress updatedProgress,
  }) {
    assert(challenge.participantIds.contains(userId));

    final newProgress = Map<String, ChallengeProgress>.from(challenge.progress);
    newProgress[userId] = updatedProgress;

    _log(
      'Progress updated for $userId in ${challenge.id}: '
      'completion=${updatedProgress.completionPercent.toStringAsFixed(1)}%, '
      'consistency=${updatedProgress.consistencyScore.toStringAsFixed(1)}, '
      'adherence=${updatedProgress.adherenceScore.toStringAsFixed(1)}',
    );

    return _rebuildChallenge(challenge, progress: newProgress);
  }

  // ─── Scoring & Payout ────────────────────────────────────────────────────

  /// Finalises a challenge and calculates payouts.
  /// Winner determined by composite score: completion 50%, consistency 30%, adherence 20%.
  /// For accountability challenges, both win if both succeed.
  ChallengePayout finalise(Challenge challenge) {
    assert(challenge.status == ChallengeStatus.active);
    _log('Finalising challenge ${challenge.id} (type=${challenge.type.name})');

    final totalPrize = challenge.stakes.values.fold<double>(0, (s, v) => s + v) +
        challenge.bonusPool;

    if (challenge.type == ChallengeType.accountability) {
      return _finaliseAccountability(challenge, totalPrize);
    }

    return _finaliseCompetitive(challenge, totalPrize);
  }

  ChallengePayout _finaliseCompetitive(Challenge challenge, double totalPrize) {
    final scores = challenge.progress.map(
      (uid, p) => MapEntry(uid, p.rankingScore),
    );

    _log('Scores: ${scores.map((k, v) => MapEntry(k, v.toStringAsFixed(2)))}');

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final winnerId = sorted.first.key;
    final runnerUpId = sorted.last.key;
    final winnerScore = sorted.first.value;
    final runnerUpScore = sorted.last.value;

    // Cliff edge: if scores within 2%, call it a draw
    final isDraw = (winnerScore - runnerUpScore).abs() < 2.0;

    Map<String, double> payouts;
    if (isDraw) {
      final half = totalPrize / 2;
      payouts = {
        winnerId: half,
        runnerUpId: half,
      };
      _log('Draw — splitting $totalPrize evenly');
    } else {
      // Partial refund to loser: they get back 20% of their stake
      final loserRefund = challenge.stakes[runnerUpId]! * 0.2;
      payouts = {
        winnerId: totalPrize - loserRefund,
        runnerUpId: loserRefund,
      };
      _log(
        'Winner: $winnerId (+${(totalPrize - loserRefund).toStringAsFixed(1)} FP), '
        'Runner-up: $runnerUpId (+${loserRefund.toStringAsFixed(1)} FP refund)',
      );
    }

    return ChallengePayout(
      challengeId: challenge.id,
      payouts: payouts,
      winnerId: isDraw ? null : winnerId,
      isDraw: isDraw,
      totalDistributed: totalPrize,
    );
  }

  ChallengePayout _finaliseAccountability(Challenge challenge, double totalPrize) {
    final participants = challenge.participantIds;
    const successThreshold = 70.0; // completion% to be considered "successful"

    final successfulUsers = participants.where((uid) {
      final p = challenge.progress[uid];
      return p != null && p.completionPercent >= successThreshold;
    }).toList();

    _log('Accountability success: ${successfulUsers.length}/${participants.length}');

    if (successfulUsers.length == participants.length) {
      // Everyone wins — split the pool plus bonus
      final perPerson = totalPrize / participants.length;
      final payouts = {for (final uid in participants) uid: perPerson};
      return ChallengePayout(
        challengeId: challenge.id,
        payouts: payouts,
        winnerId: null,
        isDraw: true,
        totalDistributed: totalPrize,
        allSucceeded: true,
      );
    }

    // Partial success: successful users get their stake back + share of bonus
    final bonusPerSuccessful = challenge.bonusPool /
        max(successfulUsers.length, 1);
    final payouts = <String, double>{};
    for (final uid in participants) {
      if (successfulUsers.contains(uid)) {
        payouts[uid] = (challenge.stakes[uid] ?? 0) + bonusPerSuccessful;
      } else {
        payouts[uid] = 0;
      }
    }

    return ChallengePayout(
      challengeId: challenge.id,
      payouts: payouts,
      winnerId: null,
      isDraw: false,
      totalDistributed: payouts.values.fold(0, (s, v) => s + v),
      allSucceeded: false,
    );
  }

  // ─── Anti-Abuse ───────────────────────────────────────────────────────────

  _AbuseCheckResult _checkOpponentAbuse({
    required String initiatorId,
    required String opponentId,
    required List<Challenge> history,
  }) {
    final pairHistory = history.where((c) =>
        c.participantIds.contains(initiatorId) &&
        c.participantIds.contains(opponentId) &&
        c.status == ChallengeStatus.completed).toList();

    if (pairHistory.length >= _maxChallengesPerOpponent) {
      // Check cooldown: last challenge must be >14 days ago
      final lastChallenge = pairHistory.reduce(
        (a, b) => a.endsAt.isAfter(b.endsAt) ? a : b,
      );
      final daysSinceLast = DateTime.now().difference(lastChallenge.endsAt).inDays;
      if (daysSinceLast < _opponentCooldownDays) {
        return _AbuseCheckResult(
          allowed: false,
          reason:
              'Too many recent challenges with this opponent. '
              'Cooldown ends in ${_opponentCooldownDays - daysSinceLast} days.',
        );
      }
    }

    // Detect suspicious: same opponent, same outcome pattern (win-trading)
    if (pairHistory.length >= 2) {
      final alternating = _detectWinTrading(initiatorId, pairHistory);
      if (alternating) {
        _log('Suspicious win-trading pattern detected between $initiatorId and $opponentId');
        return const _AbuseCheckResult(
          allowed: false,
          reason: 'Suspicious challenge pattern detected. Contact support.',
        );
      }
    }

    return const _AbuseCheckResult(allowed: true, reason: '');
  }

  /// Simple heuristic: if winners alternate every time between two users → suspicious.
  bool _detectWinTrading(String userId, List<Challenge> history) {
    if (history.length < 2) return false;
    final sorted = history..sort((a, b) => a.endsAt.compareTo(b.endsAt));
    bool lastWin = sorted.first.winnerId == userId;
    int alternations = 0;
    for (final c in sorted.skip(1)) {
      final thisWin = c.winnerId == userId;
      if (thisWin != lastWin) alternations++;
      lastWin = thisWin;
    }
    return alternations == history.length - 1; // perfectly alternating
  }

  // ─── Goal Weight Safety ──────────────────────────────────────────────────

  _SafetyCheckResult _validateGoalWeightConfig(Map<String, dynamic> config) {
    for (final participantKey in config.keys) {
      final data = config[participantKey] as Map<String, dynamic>?;
      if (data == null) continue;

      final startWeight = (data['startWeight'] as num?)?.toDouble();
      final goalWeight = (data['goalWeight'] as num?)?.toDouble();
      final durationDays = (data['durationDays'] as num?)?.toInt() ?? 30;

      if (startWeight == null || goalWeight == null) continue;

      final weightChange = (goalWeight - startWeight).abs();
      // Safe rate: ~0.5–1kg/week max
      final maxSafeChange = (durationDays / 7) * 1.0;

      if (weightChange > maxSafeChange) {
        _log(
          'Unsafe weight goal for $participantKey: '
          '${startWeight}kg → ${goalWeight}kg in ${durationDays}d '
          '(max safe: ${maxSafeChange.toStringAsFixed(1)}kg)',
        );
        return _SafetyCheckResult(
          safe: false,
          reason:
              'Goal weight change (${weightChange.toStringAsFixed(1)}kg in ${durationDays}d) '
              'exceeds safe rate. Max recommended: ${maxSafeChange.toStringAsFixed(1)}kg.',
        );
      }
    }
    return const _SafetyCheckResult(safe: true, reason: '');
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Challenge _rebuildChallenge(
    Challenge c, {
    Map<String, ChallengeProgress>? progress,
    ChallengeStatus? status,
    String? winnerId,
  }) {
    return Challenge(
      id: c.id,
      type: c.type,
      status: status ?? c.status,
      participantIds: c.participantIds,
      stakes: c.stakes,
      bonusPool: c.bonusPool,
      createdAt: c.createdAt,
      startsAt: c.startsAt,
      endsAt: c.endsAt,
      goalConfig: c.goalConfig,
      progress: progress ?? c.progress,
      winnerId: winnerId ?? c.winnerId,
    );
  }

  void _log(String message) {
    // ignore: avoid_print
    debugPrint('[ChallengeService] $message');
  }
}

// ─── Result Types ─────────────────────────────────────────────────────────────

class ChallengeCreateResult {
  final bool success;
  final Challenge? challenge;
  final String? errorMessage;

  const ChallengeCreateResult._({
    required this.success,
    this.challenge,
    this.errorMessage,
  });

  factory ChallengeCreateResult.success(Challenge challenge) =>
      ChallengeCreateResult._(success: true, challenge: challenge);

  factory ChallengeCreateResult.failed(String reason) =>
      ChallengeCreateResult._(success: false, errorMessage: reason);
}

class ChallengePayout {
  final String challengeId;
  final Map<String, double> payouts; // userId → FP earned
  final String? winnerId;
  final bool isDraw;
  final double totalDistributed;
  final bool allSucceeded;

  const ChallengePayout({
    required this.challengeId,
    required this.payouts,
    required this.winnerId,
    required this.isDraw,
    required this.totalDistributed,
    this.allSucceeded = false,
  });
}

class _AbuseCheckResult {
  final bool allowed;
  final String reason;
  const _AbuseCheckResult({required this.allowed, required this.reason});
}

class _SafetyCheckResult {
  final bool safe;
  final String reason;
  const _SafetyCheckResult({required this.safe, required this.reason});
}
