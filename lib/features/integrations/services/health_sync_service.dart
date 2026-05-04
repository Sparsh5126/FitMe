import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Unified wrapper around the `health` package (v10.x API).
/// Covers Google Health Connect / Google Fit (Android) and Apple HealthKit (iOS).
class HealthSyncService {
  static final HealthSyncService _instance = HealthSyncService._();
  factory HealthSyncService() => _instance;
  HealthSyncService._();

  // health v10 is a singleton accessed via Health()
  final Health _health = Health();

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WEIGHT,
  ];

  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  // ── Request permissions ──────────────────────────────
  Future<bool> requestPermissions() async {
    // Android: activity recognition needed for steps
    await Permission.activityRecognition.request();

    await _health.configure();
    return _health.requestAuthorization(_types, permissions: _permissions);
  }

  // ── Check if already authorized ─────────────────────
  Future<bool> get isAuthorized async {
    try {
      await _health.configure();
      return await _health.hasPermissions(_types, permissions: _permissions) ??
          false;
    } catch (_) {
      return false;
    }
  }

  // ── Fetch today's summary ────────────────────────────
  Future<HealthSummary> fetchTodaySummary() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    List<HealthDataPoint> points = [];
    try {
      points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: startOfDay,
        endTime: now,
      );
      points = _health.removeDuplicates(points);
    } catch (_) {
      return HealthSummary.empty();
    }

    int steps = 0;
    double caloriesBurned = 0;
    double? weightKg;

    for (final p in points) {
      final val = p.value;
      switch (p.type) {
        case HealthDataType.STEPS:
          if (val is NumericHealthValue) {
            steps += val.numericValue.toInt();
          }
          break;
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          if (val is NumericHealthValue) {
            caloriesBurned += val.numericValue.toDouble();
          }
          break;
        case HealthDataType.WEIGHT:
          if (val is NumericHealthValue) {
            weightKg = val.numericValue.toDouble();
          }
          break;
        default:
          break;
      }
    }

    return HealthSummary(
      steps: steps,
      caloriesBurned: caloriesBurned,
      weightKg: weightKg,
      fetchedAt: now,
    );
  }

  // ── Fetch steps for last N days (for chart) ──────────
  Future<Map<DateTime, int>> fetchStepsLastDays(int days) async {
    final now = DateTime.now();
    final result = <DateTime, int>{};

    for (int i = 0; i < days; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      final end = i == 0 ? now : day.add(const Duration(days: 1));
      try {
        final points = await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: day,
          endTime: end,
        );
        final deduped = _health.removeDuplicates(points);
        int daySteps = 0;
        for (final p in deduped) {
          if (p.value is NumericHealthValue) {
            daySteps += (p.value as NumericHealthValue).numericValue.toInt();
          }
        }
        result[day] = daySteps;
      } catch (_) {
        result[day] = 0;
      }
    }

    return result;
  }
}

// ── Data class ────────────────────────────────────────
class HealthSummary {
  final int steps;
  final double caloriesBurned;
  final double? weightKg;
  final DateTime fetchedAt;

  const HealthSummary({
    required this.steps,
    required this.caloriesBurned,
    required this.weightKg,
    required this.fetchedAt,
  });

  factory HealthSummary.empty() => HealthSummary(
        steps: 0,
        caloriesBurned: 0,
        weightKg: null,
        fetchedAt: DateTime.now(),
      );

  bool get isEmpty => steps == 0 && caloriesBurned == 0 && weightKg == null;
}