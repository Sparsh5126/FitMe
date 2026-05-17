import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/features/recipes/providers/recipes_provider.dart';
import 'package:fitme/features/recipes/models/recipe_model.dart';
import 'package:fitme/features/recipes/screens/recipe_detail_screen.dart';
import 'package:fitme/features/nutrition/providers/nutrition_provider.dart';

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  static const _allTags = [
    'breakfast',
    'lunch',
    'post-workout',
    'high-protein',
    'budget',
    'quick',
    'vegetarian',
    'high-calorie',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(filteredRecipesProvider);
    final selectedTag = ref.watch(recipeTagFilterProvider);

    final theme = ThemeManager.instance.activeTheme;

    return Scaffold(
      backgroundColor: theme.colors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: theme.colors.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Recipes',
                    style: TextStyle(
                      color: theme.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Tag filter chips ─────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _TagChip(
                    label: 'All',
                    selected: selectedTag == null,
                    onTap: () =>
                        ref.read(recipeTagFilterProvider.notifier).setTag(null),
                  ),
                  ..._allTags.map(
                    (tag) => _TagChip(
                      label: tag,
                      selected: selectedTag == tag,
                      onTap: () => ref
                          .read(recipeTagFilterProvider.notifier)
                          .setTag(selectedTag == tag ? null : tag),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Recipe list ──────────────────────────────
            Expanded(
              child: recipes.isEmpty
                  ? Center(
                      child: Text(
                        'No recipes found',
                        style: TextStyle(color: theme.colors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                      itemCount: recipes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _RecipeCard(
                        recipe: recipes[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RecipeDetailScreen(recipeId: recipes[i].id),
                          ),
                        ),
                        onFavoriteTap: () async {
                          // Update local UI state (heart icon)
                          ref
                              .read(recipesProvider.notifier)
                              .toggleFavorite(recipes[i].id);
                          // Sync to Firestore favorites collection
                          await ref
                              .read(foodActionsProvider)
                              .toggleFavorite(recipes[i].toFoodItem());
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tag chip ─────────────────────────────────────────
class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.colors.accent : theme.colors.surfacePrimary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? theme.colors.backgroundPrimary
                : theme.colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Recipe card ──────────────────────────────────────
class _RecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  const _RecipeCard({
    required this.recipe,
    required this.onTap,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colors.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(recipe.emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: TextStyle(
                      color: theme.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: theme.colors.accent,
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${recipe.calories.toInt()} kcal',
                        style: TextStyle(
                          color: theme.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.fitness_center_rounded,
                        color: theme.colors.proteinColor,
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${recipe.protein.toInt()}g protein',
                        style: TextStyle(
                          color: theme.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.timer_rounded,
                        color: theme.colors.textSecondary,
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${recipe.prepMinutes}m',
                        style: TextStyle(
                          color: theme.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: recipe.tags
                        .take(2)
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                color: theme.colors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

            // Favorite
            GestureDetector(
              onTap: onFavoriteTap,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  recipe.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(recipe.isFavorite),
                  color: recipe.isFavorite
                      ? theme.colors.error
                      : theme.colors.textSecondary,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
