import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/food_item.dart';
import '../models/parsed_meal.dart';
import 'food_search_service.dart' show FoodSource;
import 'gemini_service.dart';

// ── Alias / synonym map ────────────────────────────────────────────────────
const Map<String, List<String>> _aliases = {
  'chapati': ['roti'], 'chapatti': ['roti'], 'phulka': ['roti'],
  'naan': ['roti'], 'daal': ['dal'], 'lentil': ['dal'], 'lentils': ['dal'],
  'makhani': ['dal', 'butter'], 'tadka': ['dal'], 'moong': ['dal', 'moong'],
  'chana': ['dal', 'chana'], 'toor': ['dal'], 'arhar': ['dal'],
  'masoor': ['dal'], 'chawal': ['rice'], 'biryani': ['chicken', 'biryani'],
  'pulao': ['rice'], 'khichri': ['khichdi'], 'murgh': ['chicken'],
  'grilled chicken': ['chicken', 'breast'], 'boneless': ['chicken', 'breast'],
  'cottage cheese': ['paneer'], 'shahi paneer': ['paneer', 'butter', 'masala'],
  'chai': ['tea'], 'doodh': ['milk'], 'buttermilk': ['chaas'],
  'sabji': ['sabzi'], 'bhaji': ['sabzi'], 'aloo': ['potato'],
  'gobi': ['cauliflower'], 'dahi': ['curd'], 'chole': ['chana', 'chole'],
  'rajma': ['rajma'], 'poori': ['puri'], 'besan': ['chana', 'dal'],
  'anda': ['egg'], 'matar': ['peas'], 'gobhi': ['cauliflower'],
  'lauki': ['gourd'], 'bhindi': ['okra'], 'baingan': ['eggplant'],
  'methi': ['fenugreek'], 'palak': ['spinach'],
  // Branded
  'diet coke': ['coca-cola', 'zero', 'diet'],
  'coke zero': ['coca-cola', 'zero'],
  'pepsi': ['pepsi', 'cola'],
  'fairlife': ['fairlife', 'milk', 'protein'],
};

// ── Plural normalization ───────────────────────────────────────────────────
const Map<String, String> _plurals = {
  'rotis': 'roti', 'chapatis': 'chapati', 'parathas': 'paratha',
  'puris': 'puri', 'idlis': 'idli', 'dosas': 'dosa', 'eggs': 'egg',
  'pieces': 'piece', 'slices': 'slice', 'bananas': 'banana',
  'apples': 'apple', 'samosas': 'samosa', 'bowls': 'bowl',
  'plates': 'plate', 'cups': 'cup', 'katoris': 'katori',
  'scoops': 'scoop', 'bars': 'bar', 'tbsps': 'tbsp',
  'tablespoon': 'tbsp', 'tablespoons': 'tbsp',
  'teaspoon': 'tsp', 'teaspoons': 'tsp', 'tsps': 'tsp',
  'grams': 'g', 'gram': 'g', 'kilograms': 'kg', 'kilogram': 'kg',
  'milliliters': 'ml', 'millilitres': 'ml', 'liters': 'l', 'litres': 'l',
  'glasses': 'glass',
};

// ── Word numbers ───────────────────────────────────────────────────────────
const Map<String, double> _wordNumbers = {
  'one': 1, 'ek': 1, 'two': 2, 'do': 2, 'three': 3, 'teen': 3,
  'four': 4, 'char': 4, 'five': 5, 'paanch': 5, 'six': 6,
  'seven': 7, 'saat': 7, 'eight': 8, 'aath': 8,
  'half': 0.5, 'aadha': 0.5, 'quarter': 0.25,
};

const Set<String> _unitWords = {
  'ml', 'l', 'g', 'kg', 'tbsp', 'tsp', 'scoop', 'slice', 'bar',
  'bowl', 'plate', 'cup', 'katori', 'glass', 'piece', 'serving',
};

const Set<String> _conjunctions = {
  'and', 'with', 'aur', 'ke', 'plus', 'or', 'n',
};

const Set<String> _stopwords = {
  'and', 'with', 'some', 'the', 'a', 'an', 'of', 'in', 'on', 'for',
  'or', 'to', 'at', 'by', 'is', 'it', 'my', 'had', 'have', 'ate',
  'eat', 'just', 'little', 'bit', 'small', 'large', 'big',
};

