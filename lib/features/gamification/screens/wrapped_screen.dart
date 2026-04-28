import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_profile.dart';
import '../../dashboard/providers/user_provider.dart';
import '../../nutrition/models/food_item.dart';
import '../../nutrition/repositories/nutrition_repository.dart';

final wrappedDataProvider = FutureProvider<WrappedData>((ref) async {
  final profile = ref.read(userProfileProvider).value;
  return WrappedData.calculate(profile);
});

class WrappedScreen extends ConsumerWidget {
  const WrappedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(wrappedDataProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('FitMe Wrapped', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            Expanded(
              child: dataAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
                data: (data) => _WrappedContent(data: data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WrappedContent extends StatefulWidget {
  final WrappedData data;
  const _WrappedContent({required this.data});

  @override
  State<_WrappedContent> createState() => _WrappedContentState();
}

class _WrappedContentState extends State<_WrappedContent> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      // Capture widget as image
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      // TODO: use share_plus package to share the image bytes
      // Share.shareXFiles([XFile.fromData(byteData.buffer.asUint8List(), mimeType: 'image/png')]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ready to share! (wire share_plus)'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Shareable card ───────────────────
          RepaintBoundary(
            key: _repaintKey,
            child: _WrappedCard(data: widget.data),
          ),

          const SizedBox(height: 24),

          // ── Share button ─────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _sharing ? null : _share,
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share My Wrapped', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Detailed stats ───────────────────
          _DetailedStats(data: widget.data),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WRAPPED CARD (the shareable visual)
// ─────────────────────────────────────────────
class _WrappedCard extends StatelessWidget {
  final WrappedData data;
  const _WrappedCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1F1A), Color(0xFF0D0D0D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FitMe', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1)),
                  Text('Wrapped ${data.periodLabel}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
              const Text('💪', style: TextStyle(fontSize: 32)),
            ],
          ),

          const SizedBox(height: 24),

          // Name
          Text(data.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
          const SizedBox(height: 4),
          Text('Here\'s your journey', style: TextStyle(color: AppTheme.accent.withOpacity(0.8), fontSize: 13)),

          const SizedBox(height: 24),

          // Big stats
          Row(
            children: [
              _BigStat(value: '${data.totalProtein}g', label: 'Protein\nConsumed', color: Colors.blueAccent),
              const SizedBox(width: 12),
              _BigStat(value: '${data.daysLogged}', label: 'Days\nLogged', color: AppTheme.accent),
              const SizedBox(width: 12),
              _BigStat(value: '${data.longestStreak}d', label: 'Longest\nStreak', color: Colors.purpleAccent),
            ],
          ),

          const SizedBox(height: 20),

          // Dumbbell streak icon
          Center(
            child: Column(
              children: [
                CustomPaint(
                  size: const Size(160, 80),
                  painter: _MiniDumbbellPainter(level: data.dumbbellLevel),
                ),
                const SizedBox(height: 6),
                Text(data.dumbbellLabel,
                    style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Secondary stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SmallStat('${data.totalCalories}', 'kcal total'),
              _SmallStat('${data.workoutsCompleted}', 'workouts'),
              _SmallStat('${data.fitPoints}', 'FitPoints'),
              _SmallStat('${data.macroGoalHits}', 'macro wins'),
            ],
          ),

          const SizedBox(height: 20),

          // Footer
          const Center(
            child: Text('fitme.app', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _BigStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String value;
  final String label;
  const _SmallStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// DETAILED STATS (below card)
// ─────────────────────────────────────────────
class _DetailedStats extends StatelessWidget {
  final WrappedData data;
  const _DetailedStats({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Full Breakdown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          _Row('Total Protein', '${data.totalProtein}g', Colors.blueAccent),
          _Row('Total Carbs', '${data.totalCarbs}g', Colors.orangeAccent),
          _Row('Total Fats', '${data.totalFats}g', Colors.purpleAccent),
          _Row('Total Calories', '${data.totalCalories} kcal', AppTheme.accent),
          const Divider(color: AppTheme.background, height: 24),
          _Row('Days Logged', '${data.daysLogged}', Colors.white),
          _Row('Macro Goal Days Hit', '${data.macroGoalHits}', AppTheme.accent),
          _Row('Longest Streak', '${data.longestStreak} days', AppTheme.accent),
          _Row('Current Streak Level', data.dumbbellLabel, AppTheme.accent),
          const Divider(color: AppTheme.background, height: 24),
          _Row('Workouts Completed', '${data.workoutsCompleted}', Colors.white),
          _Row('FitPoints Earned', '${data.fitPoints} pts', AppTheme.accent),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Row(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MINI DUMBBELL PAINTER (for wrapped card)
// ─────────────────────────────────────────────
class _MiniDumbbellPainter extends CustomPainter {
  final int level;
  _MiniDumbbellPainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final color = AppTheme.accent;
    final active = Paint()..color = color..style = PaintingStyle.fill;
    final dim = Paint()..color = color.withOpacity(0.15)..style = PaintingStyle.fill;
    final bar = Paint()..color = color..strokeWidth = 6..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawLine(Offset(cx - 60, cy), Offset(cx + 60, cy), bar);
    _p(canvas, cx - 42, cy, 7, 24, active);
    _p(canvas, cx + 42, cy, 7, 24, active);
    _p(canvas, cx - 52, cy, 6, 20, level >= 1 ? active : dim);
    _p(canvas, cx + 52, cy, 6, 20, level >= 1 ? active : dim);
    _p(canvas, cx - 62, cy, 8, 28, level >= 2 ? active : dim);
    _p(canvas, cx + 62, cy, 8, 28, level >= 2 ? active : dim);
    _p(canvas, cx - 74, cy, 9, 36, level >= 3 ? active : dim);
    _p(canvas, cx + 74, cy, 9, 36, level >= 3 ? active : dim);
  }

  void _p(Canvas c, double x, double cy, double w, double h, Paint p) {
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, cy), width: w, height: h), const Radius.circular(2)), p);
  }

  @override
  bool shouldRepaint(_MiniDumbbellPainter old) => old.level != level;
}

// ─────────────────────────────────────────────
// WRAPPED DATA MODEL + CALCULATOR
// ─────────────────────────────────────────────
class WrappedData {
  final String name;
  final String periodLabel;
  final int totalProtein;
  final int totalCarbs;
  final int totalFats;
  final int totalCalories;
  final int daysLogged;
  final int macroGoalHits;
  final int longestStreak;
  final int workoutsCompleted;
  final int fitPoints;
  final int dumbbellLevel;
  final String dumbbellLabel;

  const WrappedData({
    required this.name, required this.periodLabel,
    required this.totalProtein, required this.totalCarbs,
    required this.totalFats, required this.totalCalories,
    required this.daysLogged, required this.macroGoalHits,
    required this.longestStreak, required this.workoutsCompleted,
    required this.fitPoints, required this.dumbbellLevel,
    required this.dumbbellLabel,
  });

  static Future<WrappedData> calculate(UserProfile? profile) async {
    if (profile == null) return _empty();

    final repo = NutritionRepository();
    final now = DateTime.now();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    int totalPro = 0, totalCarbs = 0, totalFats = 0, totalCals = 0;
    int daysLogged = 0, macroHits = 0;

    for (int i = 0; i < 180; i++) {
      final date = now.subtract(Duration(days: i));
      final logs = await repo.getLogsForDate(FoodItem.dateFor(date));
      if (logs.isEmpty) continue;

      daysLogged++;
      for (final l in logs) {
        totalPro += l.protein; totalCarbs += l.carbs;
        totalFats += l.fats; totalCals += l.calories;
      }

      final dayPro = logs.fold<int>(0, (s, l) => s + l.protein);
      if (dayPro >= (profile.dynamicProtein * 0.85).round()) macroHits++;
    }

    // Read Firestore extras
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    final longest = data['longestStreak'] as int? ?? 0;
    final points = data['fitPoints'] as int? ?? 0;
    final workouts = data['workoutsCompleted'] as int? ?? 0;
    final streak = data['currentStreak'] as int? ?? 0;

    // Dumbbell level
    int level = 0;
    if (streak >= 61) level = 3;
    else if (streak >= 22) level = 2;
    else if (streak >= 8) level = 1;

    const labels = ['Light Dumbbell', 'Heavy Dumbbell', 'Barbell', 'Loaded Barbell'];

    return WrappedData(
      name: profile.name,
      periodLabel: '6 Months',
      totalProtein: totalPro,
      totalCarbs: totalCarbs,
      totalFats: totalFats,
      totalCalories: totalCals,
      daysLogged: daysLogged,
      macroGoalHits: macroHits,
      longestStreak: longest,
      workoutsCompleted: workouts,
      fitPoints: points,
      dumbbellLevel: level,
      dumbbellLabel: labels[level],
    );
  }

  static WrappedData _empty() => const WrappedData(
    name: '', periodLabel: '6 Months',
    totalProtein: 0, totalCarbs: 0, totalFats: 0, totalCalories: 0,
    daysLogged: 0, macroGoalHits: 0, longestStreak: 0,
    workoutsCompleted: 0, fitPoints: 0, dumbbellLevel: 0, dumbbellLabel: 'Light Dumbbell',
  );
}