import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../services/gemini_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FoodSearchResult {
  final List<FoodItem> foods;
  final FoodSource source;
  const FoodSearchResult(this.foods, this.source);
}

enum FoodSource { favorites, recents, custom, commonDb, off, usda, gemini, command, none }

class ParsedCustomMeal {
  final FoodItem summary;
  final List<MealItem> ingredients;
  ParsedCustomMeal(this.summary, this.ingredients);
}

const Map<String, List<String>> _aliases = {
  'chapati':         ['roti'],
  'chapatti':        ['roti'],
  'phulka':          ['roti'],
  'naan':            ['roti'],
  'daal':            ['dal'],
  'lentil':          ['dal'],
  'lentils':         ['dal'],
  'makhani':         ['dal', 'butter'],
  'tadka':           ['dal'],
  'dal makhani':     ['dal'],
  'moong':           ['dal', 'moong'],
  'chana':           ['dal', 'chana'],
  'toor':            ['dal'],
  'arhar':           ['dal'],
  'masoor':          ['dal'],
  'chawal':          ['rice'],
  'biryani':         ['chicken', 'biryani'],
  'pulao':           ['rice'],
  'khichri':         ['khichdi'],
  'murgh':           ['chicken'],
  'grilled chicken': ['chicken', 'breast'],
  'boneless':        ['chicken', 'breast'],
  'cottage cheese':  ['paneer'],
  'shahi paneer':    ['paneer', 'butter', 'masala'],
  'bhel':            ['chaat'],
  'sev puri':        ['chaat'],
  'gol gappa':       ['pani', 'puri'],
  'puchka':          ['pani', 'puri'],
  'chai':            ['tea'],
  'doodh':           ['milk'],
  'buttermilk':      ['chaas'],
  'sabji':           ['sabzi'],
  'sabzee':          ['sabzi'],
  'bhaji':           ['sabzi'],
  'aloo':            ['potato'],
  'gobi':            ['broccoli'],
  'dahi':            ['curd'],
  'chole':           ['chana', 'chole'],
  'rajma':           ['rajma'],
  'poori':           ['puri'],
  'besan':           ['chana', 'dal'],
  'anda':            ['egg'],
  'matar':           ['peas'],
  'gobhi':           ['cauliflower'],
  'lauki':           ['gourd'],
  'karela':          ['bitter', 'gourd'],
  'bhindi':          ['okra', 'bhindi'],
  'baingan':         ['eggplant'],
  'methi':           ['fenugreek'],
  'palak':           ['spinach'],
  'kadhi':           ['kadhi'],
};

class MealItem {
  final FoodItem food;
  final double quantity;
  const MealItem(this.food, this.quantity);
}

const Map<String, String> _plurals = {
  'rotis':     'roti',
  'chapatis':  'chapati',
  'chapattis': 'chapati',
  'parathas':  'paratha',
  'puris':     'puri',
  'pooris':    'puri',
  'idlis':     'idli',
  'dosas':     'dosa',
  'eggs':      'egg',
  'pieces':    'piece',
  'slices':    'slice',
  'bananas':   'banana',
  'apples':    'apple',
  'samosas':   'samosa',
  'pakoras':   'pakora',
  'bowls':     'bowl',
  'plates':    'plate',
  'cups':      'cup',
  'katoris':   'katori',
  'scoops':    'scoop',
  'bars':      'bar',
  'tbsps':     'tbsp',
  'tablespoon':'tbsp',
  'tablespoons':'tbsp',
  'teaspoon':  'tsp',
  'teaspoons': 'tsp',
  'tsps':      'tsp',
  'grams':     'g',
  'gram':      'g',
  'kilograms': 'kg',
  'kilogram':  'kg',
  'milliliters':'ml',
  'millilitres':'ml',
  'liters':    'l',
  'litres':    'l',
  'glasses':   'glass',
};

const Map<String, double> _wordNumbers = {
  'one':    1, 'ek':    1,
  'two':    2, 'do':    2,
  'three':  3, 'teen':  3, 'tin': 3,
  'four':   4, 'char':  4,
  'five':   5, 'paanch':5,
  'six':    6, 'chhe':  6,
  'seven':  7, 'saat':  7,
  'eight':  8, 'aath':  8,
  'half':   0.5, 'aadha': 0.5,
  'quarter':0.25,
};

