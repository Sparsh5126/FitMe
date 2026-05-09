import 'package:health/health.dart';

/// Unified wrapper around the `health` package (v10.x API).
/// Covers Google Health Connect / Google Fit (Android) and Apple HealthKit (iOS).
///
/// Responsibility boundary:
///   - This service ONLY talks to the health package.
///   - Runtime OS permissions (activityRecognition etc.) are the caller's
///     responsibility (IntegrationsScreen requests them before invoking connect).
class HealthSyncService {
  static final HealthSyncService _instance = HealthSyncService._();
  factory HealthSyncService() => _instance;
  HealthSyncService._();

  final Health _health = Health();

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WEIGHT,
    HealthDataType.WORKOUT,
  ];

  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  Future<bool> requestPermissions() async {
    try {
      print('HealthSyncService: Configuring health package...');
      await _health.configure();

      // Check Health Connect SDK status on Android
      final status = await _health.getHealthConnectSdkStatus();
      print('HealthSyncService: Health Connect SDK status: $status');
      
      if (status == HealthConnectSdkStatus.sdkUnavailable) {
        // On Android 14+, Health Connect is a system setting, not a standalone app.
        // We only return false if it's truly unavailable (old Android or restricted).
        print('HealthSyncService: Health Connect SDK is not installed or is a system setting.');
      }
      if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        print('HealthSyncService: Health Connect SDK update required.');
        return false;
      }

      print('HealthSyncService: Requesting authorization for types: $_types');
      final granted = await _health.requestAuthorization(_types,
          permissions: _permissions);
      
      if (!granted) {
        print('HealthSyncService: Authorization failed. Checking if permissions are missing in manifest...');
        final hasSteps = await _health.hasPermissions([HealthDataType.STEPS]) ?? false;
        print('HealthSyncService: Steps permission status: $hasSteps');
      }
      
      print('HealthSyncService: Authorization granted: $granted');
      return granted;
    } catch (e) {
      print('HealthSyncService: Health authorization error: $e');
      return false;
    }
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