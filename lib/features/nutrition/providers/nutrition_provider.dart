import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/food_item.dart';
import '../repositories/nutrition_repository.dart';

final nutritionRepoProvider = Provider((ref) => NutritionRepository());

class NutritionNotifier extends Notifier<List<FoodItem>> {
  @override
  List<FoodItem> build() {
    _loadMeals();
    return []; 
  }

  Future<void> _loadMeals() async {
    final repo = ref.read(nutritionRepoProvider);
    final meals = await repo.getTodayMeals();
    state = meals; 
  }

  // --- OPTIMISTIC UI UPDATES ---
  
  Future<void> addFood(FoodItem item) async {
    // 1. Update the UI instantly
    state = [item, ...state]; 
    // 2. Save to the cloud in the background
    await ref.read(nutritionRepoProvider).addMeal(item);
  }

  Future<void> updateFood(String id, FoodItem updatedItem) async {
    // 1. Update the UI instantly
    state = [
      for (final item in state)
        if (item.id == id) updatedItem else item
    ];
    // 2. Save to the cloud in the background
    await ref.read(nutritionRepoProvider).updateMeal(updatedItem);
  }

  Future<void> deleteFood(String id) async {
    // 1. Update the UI instantly
    state = state.where((item) => item.id != id).toList();
    // 2. Delete from the cloud in the background
    await ref.read(nutritionRepoProvider).deleteMeal(id);
  }

  // Used by the Smart Logger Sheet
  Future<void> parseAndLogFood(String rawText) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final newItem = FoodItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(), 
      name: rawText,
      calories: 550, 
      protein: 45,
      carbs: 50,
      fats: 15,
      consumedAmount: 1, 
      consumedUnit: 'serving', 
    );
    
    // Uses the new optimistic addFood method
    await addFood(newItem);
  }
}

final nutritionProvider = NotifierProvider<NutritionNotifier, List<FoodItem>>(() {
  return NutritionNotifier();
});