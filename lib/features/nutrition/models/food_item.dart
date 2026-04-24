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
  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.consumedAmount = 1.0,
    this.consumedUnit = 'serving',
    this.isAiLogged = false,
  });

  // 1. Translates the Dart Object into JSON to save to Firebase
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
      // We generate the timestamp & dateString right before saving!
      'timestamp': DateTime.now().toIso8601String(),
      'dateString': DateTime.now().toIso8601String().split('T')[0], // YYYY-MM-DD format
      'isAiLogged': isAiLogged,
    };
  }

  // 2. Translates the Firebase JSON back into a Dart Object
  factory FoodItem.fromMap(Map<String, dynamic> map, String documentId) {
    return FoodItem(
      id: documentId,
      name: map['name'] ?? 'Unknown Food',
      calories: map['calories']?.toInt() ?? 0,
      protein: map['protein']?.toInt() ?? 0,
      carbs: map['carbs']?.toInt() ?? 0,
      fats: map['fats']?.toInt() ?? 0,
      consumedAmount: (map['consumedAmount'] ?? 1.0).toDouble(),
      consumedUnit: map['consumedUnit'] ?? 'serving',
      isAiLogged: map['isAiLogged'] ?? false,
    );
  }
}