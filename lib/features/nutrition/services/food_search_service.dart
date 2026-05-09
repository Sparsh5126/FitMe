import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import 'food_knowledge_resolver.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS / RESULT TYPES (kept for backward-compat with log_sheet, custom_meal_form)
// ─────────────────────────────────────────────────────────────────────────────
enum FoodSource { favorites, recents, custom, commonDb, off, usda, gemini, command, none }

class FoodSearchResult {
  final List<FoodItem> foods;
  final FoodSource source;
  const FoodSearchResult(this.foods, this.source);
}

class ParsedCustomMeal {
  final FoodItem summary;
  final List<MealItem> ingredients;
  ParsedCustomMeal(this.summary, this.ingredients);
}

class MealItem {
  final FoodItem food;
  final double quantity;
  const MealItem(this.food, this.quantity);
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOD SEARCH SERVICE
// Thin delegation layer → FoodKnowledgeResolver.
// All heavy logic (scoring, aliases, plural maps, OFF/USDA) now lives there.
// ─────────────────────────────────────────────────────────────────────────────
class FoodSearchService {
  // ── Common foods (delegates to resolver cache) ───────────────────────────
  static Future<List<FoodItem>> loadCommonFoods() =>
      FoodKnowledgeResolver.loadCommonFoods();

  // ── Log-sheet unified search (delegates to resolver) ─────────────────────
  static Future<FoodSearchResult> logSheetSearch({
    required String query,
    required List<FoodItem> favorites,
    required List<FoodItem> recents,
    required List<FoodItem> customMeals,
    required List<FoodItem> commonFoods,
  }) async {
    if (query.trim().isEmpty) return const FoodSearchResult([], FoodSource.none);
    final foods = await FoodKnowledgeResolver.search(
      query: query,
      customs: customMeals,
      commonFoods: commonFoods,
      recents: recents,
      favorites: favorites,
    );
    return FoodSearchResult(foods, FoodSource.none);
  }

  // ── Barcode lookup (OFF → USDA fallback) ─────────────────────────────────
  static Future<FoodItem?> lookupBarcode(String barcode) async {
    debugPrint('[FoodSearch] barcode: $barcode');
    String? productName;

    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
        '?fields=product_name,nutriments',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': 'FitMe/1.0'})
          .timeout(const Duration(seconds: 2));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['status'] == 1) {
          final p    = data['product'] as Map;
          final n    = (p['nutriments'] as Map?) ?? {};
          final name = (p['product_name'] as String? ?? '').trim();
          if (name.isNotEmpty) {
            productName = name;
            final cal = _nMap(n, ['energy-kcal_100g', 'energy_100g']);
            if (cal > 0) {
              debugPrint('[FoodSearch] OFF hit: $name ($cal kcal)');
              return FoodItem(
                id: 'off_$barcode',
                name: _capitalize(name),
                calories: cal,
                protein:  _nMap(n, ['proteins_100g']),
                carbs:    _nMap(n, ['carbohydrates_100g']),
                fats:     _nMap(n, ['fat_100g']),
                consumedAmount: 100,
                consumedUnit: 'g',
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[FoodSearch] OFF barcode: $e');
    }

    // USDA fallback using resolver search
    if (productName != null) {
      try {
        final results = await FoodKnowledgeResolver.search(
          query: productName,
          customs: [],
          commonFoods: [],
          recents: [],
          favorites: [],
        ).timeout(const Duration(seconds: 2));
        if (results.isNotEmpty) {
          debugPrint('[FoodSearch] USDA hit for: $productName');
          return results.first;
        }
      } catch (e) {
        debugPrint('[FoodSearch] USDA fallback: $e');
      }
    }

    debugPrint('[FoodSearch] barcode not found: $barcode');
    return null;
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  static int _nMap(Map n, List<String> keys) {
    for (final k in keys) {
      final v = n[k];
      if (v != null) return (v as num).round();
    }
    return 0;
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}