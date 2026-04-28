import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';
import '../screens/quantity_selection_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  static void push(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const FavoritesScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Favourites',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 22)),
            ]),
          ),

          const SizedBox(height: 16),

          Expanded(child: favAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent)),
            error: (e, _) => Center(
                child: Text('$e',
                    style: const TextStyle(color: Colors.redAccent))),
            data: (favs) {
              if (favs.isEmpty) return _EmptyFavourites();
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: favs.length,
                itemBuilder: (_, i) =>
                    _FavTile(food: favs[i]),
              );
            },
          )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FAVORITE TILE
// ─────────────────────────────────────────────
class _FavTile extends ConsumerWidget {
  final FoodItem food;
  const _FavTile({required this.food});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.favorite_rounded,
              color: AppTheme.accent, size: 20),
        ),
        title: Text(food.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${food.protein}g P  •  ${food.carbs}g C  •  ${food.fats}g F',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${food.calories} kcal',
              style: const TextStyle(
                  color: AppTheme.accent, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          // Remove from favourites
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(foodActionsProvider).removeFavorite(food.name);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.favorite_rounded,
                  size: 16, color: Colors.redAccent),
            ),
          ),
          const SizedBox(width: 6),
          // Quick log
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          QuantitySelectionScreen(baseFood: food)));
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 16, color: AppTheme.accent),
            ),
          ),
        ]),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    QuantitySelectionScreen(baseFood: food))),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────
class _EmptyFavourites extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.favorite_border_rounded,
            color: AppTheme.textSecondary, size: 36),
      ),
      const SizedBox(height: 20),
      const Text('No favourites yet',
          style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 8),
      const Text('Tap the ♡ on any food card to save it here.',
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 13),
          textAlign: TextAlign.center),
    ]),
  );
}
