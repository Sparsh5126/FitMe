import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/providers/user_provider.dart';
import '../../nutrition/providers/nutrition_provider.dart';
import '../../nutrition/models/food_item.dart';
import '../../nutrition/repositories/nutrition_repository.dart';

// Period selection
enum InsightsPeriod { week, twoWeeks, month }

class InsightsPeriodNotifier extends Notifier<InsightsPeriod> {
  @override
  InsightsPeriod build() => InsightsPeriod.week;
}

final insightsPeriodProvider = NotifierProvider<InsightsPeriodNotifier, InsightsPeriod>(InsightsPeriodNotifier.new);

final insightsDataProvider = FutureProvider<List<DayMacros>>((ref) async {
  final period = ref.watch(insightsPeriodProvider);
  final days = period == InsightsPeriod.week ? 7 : period == InsightsPeriod.twoWeeks ? 14 : 30;
  final repo = NutritionRepository();
  final now = DateTime.now();
  final result = <DayMacros>[];

  for (int i = days - 1; i >= 0; i--) {
    final date = now.subtract(Duration(days: i));
    final dateStr = FoodItem.dateFor(date);
    final meals = await repo.getLogsForDate(dateStr);
    double cals = 0, pro = 0, carbs = 0, fats = 0;
    for (final m in meals) {
      cals += m.calories; pro += m.protein; carbs += m.carbs; fats += m.fats;
    }
    result.add(DayMacros(date: date, calories: cals.round(), protein: pro.round(), carbs: carbs.round(), fats: fats.round()));
  }
  return result;
});

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final period = ref.watch(insightsPeriodProvider);
    final dataAsync = ref.watch(insightsDataProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────
                const Text('Insights', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
                const SizedBox(height: 20),

                // ── FitPoints ───────────────────────────
                _FitPointsCard(profile: profile),
                const SizedBox(height: 24),

                // ── Re-balancer summary ─────────────────
                if (profile != null) _RebalancerCard(profile: profile),
                const SizedBox(height: 24),

                // ── Period selector ─────────────────────
                const Text('Trends', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _PeriodSelector(selected: period),
                const SizedBox(height: 16),

                // ── Charts ──────────────────────────────
                dataAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    ),
                  ),
                  error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
                  data: (data) => Column(
                    children: [
                      _MacroChart(data: data, macro: 'calories', color: AppTheme.accent,
                          goal: profile?.dynamicCalories ?? 2000, label: 'Calories (kcal)'),
                      const SizedBox(height: 20),
                      _MacroChart(data: data, macro: 'protein', color: Colors.blueAccent,
                          goal: profile?.dynamicProtein ?? 150, label: 'Protein (g)'),
                      const SizedBox(height: 20),
                      _MacroChart(data: data, macro: 'carbs', color: Colors.orangeAccent,
                          goal: profile?.dynamicCarbs ?? 200, label: 'Carbs (g)'),
                      const SizedBox(height: 20),
                      _MacroChart(data: data, macro: 'fats', color: Colors.purpleAccent,
                          goal: profile?.dynamicFats ?? 55, label: 'Fats (g)'),
                      const SizedBox(height: 20),
                      _SummaryStats(data: data, profile: profile),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FITPOINTS CARD
// ─────────────────────────────────────────────
class _FitPointsCard extends StatelessWidget {
  final dynamic profile;
  const _FitPointsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    // FitPoints: calculated from streak + macro consistency
    // TODO: wire to fitpoints_service.dart
    const points = 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accent.withOpacity(0.8), AppTheme.accent.withOpacity(0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('🐦‍🔥', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FitPoints', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('$points', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1)),
              const Text('Stay Consistent, Get Fit!',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RE-BALANCER SUMMARY CARD
// ─────────────────────────────────────────────
class _RebalancerCard extends StatelessWidget {
  final dynamic profile;
  const _RebalancerCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final proteinDiff = profile.dynamicProtein - profile.dailyProtein;
    final carbsDiff = profile.dynamicCarbs - profile.dailyCarbs;
    final fatsDiff = profile.dynamicFats - profile.dailyFats;
    final isAdjusted = proteinDiff != 0 || carbsDiff != 0 || fatsDiff != 0;

    if (!isAdjusted) return const SizedBox();

    String _fmt(int v) => v > 0 ? '+$v' : '$v';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.balance_rounded, color: AppTheme.accent, size: 18),
              SizedBox(width: 8),
              Text('Weekly Re-balancer Active',
                  style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Your daily targets have been adjusted to keep you on track for the week.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (proteinDiff != 0) _AdjustChip('Protein', _fmt(proteinDiff) + 'g', Colors.blueAccent),
              if (carbsDiff != 0) _AdjustChip('Carbs', _fmt(carbsDiff) + 'g', Colors.orangeAccent),
              if (fatsDiff != 0) _AdjustChip('Fats', _fmt(fatsDiff) + 'g', Colors.purpleAccent),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdjustChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AdjustChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final isPositive = value.startsWith('+');
    return Column(
      children: [
        Text(value, style: TextStyle(color: isPositive ? Colors.redAccent : Colors.greenAccent,
            fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// PERIOD SELECTOR
// ─────────────────────────────────────────────
class _PeriodSelector extends ConsumerWidget {
  final InsightsPeriod selected;
  const _PeriodSelector({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const options = [
      (InsightsPeriod.week, '1 Week'),
      (InsightsPeriod.twoWeeks, '2 Weeks'),
      (InsightsPeriod.month, '1 Month'),
    ];

    return Row(
      children: options.map((o) {
        final isSelected = selected == o.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => ref.read(insightsPeriodProvider.notifier).state = o.$1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppTheme.accent : Colors.transparent, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(o.$2,
                  style: TextStyle(
                    color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  )),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
// MACRO LINE CHART (custom painter)
// ─────────────────────────────────────────────
class _MacroChart extends StatelessWidget {
  final List<DayMacros> data;
  final String macro;
  final Color color;
  final int goal;
  final String label;

  const _MacroChart({
    required this.data, required this.macro,
    required this.color, required this.goal, required this.label,
  });

  List<int> get _values => data.map((d) {
    switch (macro) {
      case 'calories': return d.calories;
      case 'protein': return d.protein;
      case 'carbs': return d.carbs;
      case 'fats': return d.fats;
      default: return 0;
    }
  }).toList();

  @override
  Widget build(BuildContext context) {
    final values = _values;
    final avg = values.isEmpty ? 0 : (values.reduce((a, b) => a + b) / values.length).round();
    final maxVal = values.isEmpty ? goal : values.reduce((a, b) => a > b ? a : b);
    final chartMax = (maxVal * 1.2).round() < goal ? goal : (maxVal * 1.2).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text('avg $avg', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: const Size(double.infinity, 100),
              painter: _LinePainter(values: values, goal: goal, maxVal: chartMax, color: color),
            ),
          ),
          const SizedBox(height: 8),
          // X-axis labels (first and last date)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_shortDate(data.first.date), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              Text('Goal: $goal', style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
              Text(_shortDate(data.last.date), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime d) => '${d.day}/${d.month}';
}

class _LinePainter extends CustomPainter {
  final List<int> values;
  final int goal;
  final int maxVal;
  final Color color;

  _LinePainter({required this.values, required this.goal, required this.maxVal, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final goalY = size.height - (goal / maxVal * size.height);

    // Goal line (dashed)
    final goalPaint = Paint()..color = color.withOpacity(0.3)..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, goalY), Offset((x + 6).clamp(0, size.width), goalY), goalPaint);
    }

    // Fill area
    final fillPath = Path();
    final stepX = size.width / (values.length - 1).clamp(1, 9999);

    fillPath.moveTo(0, size.height);
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxVal * size.height).clamp(0, size.height);
      if (i == 0) fillPath.lineTo(x, y);
      else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (values[i - 1] / maxVal * size.height).clamp(0, size.height);
        final cpX = (prevX + x) / 2;
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    fillPath.lineTo((values.length - 1) * stepX, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill);

    // Line
    final linePaint = Paint()..color = color..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final linePath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxVal * size.height).clamp(0, size.height);
      if (i == 0) linePath.moveTo(x, y);
      else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (values[i - 1] / maxVal * size.height).clamp(0, size.height);
        final cpX = (prevX + x) / 2;
        linePath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxVal * size.height).clamp(0, size.height);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values;
}

// ─────────────────────────────────────────────
// SUMMARY STATS
// ─────────────────────────────────────────────
class _SummaryStats extends StatelessWidget {
  final List<DayMacros> data;
  final dynamic profile;
  const _SummaryStats({required this.data, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || profile == null) return const SizedBox();

    final daysLogged = data.where((d) => d.calories > 0).length;
    final avgProtein = data.isEmpty ? 0 : (data.map((d) => d.protein).reduce((a, b) => a + b) / data.length).round();
    final goalHits = data.where((d) => d.protein >= profile.dynamicProtein).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Period Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),
          _SummaryRow('Days logged', '$daysLogged / ${data.length}'),
          _SummaryRow('Avg. protein', '${avgProtein}g / day'),
          _SummaryRow('Protein goal hit', '$goalHits / ${data.length} days'),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────
class DayMacros {
  final DateTime date;
  final int calories, protein, carbs, fats;
  const DayMacros({required this.date, required this.calories,
      required this.protein, required this.carbs, required this.fats});
}