class FoodSearchService {
  static String get _usdaKey => dotenv.env['USDA_API_KEY'] ?? '';

  static Future<FoodItem?> lookupBarcode(String barcode) async {
    debugPrint('[FoodSearch] barcode: $barcode');
    String? productName;

    try {
      final uri = Uri.parse(
          'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
          '?fields=product_name,nutriments');
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
      debugPrint('[FoodSearch] OFF: $e');
    }

    if (productName != null) {
      try {
        final usdaR = await _searchUsda(productName, pageSize: 1)
            .timeout(const Duration(seconds: 2));
        if (usdaR.isNotEmpty) {
          debugPrint('[FoodSearch] USDA hit for: $productName');
          return usdaR.first;
        }
      } catch (e) {
        debugPrint('[FoodSearch] USDA: $e');
      }
    }

    debugPrint('[FoodSearch] barcode not found: $barcode');
    return null;
  }

  static Future<List<FoodItem>> searchByBarcode(String barcode) async {
    final food = await lookupBarcode(barcode);
    return food == null ? [] : [food];
  }

  static ParsedCustomMeal? parseCustomMealCommand({
    required String text,
    required List<FoodItem> recents,
    required List<FoodItem> customMeals,
    required List<FoodItem> commonFoods,
  }) {
    final match = RegExp(r'^/custommeal\s+"([^"]+)"\s+(.+)$', caseSensitive: false).firstMatch(text.trim());
    if (match == null) return null;
    
    final name = match.group(1)!;
    final ingredients = match.group(2)!;

    final mealItems = parseNaturalMeal(
      text: ingredients,
      recents: recents,
      customMeals: customMeals,
      commonFoods: commonFoods,
    );

    if (mealItems.isEmpty) return null;

    int cals = 0, pro = 0, carbs = 0, fats = 0;
    for (final m in mealItems) {
      cals += m.food.calories;
      pro += m.food.protein;
      carbs += m.food.carbs;
      fats += m.food.fats;
    }

    final summary = FoodItem(
      id: 'cmd_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      calories: cals,
      protein: pro,
      carbs: carbs,
      fats: fats,
      consumedAmount: 1,
      consumedUnit: 'serving',
      isAiLogged: false, 
    );

    return ParsedCustomMeal(summary, mealItems);
  }

  static Future<FoodSearchResult> logSheetSearch({
    required String query,
    required List<FoodItem> favorites,
    required List<FoodItem> recents,
    required List<FoodItem> customMeals,
    required List<FoodItem> commonFoods,
  }) async {
    if (query.trim().isEmpty) return const FoodSearchResult([], FoodSource.none);

    final expanded = _expandQuery(query);

    // ── Score local sources synchronously ────────────
    final localScored = <_ScoredItem>[];

    void scoreList(List<FoodItem> items, double sourceBias) {
      for (final f in items) {
        final s = _score(expanded, _tokenize(f.name));
        if (s > 0) localScored.add(_ScoredItem(f, s + sourceBias));
      }
    }

    // Small bias so local favorites/recents beat equal-scoring remote results
    scoreList(favorites,   0.15);
    scoreList(recents,     0.10);
    scoreList(customMeals, 0.08);
    scoreList(commonFoods, 0.03);

    // ── Fetch remote sources in parallel ─────────────
    final futures = await Future.wait([
      _safeOff(query),
      _safeUsda(query),
    ]);

    final offR  = futures[0];
    final usdaR = futures[1];

    // Remote items get scored too — no fixed bias
    for (final f in offR) {
      final s = _score(expanded, _tokenize(f.name));
      localScored.add(_ScoredItem(f, s));
    }
    for (final f in usdaR) {
      final s = _score(expanded, _tokenize(f.name));
      localScored.add(_ScoredItem(f, s));
    }

    // ── Global sort by score descending ──────────────
    localScored.sort((a, b) => b.score.compareTo(a.score));

    // ── Deduplicate by name, cap at 15 ───────────────
    final seen = <String>{};
    final merged = <FoodItem>[];

    for (final si in localScored) {
      final key = si.food.name.toLowerCase().trim();
      if (!seen.contains(key)) {
        seen.add(key);
        merged.add(si.food);
        if (merged.length >= 15) break;
      }
    }
    return FoodSearchResult(merged, FoodSource.none);
  }

