import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/recipes_provider.dart';
import '../../nutrition/providers/nutrition_provider.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _logging = false;

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);
    final recipe = recipes.firstWhere((r) => r.id == widget.recipeId);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(recipe.title,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      // Update local UI state (heart icon on Recipes screen)
                      ref.read(recipesProvider.notifier).toggleFavorite(recipe.id);
                      // Sync to Firestore so it appears in the global Favorites tab
                      await ref.read(foodActionsProvider).toggleFavorite(
                        recipe.toFoodItem(),
                      );
                    },
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        recipe.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        key: ValueKey(recipe.isFavorite),
                        color: recipe.isFavorite ? Colors.redAccent : AppTheme.textSecondary,
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
                    // ── Emoji + meta ──────────────────────
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(recipe.emoji,
                              style: const TextStyle(fontSize: 48)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Macro row ─────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _MacroChip('Calories', '${recipe.calories.toInt()}', 'kcal', AppTheme.accent),
                          _MacroChip('Protein', '${recipe.protein.toInt()}', 'g', AppTheme.proteinColor),
                          _MacroChip('Carbs', '${recipe.carbs.toInt()}', 'g', AppTheme.carbsColor),
                          _MacroChip('Fats', '${recipe.fats.toInt()}', 'g', AppTheme.fatsColor),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Prep time + tags row
                    Row(
                      children: [
                        const Icon(Icons.timer_rounded, color: AppTheme.textSecondary, size: 14),
                        const SizedBox(width: 4),
                        Text('${recipe.prepMinutes} min prep',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(width: 12),
                        ...recipe.tags.map((t) => Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(t,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            )),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Ingredients ───────────────────────
                    const Text('Ingredients',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...recipe.ingredients.map(
                      (ing) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(ing,
                                  style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Steps ─────────────────────────────
                    const Text('Steps',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...recipe.steps.asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text('${e.key + 1}',
                                        style: const TextStyle(
                                            color: AppTheme.accent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(e.value,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14, height: 1.5)),
                                ),
                              ],
                            ),
                          ),
                        ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // ── Log as Meal CTA ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logging ? null : () => _logMeal(context, recipe),
                  icon: _logging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.background),
                        )
                      : const Icon(Icons.add_circle_outline_rounded),
                  label: Text(_logging ? 'Logging...' : 'Log as Meal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logMeal(BuildContext context, recipe) async {
    setState(() => _logging = true);
    HapticFeedback.mediumImpact();

    try {
      // Route through the shared nutrition pipeline:
      // → logs collection (home screen / streak / insights)
      // → custom_meals (Customs tab with ingredients for reuse)
      // → skips recents (recipes live in Customs, not Recents)
      await ref.read(foodActionsProvider).logRecipe(recipe);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${recipe.title} logged!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log meal. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  String _inferMealType(int hour) {
    if (hour < 11) return 'breakfast';
    if (hour < 15) return 'lunch';
    if (hour < 19) return 'snack';
    return 'dinner';
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MacroChip(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(unit, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}