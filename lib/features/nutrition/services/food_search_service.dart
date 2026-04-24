import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';

// Result wrapper so callers know which source matched
class FoodSearchResult {
  final List<FoodItem> foods;
  final FoodSource source;
  const FoodSearchResult(this.foods, this.source);
}

enum FoodSource { favorites, recents, custom, commonDb, nutritionix, usda, openFoodFacts, gemini, none }

class FoodSearchService {
  static const _nutritionixAppId = 'YOUR_NUTRITIONIX_APP_ID';
  static const _nutritionixApiKey = 'YOUR_NUTRITIONIX_API_KEY';

  // ─────────────────────────────────────────
  // SMART LOGGER SEARCH (full cascade)
  // Called when user types in smart logger
  // ─────────────────────────────────────────
  static Future<FoodSearchResult> smartLoggerSearch({
    required String query,
    required List<FoodItem> recents,
    required List<FoodItem> customMeals,
    required List<FoodItem> commonFoods,
  }) async {
    // 1. Exact match in recents
    final exactRecent = _exactMatch(query, recents);
    if (exactRecent != null) return FoodSearchResult([exactRecent], FoodSource.recents);

    // 2. Fuzzy match in recents
    final fuzzyRecent = _fuzzyMatch(query, recents);
    if (fuzzyRecent != null) return FoodSearchResult([fuzzyRecent], FoodSource.recents);

    // 3. Custom meals
    final customMatch = _fuzzyMatch(query, customMeals);
    if (customMatch != null) return FoodSearchResult([customMatch], FoodSource.custom);

    // 4. Common foods DB
    final commonMatch = _fuzzyMatch(query, commonFoods);
    if (commonMatch != null) return FoodSearchResult([commonMatch], FoodSource.commonDb);

    // 5. Gemini — caller handles this since it needs context
    return const FoodSearchResult([], FoodSource.none);
  }

  // ─────────────────────────────────────────
  // LOG SHEET SEARCH (full API cascade)
  // Called when user types in search bar
  // ─────────────────────────────────────────
  static Future<FoodSearchResult> logSheetSearch({
    required String query,
    required List<FoodItem> favorites,
    required List<FoodItem> recents,
    required List<FoodItem> customMeals,
    required List<FoodItem> commonFoods,
  }) async {
    if (query.trim().isEmpty) return const FoodSearchResult([], FoodSource.none);

    // 1. Favorites
    final favResults = _fuzzyList(query, favorites);
    if (favResults.isNotEmpty) return FoodSearchResult(favResults, FoodSource.favorites);

    // 2. Recents
    final recentResults = _fuzzyList(query, recents);
    if (recentResults.isNotEmpty) return FoodSearchResult(recentResults, FoodSource.recents);

    // 3. Custom meals
    final customResults = _fuzzyList(query, customMeals);
    if (customResults.isNotEmpty) return FoodSearchResult(customResults, FoodSource.custom);

    // 4. Common foods DB
    final commonResults = _fuzzyList(query, commonFoods);
    if (commonResults.isNotEmpty) return FoodSearchResult(commonResults, FoodSource.commonDb);

    // 5. Nutritionix
    final nutritionixResults = await _searchNutritionix(query);
    if (nutritionixResults.isNotEmpty) return FoodSearchResult(nutritionixResults, FoodSource.nutritionix);

    // 6. USDA
    final usdaResults = await _searchUsda(query);
    if (usdaResults.isNotEmpty) return FoodSearchResult(usdaResults, FoodSource.usda);

    // 7. OpenFoodFacts
    final offResults = await _searchOpenFoodFacts(query);
    if (offResults.isNotEmpty) return FoodSearchResult(offResults, FoodSource.openFoodFacts);

    return const FoodSearchResult([], FoodSource.none);
  }