  static List<MealItem> parseNaturalMeal({
    required String text,
    required List<FoodItem> recents,
    required List<FoodItem> customMeals,
    required List<FoodItem> commonFoods,
  }) {
    final all = [...recents, ...customMeals, ...commonFoods];
    if (all.isEmpty || text.trim().isEmpty) return [];

    // Replace commas with ' and ' so the token segmenter splits correctly
    final rawText = text.toLowerCase().replaceAll(',', ' and ').replaceAll('.', ' ');
    final rawTokens = rawText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final tokens = <String>[];
    for (final raw in rawTokens) {
      final attached = RegExp(
          r'^(\d+(?:\.\d+)?)(ml|l|g|kg|tbsp|tsp|scoop|slice|bar|bowl|cup|katori|glass|piece|serving)$',
          caseSensitive: false,
      ).firstMatch(raw);
      if (attached != null) {
        tokens.add(attached.group(1)!);
        tokens.add(attached.group(2)!.toLowerCase());
      } else {
        tokens.add(_plurals[raw] ?? raw);
      }
    }

    const conjunctions = {'and', 'with', 'aur', 'ke', 'plus', 'or', 'n'};
    final segments = <List<String>>[];
    var current = <String>[];
    for (final tok in tokens) {
      if (conjunctions.contains(tok)) {
        if (current.isNotEmpty) segments.add(current);
        current = [];
      } else {
        current.add(tok);
      }
    }
    if (current.isNotEmpty) segments.add(current);

    final results = <MealItem>[];
    final seen = <String>{};

    for (final seg in segments) {
      if (seg.isEmpty) continue;

      double qty = 1;
      String? detectedUnit;
      final foodTokens = <String>[];

      const unitWords = {
        'ml', 'l', 'g', 'kg',
        'tbsp', 'tsp', 'scoop', 'slice', 'bar',
        'bowl', 'plate', 'cup', 'katori', 'glass',
        'piece', 'serving',
      };

      for (final tok in seg) {
        final num = double.tryParse(tok);
        if (num != null) {
          qty = num;
          continue;
        }
        final wordNum = _wordNumbers[tok];
        if (wordNum != null) {
          qty = wordNum;
          continue;
        }
        if (unitWords.contains(tok)) {
          detectedUnit ??= tok;
          continue;
        }
        foodTokens.add(tok);
      }

      if (foodTokens.isEmpty) continue;

      final expanded = _expandQueryFromTokens(foodTokens);
      final match = _fuzzyMatchList(expanded, all);
      
      if (match != null && !seen.contains(match.id)) {
        seen.add(match.id);

        final finalUnit = detectedUnit ?? match.consumedUnit;
        FoodItem result = match.copyWith(consumedAmount: qty, consumedUnit: finalUnit);
        
        if (detectedUnit != null &&
            const {'g', 'kg', 'ml', 'l'}.contains(detectedUnit) &&
            const {'g', 'kg', 'ml', 'l'}.contains(match.consumedUnit)) {
          final baseAmt = match.consumedAmount == 0 ? 1.0 : match.consumedAmount;
          double inBaseUnits = qty;
          
          if (detectedUnit == 'kg' && match.consumedUnit == 'g') inBaseUnits = qty * 1000;
          if (detectedUnit == 'l'  && match.consumedUnit == 'ml') inBaseUnits = qty * 1000;
          if (detectedUnit == 'g'  && match.consumedUnit == 'kg') inBaseUnits = qty / 1000;
          if (detectedUnit == 'ml' && match.consumedUnit == 'l')  inBaseUnits = qty / 1000;
          
          result = match.scaleToAmount(inBaseUnits / baseAmt * match.consumedAmount)
              .copyWith(consumedAmount: qty, consumedUnit: finalUnit);
        }

        results.add(MealItem(result, qty));
      }
    }

    return results;
  }

  static List<String> _expandQueryFromTokens(List<String> tokens) {
    final extra = <String>[];
    for (final tok in tokens) {
      final mapped = _aliases[tok];
      if (mapped != null) extra.addAll(mapped);
    }
    return {...tokens, ...extra}.toList();
  }

  static FoodItem? _fuzzyMatchList(List<String> qTokens, List<FoodItem> list) {
    if (qTokens.isEmpty || list.isEmpty) return null;
    FoodItem? best; double bestScore = 0;
    for (final f in list) {
      final s = _score(qTokens, _tokenize(f.name));
      if (s >= 0.30 && s > bestScore) { bestScore = s; best = f; }
    }
    return best;
  }

