import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/health_sync_service.dart';

// ── Permission state ──────────────────────────────────
final healthPermissionProvider = FutureProvider<bool>((ref) async {
  return HealthSyncService().isAuthorized;
});

// ── Today's summary ───────────────────────────────────
final healthSummaryProvider = FutureProvider<HealthSummary>((ref) async {
  final authorized = await ref.watch(healthPermissionProvider.future);
  if (!authorized) return HealthSummary.empty();
  return HealthSyncService().fetchTodaySummary();
});

// ── Steps chart (last 7 days) ─────────────────────────
final healthStepsChartProvider =
    FutureProvider<Map<DateTime, int>>((ref) async {
  final authorized = await ref.watch(healthPermissionProvider.future);
  if (!authorized) return {};
  return HealthSyncService().fetchStepsLastDays(7);
});

// ── Notifier: request + refresh ──────────────────────
final healthConnectNotifier =
    AsyncNotifierProvider<HealthConnectNotifier, bool>(HealthConnectNotifier.new);

class HealthConnectNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return HealthSyncService().isAuthorized;
  }

  Future<bool> connect() async {
    state = const AsyncValue.loading();
    final granted = await HealthSyncService().requestPermissions();
    state = AsyncValue.data(granted);
    if (granted) {
      // Invalidate downstream providers so UI refreshes
      ref.invalidate(healthPermissionProvider);
      ref.invalidate(healthSummaryProvider);
      ref.invalidate(healthStepsChartProvider);
    }
    return granted;
  }

  Future<void> refresh() async {
    ref.invalidate(healthSummaryProvider);
    ref.invalidate(healthStepsChartProvider);
  }
}