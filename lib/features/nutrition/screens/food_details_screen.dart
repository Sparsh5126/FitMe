import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/oil_level_selector.dart';
import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';
import '../providers/oil_level_provider.dart';
import 'quantity_selection_screen.dart';

class FoodDetailsScreen extends ConsumerStatefulWidget {
  final FoodItem food;

  const FoodDetailsScreen({super.key, required this.food});

  @override
  ConsumerState<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends ConsumerState<FoodDetailsScreen> {
  OilLevel _oilLevel = OilLevel.normal;
  late bool _isOily;
  late FoodItem _displayFood;

  @override
  void initState() {
    super.initState();
    _isOily = isOilyIndianFood(widget.food.name);
    _displayFood = widget.food;
    if (_isOily) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final saved = ref.read(oilPreferenceProvider);
        final level = saved[widget.food.name.toLowerCase()] ?? OilLevel.normal;
        if (level != _oilLevel) {
          setState(() {
            _oilLevel = level;
            _displayFood = applyOilLevel(widget.food, _oilLevel);
          });
        }
      });
    }
  }

  void _onOilLevelChanged(OilLevel level) {
    setState(() {
      _oilLevel = level;
      _displayFood = applyOilLevel(widget.food, level);
    });
    ref.read(oilPreferenceProvider.notifier).set(widget.food.name, level);
  }

  @override
  Widget build(BuildContext context) {
    final food = _displayFood;
    final favoritesAsync = ref.watch(favoritesProvider);
    final isFavorite = favoritesAsync.value?.any((f) => f.name == food.name) ?? false;

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
                    child: Text(food.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis),
                  ),
                  // Favorite heart
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      if (isFavorite) {
                        await ref.read(foodActionsProvider).removeFavorite(food.name);
                      } else {
                        await ref.read(foodActionsProvider).addFavorite(food);
                      }
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        key: ValueKey(isFavorite),
                        color: isFavorite ? Colors.redAccent : AppTheme.textSecondary,
                        size: 26,
                      ),
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
                    // ── Serving info ─────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${food.consumedAmount % 1 == 0 ? food.consumedAmount.toInt() : food.consumedAmount} ${food.consumedUnit}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ),
                        if (food.isAiLogged) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amberAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🪄', style: TextStyle(fontSize: 12)),
                                SizedBox(width: 4),
                                Text('AI Estimate', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // ── Oil/Richness Slider ───────────────
                    if (_isOily) ...[
                      const SizedBox(height: 16),
                      OilLevelSelector(
                        value: _oilLevel,
                        onChanged: _onOilLevelChanged,
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Big calorie display ──────────────
                    Center(
                      child: Column(
                        children: [
                          Text('${food.calories}',
                              style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1)),
                          const Text('kcal', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Macro rings ──────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _DetailRing(label: 'Protein', value: food.protein, color: Colors.blueAccent, total: food.calories, multiplier: 4),
                        _DetailRing(label: 'Carbs', value: food.carbs, color: Colors.orangeAccent, total: food.calories, multiplier: 4),
                        _DetailRing(label: 'Fats', value: food.fats, color: Colors.purpleAccent, total: food.calories, multiplier: 9),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Full macro table ─────────────────
                    const _SectionHeader('Nutrition Facts'),
                    const SizedBox(height: 12),

                    _NutritionTable(food: food),

                    const SizedBox(height: 28),

                    // ── Source badge ─────────────────────
                    if (food.isAiLogged)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                        ),
                        child: const Text(
                          '🪄 Macros estimated by Gemini AI. Values may not be 100% accurate.',
                          style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // ── Action buttons ───────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: AppTheme.background,
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Column(
                children: [
                  // Log this food (with current oil level applied)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => QuantitySelectionScreen(baseFood: _displayFood))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Log This Food', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Save as custom meal
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await ref.read(foodActionsProvider).saveCustomMeal(food);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saved to Custom Meals ✓'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: const Text('Save as Custom Meal'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DETAIL RING (shows % of calories from macro)
// ─────────────────────────────────────────────
class _DetailRing extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final int total;
  final int multiplier;

  const _DetailRing({required this.label, required this.value, required this.color, required this.total, required this.multiplier});

  @override
  Widget build(BuildContext context) {
    final calFromMacro = value * multiplier;
    final pct = total == 0 ? 0.0 : (calFromMacro / total).clamp(0.0, 1.0);

    return Column(
      children: [
        CircularPercentIndicator(
          radius: 48,
          lineWidth: 7,
          animation: true,
          percent: pct,
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${value}g', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
              Text('${(pct * 100).round()}%', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ],
          ),
          circularStrokeCap: CircularStrokeCap.round,
          progressColor: color,
          backgroundColor: AppTheme.surface,
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// NUTRITION TABLE
// ─────────────────────────────────────────────
class _NutritionTable extends StatelessWidget {
  final FoodItem food;
  const _NutritionTable({required this.food});

  @override
  Widget build(BuildContext context) {
    final fiber = (food.carbs * 0.08).round();
    final sugar = (food.carbs * 0.25).round();
    final saturated = (food.fats * 0.35).round();

    final rows = [
      ('Calories', '${food.calories} kcal', null),
      ('Total Fat', '${food.fats}g', null),
      ('  Saturated Fat', '${saturated}g', AppTheme.textSecondary),
      ('Total Carbohydrates', '${food.carbs}g', null),
      ('  Dietary Fiber', '${fiber}g', AppTheme.textSecondary),
      ('  Sugars', '${sugar}g', AppTheme.textSecondary),
      ('Protein', '${food.protein}g', null),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final i = e.key;
          final row = e.value;
          final isSubItem = row.$3 != null;
          final isLast = i == rows.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row.$1, style: TextStyle(
                      color: isSubItem ? AppTheme.textSecondary : Colors.white,
                      fontWeight: isSubItem ? FontWeight.normal : FontWeight.bold,
                      fontSize: isSubItem ? 12 : 14,
                    )),
                    Text(row.$2, style: TextStyle(
                      color: isSubItem ? AppTheme.textSecondary : Colors.white,
                      fontWeight: isSubItem ? FontWeight.normal : FontWeight.bold,
                      fontSize: isSubItem ? 12 : 14,
                    )),
                  ],
                ),
              ),
              if (!isLast) Divider(height: 1, color: Colors.white.withOpacity(0.05)),
            ],
          );
        }).toList(),
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