  static Future<FoodSearchResult> smartLoggerSearch({
    required String query,
    required List<FoodItem> recents,
    required List<FoodItem> customMeals,
    required List<FoodItem> commonFoods,
  }) async {
    final expanded = _expandQuery(query);

    final exactR = _exactMatch(expanded, recents);
    if (exactR != null) return FoodSearchResult([exactR], FoodSource.recents);

    final fuzzyR = _fuzzyMatch(expanded, recents);
    if (fuzzyR != null) return FoodSearchResult([fuzzyR], FoodSource.recents);

    final cusR = _fuzzyMatch(expanded, customMeals);
    if (cusR != null) return FoodSearchResult([cusR], FoodSource.custom);

    final comR = _fuzzyList(expanded, commonFoods, threshold: 0.3);
    if (comR.isNotEmpty) return FoodSearchResult(comR, FoodSource.commonDb);

    return const FoodSearchResult([], FoodSource.none);
  }

  static Future<List<FoodItem>> loadCommonFoods() async {
    try {
      final commonStr = await rootBundle.loadString('assets/common_foods.json');
      final brandStr  = await rootBundle.loadString('assets/brands_india.json');

      final List commonData = jsonDecode(commonStr);
      final List brandData  = jsonDecode(brandStr);

      final merged = [...commonData, ...brandData];

      return merged.map((item) => FoodItem(
        id:                 item['id'],
        name:               item['name'],
        calories:           item['calories'],
        protein:            item['protein'],
        carbs:              item['carbs'],
        fats:               item['fats'],
        consumedAmount:     (item['consumedAmount'] ?? 1).toDouble(),
        consumedUnit:       item['consumedUnit'] ?? 'serving',
        servingWeightGrams: item['servingWeightGrams'] != null ? (item['servingWeightGrams'] as num).toDouble() : null,
        totalServings:      item['totalServings'] != null ? (item['totalServings'] as num).toInt() : null,
        servingDescription: item['servingDescription'] as String?,
      )).toList();
    } catch (e) {
      debugPrint('[FoodSearch] loadCommonFoods: $e');
      return [];
    }
  }

