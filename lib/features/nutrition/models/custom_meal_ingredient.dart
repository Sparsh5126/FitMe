import 'food_item.dart';

/// Represents one ingredient inside a custom meal recipe,
/// with its user-chosen quantity and scaled macro values.
class CustomMealIngredient {
  final String foodId;
  final String name;
  final double amount; // user-chosen amount
  final String unit; // unit label (g, ml, serving…)

  // Macros already scaled to [amount]
  final int calories;
  final int protein;
  final int carbs;
  final int fats;

  // Base reference (for re-scaling when amount changes)
  final double baseAmount;
  final int baseCal;
  final int basePro;
  final int baseCarb;
  final int baseFat;

  const CustomMealIngredient({
    required this.foodId,
    required this.name,
    required this.amount,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.baseAmount,
    required this.baseCal,
    required this.basePro,
    required this.baseCarb,
    required this.baseFat,
  });

  factory CustomMealIngredient.fromFoodItem(FoodItem food) {
    return CustomMealIngredient(
      foodId: food.id,
      name: food.name,
      amount: food.consumedAmount,
      unit: food.consumedUnit,
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fats: food.fats,
      baseAmount: food.consumedAmount,
      baseCal: food.calories,
      basePro: food.protein,
      baseCarb: food.carbs,
      baseFat: food.fats,
    );
  }

  /// Returns a copy scaled to [newAmount] (same unit).
  CustomMealIngredient scaledTo(double newAmount) {
    final ratio = newAmount / (baseAmount == 0 ? 1 : baseAmount);
    return CustomMealIngredient(
      foodId: foodId,
      name: name,
      amount: newAmount,
      unit: unit,
      calories: (baseCal * ratio).round(),
      protein: (basePro * ratio).round(),
      carbs: (baseCarb * ratio).round(),
      fats: (baseFat * ratio).round(),
      baseAmount: baseAmount,
      baseCal: baseCal,
      basePro: basePro,
      baseCarb: baseCarb,
      baseFat: baseFat,
    );
  }

  Map<String, dynamic> toMap() => {
        'foodId': foodId,
        'name': name,
        'amount': amount,
        'unit': unit,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'baseAmount': baseAmount,
        'baseCal': baseCal,
        'basePro': basePro,
        'baseCarb': baseCarb,
        'baseFat': baseFat,
      };

  factory CustomMealIngredient.fromMap(Map<String, dynamic> m) {
    return CustomMealIngredient(
      foodId: m['foodId'] ?? '',
      name: m['name'] ?? '',
      amount: (m['amount'] ?? 1).toDouble(),
      unit: m['unit'] ?? 'serving',
      calories: (m['calories'] ?? 0).toInt(),
      protein: (m['protein'] ?? 0).toInt(),
      carbs: (m['carbs'] ?? 0).toInt(),
      fats: (m['fats'] ?? 0).toInt(),
      baseAmount: (m['baseAmount'] ?? 1).toDouble(),
      baseCal: (m['baseCal'] ?? 0).toInt(),
      basePro: (m['basePro'] ?? 0).toInt(),
      baseCarb: (m['baseCarb'] ?? 0).toInt(),
      baseFat: (m['baseFat'] ?? 0).toInt(),
    );
  }
}
