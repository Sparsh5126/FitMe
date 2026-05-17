import 'package:flutter/foundation.dart';
import 'package:fitme/features/nutrition/models/food_item.dart';
import 'package:fitme/features/nutrition/models/custom_meal_ingredient.dart';
import 'package:fitme/features/nutrition/services/food_search_service.dart'
    show FoodSource;

// ── Source of a resolved food item ─────────────────────────────────────────
// Re-exported from FoodSource for convenience.
export '../../nutrition/services/food_search_service.dart' show FoodSource;

// ── A single food segment resolved from user input ─────────────────────────
@immutable
class ParsedMealSegment {
  /// The raw text token(s) that produced this segment (e.g. "50g oats").
  final String rawInput;

  /// Null if the segment could not be resolved.
  final FoodItem? resolvedFood;

  /// Parsed quantity from user input (default 1).
  final double quantity;

  /// Parsed unit from user input (e.g. "g", "ml", "serving").
  final String unit;

  /// Where the result came from.
  final FoodSource source;

  /// 0.0–1.0. Low confidence = show alternatives.
  final double confidence;

  /// True when no local/remote match was found and only Gemini can help.
  final bool requiresAi;

  /// Up to 3 close alternatives the user can swap to.
  final List<FoodItem> alternatives;

  const ParsedMealSegment({
    required this.rawInput,
    this.resolvedFood,
    this.quantity = 1.0,
    this.unit = 'serving',
    this.source = FoodSource.none,
    this.confidence = 0.0,
    this.requiresAi = false,
    this.alternatives = const [],
  });

  bool get isResolved => resolvedFood != null;

  ParsedMealSegment copyWith({
    String? rawInput,
    FoodItem? resolvedFood,
    double? quantity,
    String? unit,
    FoodSource? source,
    double? confidence,
    bool? requiresAi,
    List<FoodItem>? alternatives,
  }) {
    return ParsedMealSegment(
      rawInput: rawInput ?? this.rawInput,
      resolvedFood: resolvedFood ?? this.resolvedFood,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      requiresAi: requiresAi ?? this.requiresAi,
      alternatives: alternatives ?? this.alternatives,
    );
  }

  Map<String, dynamic> toMap() => {
    'rawInput': rawInput,
    'resolvedFood': resolvedFood?.toMap(),
    'quantity': quantity,
    'unit': unit,
    'source': source.name,
    'confidence': confidence,
    'requiresAi': requiresAi,
    'alternatives': alternatives.map((f) => f.toMap()).toList(),
  };

  factory ParsedMealSegment.fromMap(Map<String, dynamic> m) =>
      ParsedMealSegment(
        rawInput: m['rawInput'] as String? ?? '',
        resolvedFood: m['resolvedFood'] != null
            ? FoodItem.fromMap(Map<String, dynamic>.from(m['resolvedFood']))
            : null,
        quantity: (m['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: m['unit'] as String? ?? 'serving',
        source: FoodSource.values.firstWhere(
          (s) => s.name == m['source'],
          orElse: () => FoodSource.none,
        ),
        confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
        requiresAi: m['requiresAi'] as bool? ?? false,
        alternatives:
            (m['alternatives'] as List?)
                ?.map((x) => FoodItem.fromMap(Map<String, dynamic>.from(x)))
                .toList() ??
            [],
      );

  /// Returns a [CustomMealIngredient] for use in custom meal creation.
  CustomMealIngredient? toIngredient() {
    final food = resolvedFood;
    if (food == null) return null;
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
}

// ── A complete parsed meal containing one or more segments ─────────────────
@immutable
class ParsedMeal {
  final String rawInput;
  final List<ParsedMealSegment> segments;
  final DateTime parsedAt;

  const ParsedMeal({
    required this.rawInput,
    required this.segments,
    required this.parsedAt,
  });

  // ── Convenience getters ───────────────────────────────────────────────────

  List<FoodItem> get resolvedFoods =>
      segments.where((s) => s.isResolved).map((s) => s.resolvedFood!).toList();

  bool get hasUnresolved => segments.any((s) => !s.isResolved);

  /// True if any segment needs Gemini (and guests therefore see a lock).
  bool get requiresAi => segments.any((s) => s.requiresAi);

  bool get isEmpty => segments.isEmpty;

  // ── Custom meal helpers ───────────────────────────────────────────────────

  /// Combined totals across all resolved segments.
  ({int calories, int protein, int carbs, int fats}) get totals {
    int cal = 0, pro = 0, carb = 0, fat = 0;
    for (final s in segments) {
      final f = s.resolvedFood;
      if (f != null) {
        cal += f.calories;
        pro += f.protein;
        carb += f.carbs;
        fat += f.fats;
      }
    }
    return (calories: cal, protein: pro, carbs: carb, fats: fat);
  }

  /// Build a single [FoodItem] summary suitable for logging a custom meal.
  FoodItem toCustomMealSummary(String name) {
    final t = totals;
    return FoodItem(
      id: 'cm_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      calories: t.calories,
      protein: t.protein,
      carbs: t.carbs,
      fats: t.fats,
      consumedAmount: 1,
      consumedUnit: 'serving',
      isAiLogged: segments.any((s) => s.source == FoodSource.gemini),
    );
  }

  /// All resolved segments as [CustomMealIngredient] list.
  List<CustomMealIngredient> toIngredients() => segments
      .map((s) => s.toIngredient())
      .whereType<CustomMealIngredient>()
      .toList();

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'rawInput': rawInput,
    'segments': segments.map((s) => s.toMap()).toList(),
    'parsedAt': parsedAt.millisecondsSinceEpoch,
  };

  factory ParsedMeal.fromMap(Map<String, dynamic> m) => ParsedMeal(
    rawInput: m['rawInput'] as String? ?? '',
    segments:
        (m['segments'] as List?)
            ?.map(
              (x) => ParsedMealSegment.fromMap(Map<String, dynamic>.from(x)),
            )
            .toList() ??
        [],
    parsedAt: DateTime.fromMillisecondsSinceEpoch(
      (m['parsedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
    ),
  );

  /// Empty result returned when input is blank.
  factory ParsedMeal.empty(String rawInput) => ParsedMeal(
    rawInput: rawInput,
    segments: const [],
    parsedAt: DateTime.now(),
  );
}