  static Future<List<FoodItem>> _safeOff(String query) async {
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query)}'
        '&search_simple=1&action=process&json=1&page_size=8'
        '&fields=product_name,nutriments',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': 'FitMe/1.0'})
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body);
      final products = (data['products'] as List? ?? []);
      final results = <FoodItem>[];
      for (final p in products) {
        final name = (p['product_name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        final n = (p['nutriments'] as Map?) ?? {};
        final cal = _nMap(n, ['energy-kcal_100g', 'energy_100g']);
        if (cal == 0) continue;
        results.add(FoodItem(
          id: 'off_${name.toLowerCase().replaceAll(' ', '_')}',
          name: _capitalize(name),
          calories: cal,
          protein: _nMap(n, ['proteins_100g']),
          carbs:   _nMap(n, ['carbohydrates_100g']),
          fats:    _nMap(n, ['fat_100g']),
          consumedAmount: 100,
          consumedUnit: 'g',
        ));
        if (results.length >= 8) break;
      }
      debugPrint('[FoodSearch] OFF text: ${results.length} results for "$query"');
      return results;
    } catch (e) {
      debugPrint('[FoodSearch] OFF text silent: $e');
      return [];
    }
  }

  static Future<List<FoodItem>> _safeUsda(String query) async {
    try {
      return await _searchUsda(query);
    } catch (e) {
      debugPrint('[FoodSearch] USDA silent: $e');
      return [];
    }
  }

  static Future<List<FoodItem>> _searchUsda(String query,
      {int pageSize = 8}) async {
    if (_usdaKey.isEmpty) return [];
    final uri = Uri.parse(
        'https://api.nal.usda.gov/fdc/v1/foods/search'
        '?query=${Uri.encodeComponent(query)}&pageSize=$pageSize&api_key=$_usdaKey');
    final resp = await http.get(uri).timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) return [];
    final data  = jsonDecode(resp.body);
    final foods = (data['foods'] as List? ?? []);
    return foods.map((f) {
      final nutrients = (f['foodNutrients'] as List? ?? []);
      int n(int id) => ((nutrients.firstWhere(
              (x) => x['nutrientId'] == id,
              orElse: () => {'value': 0})['value'] ?? 0) as num).round();
      return FoodItem(
        id: 'usda_${f['fdcId']}',
        name: f['description'] ?? 'Unknown',
        calories: n(1008), protein: n(1003), carbs: n(1005), fats: n(1004),
        consumedAmount: 100, consumedUnit: 'g',
      );
    }).where((f) => f.calories > 0).take(8).toList();
  }

  static Future<List<FoodItem>> _safeGemini(String query) async {
    try {
      return await GeminiService.parseFood(query)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[FoodSearch] Gemini silent: $e');
      return [];
    }
  }

  static List<String> _expandQuery(String query) {
    final base  = _tokenize(query);
    final extra = <String>[];
    final lower = query.trim().toLowerCase();

    _aliases.forEach((alias, replacements) {
      if (lower.contains(alias)) extra.addAll(replacements);
    });
    for (final token in base) {
      final mapped = _aliases[token];
      if (mapped != null) extra.addAll(mapped);
    }
    return {...base, ...extra}.toList();
  }

  static FoodItem? _exactMatch(List<String> qTokens, List<FoodItem> list) {
    final q = qTokens.join(' ');
    for (final f in list) {
      if (f.name.toLowerCase().trim() == q) return f;
    }
    return null;
  }

  static FoodItem? _fuzzyMatch(List<String> qTokens, List<FoodItem> list) {
    if (qTokens.isEmpty) return null;
    FoodItem? best; double bestScore = 0;
    for (final f in list) {
      final s = _score(qTokens, _tokenize(f.name));
      if (s >= 0.35 && s > bestScore) { bestScore = s; best = f; }
    }
    return best;
  }

  static List<FoodItem> _fuzzyList(List<String> qTokens, List<FoodItem> list,
      {double threshold = 0.35}) {
    if (qTokens.isEmpty) return [];
    final results = <MapEntry<FoodItem, double>>[];
    final joined = qTokens.join(' ');
    for (final f in list) {
      double s = _score(qTokens, _tokenize(f.name));
      if (f.name.toLowerCase().contains(joined)) {
        s += 0.15;
      }
      if (s >= threshold) results.add(MapEntry(f, s));
    }
    results.sort((a, b) => b.value.compareTo(a.value));
    return results.map((e) => e.key).take(10).toList();
  }

  static double _score(List<String> qTokens, List<String> fTokens) {
    if (qTokens.isEmpty || fTokens.isEmpty) return 0;
    int fHits = 0;
    for (final fw in fTokens) {
      if (qTokens.any((qw) =>
          qw == fw ||
          fw.contains(qw) ||
          qw.contains(fw) ||
          _levenshtein(qw, fw) <= 1)) {
        fHits++;
      }
    }
    final fScore = fHits / fTokens.length;

    int qHits = 0;
    for (final qw in qTokens) {
      if (fTokens.any((fw) =>
          qw == fw ||
          fw.contains(qw) ||
          qw.contains(fw) ||
          _levenshtein(qw, fw) <= 1)) {
        qHits++;
      }
    }
    final qScore = qHits / qTokens.length;
    return fScore * 0.65 + qScore * 0.35;
  }

  static const _stopwords = {
    'and', 'with', 'some', 'the', 'a', 'an', 'of', 'in', 'on', 'for',
    'or', 'to', 'at', 'by', 'is', 'it', 'my', 'had', 'have', 'ate',
    'eat', 'just', 'little', 'bit', 'small', 'large', 'big', 'one',
    'two', 'three', 'four', 'five', 'six', 'pieces', 'piece',
  };

  static List<String> _tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[\s,/\-]+'))
      .where((w) => w.length > 1 && !_stopwords.contains(w))
      .toList();

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if ((a.length - b.length).abs() > 2) return 99;
    final dp = List.generate(
        a.length + 1, (i) => List.generate(b.length + 1, (j) => 0));
    for (int i = 0; i <= a.length; i++) dp[i][0] = i;
    for (int j = 0; j <= b.length; j++) dp[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + [dp[i-1][j], dp[i][j-1], dp[i-1][j-1]].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }

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
// Add this at the bottom of food_search_service.dart, outside FoodSearchService class

class _ScoredItem {
  final FoodItem food;
  final double score;
  const _ScoredItem(this.food, this.score);
}