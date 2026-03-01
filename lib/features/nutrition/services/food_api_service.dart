import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';

class FoodApiService {
  // We ask for 15 results per search to keep it fast
  static const String _baseUrl = 'https://world.openfoodfacts.org/cgi/search.pl';

  Future<List<FoodItem>> searchFood(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // Build the specific URL for OpenFoodFacts
      final uri = Uri.parse(
          '$_baseUrl?search_terms=${Uri.encodeComponent(query)}&search_simple=1&action=process&json=1&page_size=15');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List products = data['products'] ?? [];

        // Translate their messy JSON into our clean FoodItem models
        return products.map((p) {
          final nutriments = p['nutriments'] ?? {};
          
          return FoodItem(
            id: p['code'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: p['product_name'] ?? 'Unknown Food',
            // They provide data per 100g. We will use that as our baseline "1 serving".
            // We use .round() because APIs often return weird decimals like 4.00001
            calories: (nutriments['energy-kcal_100g'] ?? 0).round(),
            protein: (nutriments['proteins_100g'] ?? 0).round(),
            carbs: (nutriments['carbohydrates_100g'] ?? 0).round(),
            fats: (nutriments['fat_100g'] ?? 0).round(),
            consumedAmount: 100.0, // Default to 100
            consumedUnit: 'g',     // Default to grams for accurate math
          );
        }).where((food) => food.calories > 0 && food.name != 'Unknown Food').toList(); // Filter out junk data
        
      } else {
        throw Exception('Failed to load food data');
      }
    } catch (e) {
      print("API Search Error: $e");
      return []; // Return empty list if the internet drops or API fails
    }
  }
}