  // ─────────────────────────────────────────
  // LOAD COMMON FOODS FROM BUNDLED JSON
  // ─────────────────────────────────────────
  static Future<List<FoodItem>> loadCommonFoods() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/common_foods.json');
      final List data = jsonDecode(jsonStr);
      return data.map((item) => FoodItem(
        id: item['id'],
        name: item['name'],
        calories: item['calories'],
        protein: item['protein'],
        carbs: item['carbs'],
        fats: item['fats'],
        consumedAmount: (item['consumedAmount'] ?? 1).toDouble(),
        consumedUnit: item['consumedUnit'] ?? 'serving',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────
  // FUZZY MATCHING LOGIC
  // ─────────────────────────────────────────

  // Returns single best match or null
  static FoodItem? _exactMatch(String query, List<FoodItem> list) {
    final q = query.trim().toLowerCase();
    for (final food in list) {
      if (food.name.toLowerCase() == q) return food;
    }
    return null;
  }

  // Word-overlap fuzzy: match if ≥50% of query words found in food name
  static FoodItem? _fuzzyMatch(String query, List<FoodItem> list) {
    final queryWords = _tokenize(query);
    if (queryWords.isEmpty) return null;

    FoodItem? bestMatch;
    double bestScore = 0;

    for (final food in list) {
      final foodWords = _tokenize(food.name);
      final overlap = queryWords.where((w) => foodWords.any((fw) => fw.contains(w) || w.contains(fw))).length;
      final score = overlap / queryWords.length;
      if (score >= 0.5 && score > bestScore) {
        bestScore = score;
        bestMatch = food;
      }
    }
    return bestMatch;
  }

  // Returns all fuzzy matches (for list display)
  static List<FoodItem> _fuzzyList(String query, List<FoodItem> list) {
    final queryWords = _tokenize(query);
    if (queryWords.isEmpty) return [];

    final results = <MapEntry<FoodItem, double>>[];

    for (final food in list) {
      final foodWords = _tokenize(food.name);
      final overlap = queryWords.where((w) => foodWords.any((fw) => fw.contains(w) || w.contains(fw))).length;
      final score = overlap / queryWords.length;
      if (score >= 0.4) results.add(MapEntry(food, score));
    }

    results.sort((a, b) => b.value.compareTo(a.value));
    return results.map((e) => e.key).take(10).toList();
  }

  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[\s,/\-]+'))
        .where((w) => w.length > 1)
        .toList();
  }

  // ─────────────────────────────────────────
  // NUTRITIONIX API
  // ─────────────────────────────────────────
  static Future<List<FoodItem>> _searchNutritionix(String query) async {
    try {
      final response = await http.post(
        Uri.parse('https://trackapi.nutritionix.com/v2/natural/nutrients'),
        headers: {
          'Content-Type': 'application/json',
          'x-app-id': _nutritionixAppId,
          'x-app-key': _nutritionixApiKey,
        },
        body: jsonEncode({'query': query}),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List foods = data['foods'] ?? [];

      return foods.map((f) => FoodItem(
        id: 'nix_${f['food_name']}_${DateTime.now().millisecondsSinceEpoch}',
        name: _capitalize(f['food_name'] ?? 'Unknown'),
        calories: (f['nf_calories'] ?? 0).round(),
        protein: (f['nf_protein'] ?? 0).round(),
        carbs: (f['nf_total_carbohydrate'] ?? 0).round(),
        fats: (f['nf_total_fat'] ?? 0).round(),
        consumedAmount: (f['serving_qty'] ?? 1).toDouble(),
        consumedUnit: f['serving_unit'] ?? 'serving',
      )).where((f) => f.calories > 0).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────
  // USDA API
  // ─────────────────────────────────────────
  static Future<List<FoodItem>> _searchUsda(String query) async {
    try {
      const apiKey = 'YOUR_USDA_API_KEY'; // free at fdc.nal.usda.gov
      final uri = Uri.parse(
        'https://api.nal.usda.gov/fdc/v1/foods/search?query=${Uri.encodeComponent(query)}&pageSize=10&api_key=$apiKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List foods = data['foods'] ?? [];

      return foods.map((f) {
        final nutrients = (f['foodNutrients'] as List? ?? []);
        int _n(int id) => (nutrients.firstWhere((n) => n['nutrientId'] == id, orElse: () => {'value': 0})['value'] ?? 0).round();

        return FoodItem(
          id: 'usda_${f['fdcId']}',
          name: f['description'] ?? 'Unknown',
          calories: _n(1008),  // Energy
          protein: _n(1003),   // Protein
          carbs: _n(1005),     // Carbs
          fats: _n(1004),      // Fat
          consumedAmount: 100,
          consumedUnit: 'g',
        );
      }).where((f) => f.calories > 0).take(8).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────
  // OPEN FOOD FACTS API
  // ─────────────────────────────────────────
  static Future<List<FoodItem>> _searchOpenFoodFacts(String query) async {
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(query)}&search_simple=1&action=process&json=1&page_size=10',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List products = data['products'] ?? [];

      return products.map((p) {
        final n = p['nutriments'] ?? {};
        return FoodItem(
          id: 'off_${p['code'] ?? DateTime.now().millisecondsSinceEpoch}',
          name: p['product_name'] ?? 'Unknown',
          calories: (n['energy-kcal_100g'] ?? 0).round(),
          protein: (n['proteins_100g'] ?? 0).round(),
          carbs: (n['carbohydrates_100g'] ?? 0).round(),
          fats: (n['fat_100g'] ?? 0).round(),
          consumedAmount: 100,
          consumedUnit: 'g',
        );
      }).where((f) => f.calories > 0 && f.name != 'Unknown').take(8).toList();
    } catch (_) {
      return [];
    }
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}