// ── Cancellation token ─────────────────────────────────────────────────────
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

// ── Result from a remote lookup ────────────────────────────────────────────
class _RemoteResult {
  final FoodItem food;
  final FoodSource source;
  const _RemoteResult(this.food, this.source);
}

// ═══════════════════════════════════════════════════════════════════════════
// FOOD KNOWLEDGE RESOLVER
// Single entry point for ALL food resolution in the app.
// ═══════════════════════════════════════════════════════════════════════════
class FoodKnowledgeResolver {
  static String get _usdaKey => dotenv.env['USDA_API_KEY'] ?? '';

  // ── Local food database (loaded once) ────────────────────────────────────
  static List<FoodItem>? _cachedCommonFoods;

  static Future<List<FoodItem>> loadCommonFoods() async {
    if (_cachedCommonFoods != null) return _cachedCommonFoods!;
    try {
      final commonStr = await rootBundle.loadString('assets/common_foods.json');
      final brandStr  = await rootBundle.loadString('assets/brands_india.json');
      final merged = [...jsonDecode(commonStr) as List, ...jsonDecode(brandStr) as List];
      _cachedCommonFoods = merged.map((item) => FoodItem(
        id: item['id'],
        name: item['name'],
        calories: item['calories'],
        protein: item['protein'],
        carbs: item['carbs'],
        fats: item['fats'],
        consumedAmount: (item['consumedAmount'] ?? 1).toDouble(),
        consumedUnit: item['consumedUnit'] ?? 'serving',
        servingWeightGrams: item['servingWeightGrams'] != null
            ? (item['servingWeightGrams'] as num).toDouble() : null,
        totalServings: item['totalServings'] != null
            ? (item['totalServings'] as num).toInt() : null,
        servingDescription: item['servingDescription'] as String?,
      )).toList();
      return _cachedCommonFoods!;
    } catch (e) {
      dev.log('[FKR] loadCommonFoods error: $e', name: 'FKR');
      return [];
    }
  }

