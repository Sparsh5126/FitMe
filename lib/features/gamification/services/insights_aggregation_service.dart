import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../insights/screens/insights_screen.dart';
import '../../fitpoints/providers/fitpoints_provider.dart';

class InsightsAggregationService {
  static Timer? _debounce;

  static void refresh(Ref ref) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.invalidate(insightsDataProvider);
      ref.invalidate(fitPointsProvider);
      ref.invalidate(consistencySnapshotProvider);
    });
  }
}
