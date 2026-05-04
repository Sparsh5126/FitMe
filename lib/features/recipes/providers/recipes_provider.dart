import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_model.dart';
import '../data/recipes_data.dart';
import '../../nutrition/providers/nutrition_provider.dart';

// ── Favorites persistence key ─────────────────────────
const _kFavoritesKey = 'recipe_favorites';

// ── Notifier ──────────────────────────────────────────
class RecipesNotifier extends Notifier<List<RecipeModel>> {
  @override
  List<RecipeModel> build() {
    _loadFavorites();
    return predefinedRecipes;
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final localSaved = prefs.getStringList(_kFavoritesKey) ?? [];

    // Merge with Firestore favorites so cross-device state is respected.
    // The Firestore favorites stream uses food.name (= recipe.title) as key.
    final firestoreFavs = ref.read(favoritesProvider).value ?? [];
    final firestoreFavTitles = firestoreFavs
        .map((f) => f.name.toLowerCase())
        .toSet();

    state = state.map((r) {
      final inLocal = localSaved.contains(r.id);
      final inFirestore = firestoreFavTitles.contains(r.title.toLowerCase());
      return r.copyWith(isFavorite: inLocal || inFirestore);
    }).toList();
  }

  Future<void> toggleFavorite(String recipeId) async {
    // 1. Update in-memory UI state
    state = state.map((r) {
      if (r.id == recipeId) return r.copyWith(isFavorite: !r.isFavorite);
      return r;
    }).toList();

    // 2. Persist to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final favIds = state.where((r) => r.isFavorite).map((r) => r.id).toList();
    await prefs.setStringList(_kFavoritesKey, favIds);

    // 3. Firestore sync is handled by the caller (recipes_screen / recipe_detail_screen)
    //    via foodActionsProvider.toggleFavorite() to keep this notifier side-effect-free.
  }
}

// ── Provider: all recipes with favorite state ─────────
final recipesProvider = NotifierProvider<RecipesNotifier, List<RecipeModel>>(
  RecipesNotifier.new,
);

// ── Provider: favorites only ──────────────────────────
final favoriteRecipesProvider = Provider<List<RecipeModel>>((ref) {
  return ref.watch(recipesProvider).where((r) => r.isFavorite).toList();
});

// ── Filter provider ───────────────────────────────────
class RecipeTagFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setTag(String? tag) => state = tag;
}

final recipeTagFilterProvider = NotifierProvider<RecipeTagFilterNotifier, String?>(
  RecipeTagFilterNotifier.new,
);

final filteredRecipesProvider = Provider<List<RecipeModel>>((ref) {
  final recipes = ref.watch(recipesProvider);
  final tag = ref.watch(recipeTagFilterProvider);
  if (tag == null) return recipes;
  return recipes.where((r) => r.tags.contains(tag)).toList();
});