  // ── Main entry point: parse a natural language meal description ───────────
  static Future<ParsedMeal> parseMeal({
    required String input,
    required List<FoodItem> customs,
    required List<FoodItem> commonFoods,
    required List<FoodItem> recents,
    CancelToken? cancel,
    bool allowAi = true, // false for guests
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return ParsedMeal.empty(trimmed);

    final segments = _tokenizeIntoSegments(trimmed);
    dev.log('[FKR] segments: ${segments.map((s) => s.join(' ')).toList()}', name: 'FKR');

    // Step 1: resolve each segment against local DB (synchronous, fast)
    final local = _resolveLocally(segments, customs, commonFoods, recents);
    dev.log('[FKR] local resolved: ${local.where((s) => s.isResolved).length}/${local.length}', name: 'FKR');

    if (cancel?.isCancelled == true) return ParsedMeal.empty(trimmed);

    // Step 2: gather unresolved names for remote parallel lookup
    final unresolved = local.where((s) => !s.isResolved).toList();
    List<ParsedMealSegment> finalSegments = List.from(local);

    if (unresolved.isNotEmpty) {
      final remoteMap = await _resolveRemoteParallel(
        unresolved.map((s) => s.rawInput).toList(),
        cancel: cancel,
      );

      for (int i = 0; i < finalSegments.length; i++) {
        final seg = finalSegments[i];
        if (!seg.isResolved && remoteMap.containsKey(seg.rawInput)) {
          final remote = remoteMap[seg.rawInput]!;
          final scaled = _scaleFood(remote.food, seg.quantity, seg.unit);
          finalSegments[i] = seg.copyWith(
            resolvedFood: scaled,
            source: remote.source,
            confidence: 0.75,
          );
        }
      }
    }

    if (cancel?.isCancelled == true) return ParsedMeal.empty(trimmed);

    // Step 3: mark remaining as requiresAi
    for (int i = 0; i < finalSegments.length; i++) {
      final seg = finalSegments[i];
      if (!seg.isResolved) {
        finalSegments[i] = seg.copyWith(requiresAi: true);
        dev.log('[FKR] unresolved (needs AI): "${seg.rawInput}"', name: 'FKR');
      }
    }

    return ParsedMeal(
      rawInput: trimmed,
      segments: finalSegments,
      parsedAt: DateTime.now(),
    );
  }

  // ── Unified search (used by both Smart Logger search bar and Log Sheet) ───
  static Future<List<FoodItem>> search({
    required String query,
    required List<FoodItem> customs,
    required List<FoodItem> commonFoods,
    required List<FoodItem> recents,
    required List<FoodItem> favorites,
    CancelToken? cancel,
  }) async {
    if (query.trim().isEmpty) return [];

    final expanded = _expandQuery(query);

    // Score all local sources simultaneously
    final scored = <_ScoredItem>[];

    void scoreList(List<FoodItem> items, double bias) {
      for (final f in items) {
        final s = _score(expanded, _tokenize(f.name));
        if (s > 0) scored.add(_ScoredItem(f, s + bias));
      }
    }

    scoreList(favorites,   0.15);
    scoreList(recents,     0.08); // demoted from 0.10
    scoreList(customs,     0.08);
    scoreList(commonFoods, 0.03);

    if (cancel?.isCancelled == true) return [];

    // Remote in parallel
    final futures = await Future.wait([
      _safeOff(query, cancel: cancel),
      _safeUsda(query, cancel: cancel),
    ]);

    for (final f in [...futures[0], ...futures[1]]) {
      final s = _score(expanded, _tokenize(f.name));
      if (s > 0) scored.add(_ScoredItem(f, s));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    final seen = <String>{};
    final results = <FoodItem>[];
    for (final si in scored) {
      final key = si.food.name.toLowerCase().trim();
      if (!seen.contains(key)) {
        seen.add(key);
        results.add(si.food);
        if (results.length >= 20) break;
      }
    }
    return results;
  }

  // ── Tokenize input into per-food segments ─────────────────────────────────
  static List<List<String>> _tokenizeIntoSegments(String text) {
    final rawText = text.toLowerCase()
        .replaceAll(',', ' and ')
        .replaceAll('.', ' ');

    final rawTokens = rawText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Split attached qty+unit (e.g. "50g" → ["50", "g"])
    final tokens = <String>[];
    for (final raw in rawTokens) {
      final m = RegExp(
        r'^(\d+(?:\.\d+)?)(ml|l|g|kg|tbsp|tsp|scoop|slice|bar|bowl|cup|katori|glass|piece|serving)$',
        caseSensitive: false,
      ).firstMatch(raw);
      if (m != null) {
        tokens.add(m.group(1)!);
        tokens.add(m.group(2)!.toLowerCase());
      } else {
        tokens.add(_plurals[raw] ?? raw);
      }
    }

    // Split on conjunctions into segments
    final segments = <List<String>>[];
    var current = <String>[];
    for (final tok in tokens) {
      if (_conjunctions.contains(tok)) {
        if (current.isNotEmpty) segments.add(current);
        current = [];
      } else {
        current.add(tok);
      }
    }
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }

  // ── Resolve each segment against local DB ────────────────────────────────
  static List<ParsedMealSegment> _resolveLocally(
    List<List<String>> segments,
    List<FoodItem> customs,
    List<FoodItem> commonFoods,
    List<FoodItem> recents,
  ) {
    // Recents get a tiny bias — but we score all local sources together
    final allLocal = [...customs, ...commonFoods];
    final recentSet = {for (final r in recents) r.id: r};

    final results = <ParsedMealSegment>[];
    final seen = <String>{};

    for (final seg in segments) {
      if (seg.isEmpty) continue;

      double qty = 1.0;
      String? unit;
      final foodTokens = <String>[];

      for (final tok in seg) {
        final num = double.tryParse(tok);
        if (num != null) { qty = num; continue; }
        final wordNum = _wordNumbers[tok];
        if (wordNum != null) { qty = wordNum; continue; }
        if (_unitWords.contains(tok)) { unit ??= tok; continue; }
        foodTokens.add(tok);
      }

      if (foodTokens.isEmpty) continue;
      final rawInput = seg.join(' ');
      final expanded = _expandQueryFromTokens(foodTokens);

      // Score against local
      _ScoredItem? best;
      for (final f in allLocal) {
        double s = _score(expanded, _tokenize(f.name));
        // tiny recents boost
        if (recentSet.containsKey(f.id)) s += 0.08;
        if (s >= 0.35 && (best == null || s > best.score)) {
          best = _ScoredItem(f, s);
        }
      }

      dev.log('[FKR] "$rawInput" → local best: ${best?.food.name} (${best?.score.toStringAsFixed(2)})', name: 'FKR');

      if (best != null && !seen.contains(best.food.id)) {
        seen.add(best.food.id);
        final finalUnit = unit ?? best.food.consumedUnit;
        final scaled = _scaleFood(best.food, qty, finalUnit);
        results.add(ParsedMealSegment(
          rawInput: rawInput,
          resolvedFood: scaled,
          quantity: qty,
          unit: finalUnit,
          source: recentSet.containsKey(best.food.id) ? FoodSource.recents : FoodSource.commonDb,
          confidence: best.score.clamp(0.0, 1.0),
        ));
      } else {
        // Not found locally — mark for remote lookup
        results.add(ParsedMealSegment(
          rawInput: rawInput,
          quantity: qty,
          unit: unit ?? 'serving',
        ));
      }
    }
    return results;
  }

  // ── Remote parallel lookup (OFF + USDA) ──────────────────────────────────
  static Future<Map<String, _RemoteResult>> _resolveRemoteParallel(
    List<String> names, {
    CancelToken? cancel,
  }) async {
    final resultMap = <String, _RemoteResult>{};
    if (names.isEmpty) return resultMap;

    await Future.wait(names.map((name) async {
      if (cancel?.isCancelled == true) return;
      try {
        final results = await Future.wait([
          _safeOff(name, cancel: cancel),
          _safeUsda(name, cancel: cancel),
        ]).timeout(const Duration(seconds: 3));

        if (cancel?.isCancelled == true) return;

        final expanded = _expandQuery(name);
        _ScoredItem? best;
        FoodSource bestSource = FoodSource.none;

        for (final f in results[0]) {
          final s = _score(expanded, _tokenize(f.name));
          if (s > (best?.score ?? 0)) { best = _ScoredItem(f, s); bestSource = FoodSource.off; }
        }
        for (final f in results[1]) {
          final s = _score(expanded, _tokenize(f.name));
          if (s > (best?.score ?? 0)) { best = _ScoredItem(f, s); bestSource = FoodSource.usda; }
        }

        if (best != null) {
          dev.log('[FKR] remote "$name" → ${best.food.name} via $bestSource (${best.score.toStringAsFixed(2)})', name: 'FKR');
          resultMap[name] = _RemoteResult(best.food, bestSource);
        }
      } catch (e) {
        dev.log('[FKR] remote "$name" error: $e', name: 'FKR');
      }
    }));

    return resultMap;
  }

  // ── Gemini resolution (called by Smart Logger only, auth users only) ─────
  static Future<List<FoodItem>> resolveWithAi(String input) =>
      GeminiService.parseFoodSafe(input);

  // ── OFF search ────────────────────────────────────────────────────────────
  static Future<List<FoodItem>> _safeOff(String query, {CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) return [];
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query)}'
        '&search_simple=1&action=process&json=1&page_size=6'
        '&fields=product_name,nutriments',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': 'FitMe/1.0'})
          .timeout(const Duration(seconds: 3));
      if (cancel?.isCancelled == true) return [];
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body);
      final products = (data['products'] as List? ?? []);
      final results = <FoodItem>[];
      for (final p in products) {
        if (cancel?.isCancelled == true) break;
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
          carbs: _nMap(n, ['carbohydrates_100g']),
          fats: _nMap(n, ['fat_100g']),
          consumedAmount: 100,
          consumedUnit: 'g',
        ));
        if (results.length >= 6) break;
      }
      dev.log('[FKR] OFF "$query": ${results.length} results', name: 'FKR');
      return results;
    } catch (e) {
      dev.log('[FKR] OFF error for "$query": $e', name: 'FKR');
      return [];
    }
  }

  // ── USDA search ───────────────────────────────────────────────────────────
  static Future<List<FoodItem>> _safeUsda(String query, {CancelToken? cancel}) async {
    if (cancel?.isCancelled == true || _usdaKey.isEmpty) return [];
    try {
      final uri = Uri.parse(
          'https://api.nal.usda.gov/fdc/v1/foods/search'
          '?query=${Uri.encodeComponent(query)}&pageSize=6&api_key=$_usdaKey');
      final resp = await http.get(uri).timeout(const Duration(seconds: 3));
      if (cancel?.isCancelled == true) return [];
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body);
      final foods = (data['foods'] as List? ?? []);
      return foods.map((f) {
        final nutrients = (f['foodNutrients'] as List? ?? []);
        int n(int id) => ((nutrients.firstWhere(
            (x) => x['nutrientId'] == id, orElse: () => {'value': 0})['value'] ?? 0) as num).round();
        return FoodItem(
          id: 'usda_${f['fdcId']}',
          name: f['description'] ?? 'Unknown',
          calories: n(1008), protein: n(1003), carbs: n(1005), fats: n(1004),
          consumedAmount: 100, consumedUnit: 'g',
        );
      }).where((f) => f.calories > 0).take(6).toList();
    } catch (e) {
      dev.log('[FKR] USDA error for "$query": $e', name: 'FKR');
      return [];
    }
  }

  // ── Food scaling ──────────────────────────────────────────────────────────
  static FoodItem _scaleFood(FoodItem food, double qty, String? unit) {
    final finalUnit = unit ?? food.consumedUnit;
    if (unit != null &&
        const {'g', 'kg', 'ml', 'l'}.contains(unit) &&
        const {'g', 'kg', 'ml', 'l'}.contains(food.consumedUnit)) {
      double inBase = qty;
      if (unit == 'kg' && food.consumedUnit == 'g') inBase = qty * 1000;
      if (unit == 'l' && food.consumedUnit == 'ml') inBase = qty * 1000;
      if (unit == 'g' && food.consumedUnit == 'kg') inBase = qty / 1000;
      if (unit == 'ml' && food.consumedUnit == 'l') inBase = qty / 1000;
      final baseAmt = food.consumedAmount == 0 ? 1.0 : food.consumedAmount;
      return food
          .scaleToAmount(inBase / baseAmt * food.consumedAmount)
          .copyWith(consumedAmount: qty, consumedUnit: finalUnit);
    }
    return food.copyWith(consumedAmount: qty, consumedUnit: finalUnit);
  }

  // ── Scoring helpers ───────────────────────────────────────────────────────
  static List<String> _expandQuery(String query) {
    final base = _tokenize(query);
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

  static List<String> _expandQueryFromTokens(List<String> tokens) {
    final extra = <String>[];
    for (final tok in tokens) {
      final mapped = _aliases[tok];
      if (mapped != null) extra.addAll(mapped);
    }
    return {...tokens, ...extra}.toList();
  }

  static List<String> _tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[\s,/\-]+'))
      .where((w) => w.length > 1 && !_stopwords.contains(w))
      .toList();

  static double _score(List<String> qTokens, List<String> fTokens) {
    if (qTokens.isEmpty || fTokens.isEmpty) return 0;
    int fHits = 0;
    for (final fw in fTokens) {
      if (qTokens.any((qw) => qw == fw || fw.contains(qw) || qw.contains(fw) || _lev(qw, fw) <= 1)) fHits++;
    }
    int qHits = 0;
    for (final qw in qTokens) {
      if (fTokens.any((fw) => qw == fw || fw.contains(qw) || qw.contains(fw) || _lev(qw, fw) <= 1)) qHits++;
    }
    return (fHits / fTokens.length) * 0.65 + (qHits / qTokens.length) * 0.35;
  }

  static int _lev(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if ((a.length - b.length).abs() > 2) return 99;
    final dp = List.generate(a.length + 1, (i) => List.generate(b.length + 1, (j) => 0));
    for (int i = 0; i <= a.length; i++) dp[i][0] = i;
    for (int j = 0; j <= b.length; j++) dp[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        dp[i][j] = a[i-1] == b[j-1] ? dp[i-1][j-1]
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

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _ScoredItem {
  final FoodItem food;
  final double score;
  const _ScoredItem(this.food, this.score);
}
