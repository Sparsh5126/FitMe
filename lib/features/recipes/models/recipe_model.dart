import '../../nutrition/models/food_item.dart';

class RecipeModel {
  final String id;
  final String title;
  final String emoji;
  final List<String> tags;
  final int prepMinutes;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final List<String> ingredients;
  final List<String> steps;
  final bool isFavorite;

  const RecipeModel({
    required this.id,
    required this.title,
    required this.emoji,
    required this.tags,
    required this.prepMinutes,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.ingredients,
    required this.steps,
    this.isFavorite = false,
  });

  RecipeModel copyWith({bool? isFavorite}) {
    return RecipeModel(
      id: id,
      title: title,
      emoji: emoji,
      tags: tags,
      prepMinutes: prepMinutes,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      ingredients: ingredients,
      steps: steps,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// Convert to a [FoodItem] using the shared nutrition schema.
  /// Used for logging to the `logs` collection and saving to `custom_meals`.
  FoodItem toFoodItem() {
    final now = DateTime.now();
    return FoodItem(
      id: '${id}_${now.millisecondsSinceEpoch}',
      name: title,
      calories: calories.round(),
      protein: protein.round(),
      carbs: carbs.round(),
      fats: fats.round(),
      consumedAmount: 1.0,
      consumedUnit: 'serving',
      isAiLogged: false,
      isFavorite: isFavorite,
      dateString: FoodItem.dateFor(now),
      timestamp: now.millisecondsSinceEpoch,
      ingredients: ingredients,
    );
  }

  /// Convert to a [FoodItem] suitable for saving as a custom meal template
  /// (no timestamp / dateString tied to a specific log event).
  FoodItem toCustomMealTemplate() {
    return FoodItem(
      id: 'recipe_$id',
      name: title,
      calories: calories.round(),
      protein: protein.round(),
      carbs: carbs.round(),
      fats: fats.round(),
      consumedAmount: 1.0,
      consumedUnit: 'serving',
      isAiLogged: false,
      isFavorite: isFavorite,
      ingredients: ingredients,
    );
  }
}