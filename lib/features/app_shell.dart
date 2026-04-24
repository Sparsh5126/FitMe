class FoodItem {
  final String id;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final double consumedAmount;
  final String consumedUnit;
  final bool isAiLogged;
  final bool isFavorite;
  final String dateString;   // YYYY-MM-DD of when logged
  final int timestamp;

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.consumedAmount = 1,
    this.consumedUnit = 'serving',
    this.isAiLogged = false,
    this.isFavorite = false,
    String? dateString,
    int? timestamp,
  })  : dateString = dateString ?? _today(),
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String dateFor(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Scale macros to a new amount (used in quantity selection)
  FoodItem scaleToAmount(double newAmount) {
    final ratio = newAmount / (consumedAmount == 0 ? 1 : consumedAmount);
    return copyWith(
      calories: (calories * ratio).round(),
      protein: (protein * ratio).round(),
      carbs: (carbs * ratio).round(),
      fats: (fats * ratio).round(),
      consumedAmount: newAmount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'consumedAmount': consumedAmount,
      'consumedUnit': consumedUnit,
      'isAiLogged': isAiLogged,
      'isFavorite': isFavorite,
      'dateString': dateString,
      'timestamp': timestamp,
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      calories: (map['calories'] ?? 0).toInt(),
      protein: (map['protein'] ?? 0).toInt(),
      carbs: (map['carbs'] ?? 0).toInt(),
      fats: (map['fats'] ?? 0).toInt(),
      consumedAmount: (map['consumedAmount'] ?? 1).toDouble(),
      consumedUnit: map['consumedUnit'] ?? 'serving',
      isAiLogged: map['isAiLogged'] ?? false,
      isFavorite: map['isFavorite'] ?? false,
      dateString: map['dateString'] ?? _today(),
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  FoodItem copyWith({
    String? id,
    String? name,
    int? calories,
    int? protein,
    int? carbs,
    int? fats,
    double? consumedAmount,
    String? consumedUnit,
    bool? isAiLogged,
    bool? isFavorite,
    String? dateString,
    int? timestamp,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      consumedAmount: consumedAmount ?? this.consumedAmount,
      consumedUnit: consumedUnit ?? this.consumedUnit,
      isAiLogged: isAiLogged ?? this.isAiLogged,
      isFavorite: isFavorite ?? this.isFavorite,
      dateString: dateString ?? this.dateString,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}