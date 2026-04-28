import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';
import '../../dashboard/providers/user_provider.dart';

class MacroDetailScreen extends ConsumerWidget {
  final FoodItem? singleFood;
  const MacroDetailScreen({super.key, this.singleFood});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final totals = ref.watch(dailyTotalsProvider);
    final mealsAsync = ref.watch(nutritionProvider);

    if (profile == null) return const Scaffold(backgroundColor: AppTheme.background);

    final cals = singleFood != null ? singleFood!.calories : (totals['calories'] ?? 0);
    final pro = singleFood != null ? singleFood!.protein : (totals['protein'] ?? 0);
    final carbs = singleFood != null ? singleFood!.carbs : (totals['carbs'] ?? 0);
    final fats = singleFood != null ? singleFood!.fats : (totals['fats'] ?? 0);

    // Derived micros (estimated from meals or single food)
    final meals = mealsAsync.value ?? [];
    final itemCount = singleFood != null ? 1 : meals.length;
    final fiber = (carbs * 0.08).round();       // ~8% of carbs
    final sugar = (carbs * 0.25).round();        // ~25% of carbs
    final saturatedFat = (fats * 0.35).round();  // ~35% of total fat
    final sodium = itemCount * 180;            // rough estimate per item
    final cholesterol = (pro * 1.2).round();
    final vitaminA = (pro * 15 + carbs * 10).round();   // IU
    final vitaminC = (carbs * 0.5).round();      // mg
    final calcium = (pro * 12).round();          // mg
    final iron = (pro * 0.2).round();            // mg
    final potassium = (carbs * 10 + pro * 5).round();    // mg

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(singleFood?.name ?? 'Today\'s Nutrition', 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [


                    // ── Macros section ───────────────────
                    const _SectionHeader('Macronutrients'),
                    const SizedBox(height: 12),

                    _MacroBar(label: 'Protein', current: pro, goal: profile.dynamicProtein, color: Colors.blueAccent, unit: 'g',
                        note: 'Builds & repairs muscle'),
                    _MacroBar(label: 'Carbohydrates', current: carbs, goal: profile.dynamicCarbs, color: Colors.orangeAccent, unit: 'g',
                        note: 'Primary energy source'),
                    _MacroBar(label: 'Fats', current: fats, goal: profile.dynamicFats, color: Colors.purpleAccent, unit: 'g',
                        note: 'Hormone & cell health'),
                    _MacroBar(label: 'Calories', current: cals, goal: profile.dynamicCalories, color: AppTheme.accent, unit: 'kcal',
                        note: 'Total energy'),

                    const SizedBox(height: 28),

                    // ── Micros section ───────────────────
                    const _SectionHeader('Micronutrients (Estimated)'),
                    const SizedBox(height: 4),
                    const Text('Based on your logged meals. Values are estimates.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 14),

                    _MicroRow(label: 'Dietary Fiber', value: '${fiber}g', goal: '25–30g'),
                    _MicroRow(label: 'Sugar', value: '${sugar}g', goal: '< 50g'),
                    _MicroRow(label: 'Saturated Fat', value: '${saturatedFat}g', goal: '< 20g'),
                    _MicroRow(label: 'Sodium', value: '${sodium}mg', goal: '< 2300mg'),
                    _MicroRow(label: 'Cholesterol', value: '${cholesterol}mg', goal: '< 300mg'),
                    _MicroRow(label: 'Vitamin A', value: '${vitaminA}IU', goal: '3000IU'),
                    _MicroRow(label: 'Vitamin C', value: '${vitaminC}mg', goal: '90mg'),
                    _MicroRow(label: 'Calcium', value: '${calcium}mg', goal: '1000mg'),
                    _MicroRow(label: 'Iron', value: '${iron}mg', goal: '18mg'),
                    _MicroRow(label: 'Potassium', value: '${potassium}mg', goal: '3400mg'),

                    const SizedBox(height: 28),

                    // ── Calorie breakdown ─────────────────
                    const _SectionHeader('Calorie Breakdown'),
                    const SizedBox(height: 14),

                    _CaloriePieRow(
                      proteinCals: pro * 4,
                      carbsCals: carbs * 4,
                      fatsCals: fats * 9,
                      totalCals: cals,
                    ),

                    if (singleFood == null) ...[
                      const SizedBox(height: 28),

                      // ── Logged meals ─────────────────────
                      const _SectionHeader('Logged Meals'),
                      const SizedBox(height: 12),

                      mealsAsync.when(
                        data: (meals) => meals.isEmpty
                            ? const Text('No meals logged yet.', style: TextStyle(color: AppTheme.textSecondary))
                            : Column(
                                children: meals.map((m) => _LoggedMealRow(food: m)).toList(),
                              ),
                        loading: () => const CircularProgressIndicator(color: AppTheme.accent),
                        error: (_, __) => const SizedBox(),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────
// MACRO BAR
// ─────────────────────────────────────────────
class _MacroBar extends StatelessWidget {
  final String label;
  final int current;
  final int goal;
  final Color color;
  final String unit;
  final String note;

  const _MacroBar({required this.label, required this.current, required this.goal, required this.color, required this.unit, required this.note});

  @override
  Widget build(BuildContext context) {
    final pct = (current / (goal == 0 ? 1 : goal)).clamp(0.0, 1.0);
    final isOver = current > goal;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(
                '$current / $goal $unit',
                style: TextStyle(color: isOver ? Colors.redAccent : color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppTheme.background,
              color: isOver ? Colors.redAccent : color,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text('${(pct * 100).round()}% of daily goal', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MICRO ROW
// ─────────────────────────────────────────────
class _MicroRow extends StatelessWidget {
  final String label;
  final String value;
  final String goal;

  const _MicroRow({required this.label, required this.value, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          Row(
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('goal: $goal', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CALORIE PIE ROW
// ─────────────────────────────────────────────
class _CaloriePieRow extends StatelessWidget {
  final int proteinCals;
  final int carbsCals;
  final int fatsCals;
  final int totalCals;

  const _CaloriePieRow({required this.proteinCals, required this.carbsCals, required this.fatsCals, required this.totalCals});

  @override
  Widget build(BuildContext context) {
    final total = totalCals == 0 ? 1 : totalCals;
    return Row(
      children: [
        _PieSegment(label: 'Protein', cals: proteinCals, pct: proteinCals / total, color: Colors.blueAccent),
        const SizedBox(width: 8),
        _PieSegment(label: 'Carbs', cals: carbsCals, pct: carbsCals / total, color: Colors.orangeAccent),
        const SizedBox(width: 8),
        _PieSegment(label: 'Fats', cals: fatsCals, pct: fatsCals / total, color: Colors.purpleAccent),
      ],
    );
  }
}

class _PieSegment extends StatelessWidget {
  final String label;
  final int cals;
  final double pct;
  final Color color;

  const _PieSegment({required this.label, required this.cals, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text('${(pct * 100).round()}%', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
            Text('$cals kcal', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOGGED MEAL ROW
// ─────────────────────────────────────────────
class _LoggedMealRow extends StatelessWidget {
  final FoodItem food;
  const _LoggedMealRow({required this.food});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (food.isAiLogged) const Text('🪄 ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text('${food.consumedAmount.toStringAsFixed(food.consumedAmount % 1 == 0 ? 0 : 1)} ${food.consumedUnit}  •  '
                    '${food.protein}g P  •  ${food.carbs}g C  •  ${food.fats}g F',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text('${food.calories} kcal', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16));
  }
}