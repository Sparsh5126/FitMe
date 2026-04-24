class UserProfile {
  final String uid;
  final String name;
  final int age;
  final double weight;
  final double height;
  final String gender;
  final double goalWeight;
  final String activityLevel;
  final String dietType;
  final String appUse;

  // Base goals (never change unless user edits profile)
  final int dailyCalories;
  final int dailyProtein;
  final int dailyCarbs;
  final int dailyFats;

  // Dynamic goals (adjusted by weekly re-balancer)
  final int dynamicCalories;
  final int dynamicProtein;
  final int dynamicCarbs;
  final int dynamicFats;

  // Settings toggles
  final bool hiFiveEnabled;
  final bool celebrationsEnabled;
  final bool restMessagesEnabled;

  // Smart logger daily limit
  final int smartLoggerUsedToday;
  final String smartLoggerLastResetDate; // YYYY-MM-DD

  // Personalization
  final String mantra;

  UserProfile({
    required this.uid,
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.goalWeight,
    required this.activityLevel,
    required this.dietType,
    required this.appUse,
    required this.dailyCalories,
    required this.dailyProtein,
    required this.dailyCarbs,
    required this.dailyFats,
    required this.dynamicCalories,
    required this.dynamicProtein,
    required this.dynamicCarbs,
    required this.dynamicFats,
    this.hiFiveEnabled = true,
    this.celebrationsEnabled = true,
    this.restMessagesEnabled = true,
    this.smartLoggerUsedToday = 0,
    this.smartLoggerLastResetDate = '',
    this.mantra = '',
  });

  // --- MACRO CALCULATION ---
  // Called during onboarding to compute goals from user stats.
  // BMR: Mifflin-St Jeor formula
  // TDEE: BMR × activity multiplier
  // Deficit/Surplus: based on goal weight vs current weight
  static UserProfile fromOnboarding({
    required String uid,
    required String name,
    required int age,
    required double weight,
    required double height,
    required String gender,
    required double goalWeight,
    required String activityLevel,
    required String dietType,
    required String appUse,
    required String mantra,
  }) {
    final macros = _calculateMacros(
      age: age,
      weight: weight,
      height: height,
      gender: gender,
      goalWeight: goalWeight,
      activityLevel: activityLevel,
      dietType: dietType,
      appUse: appUse,
    );

    return UserProfile(
      uid: uid,
      name: name,
      age: age,
      weight: weight,
      height: height,
      gender: gender,
      goalWeight: goalWeight,
      activityLevel: activityLevel,
      dietType: dietType,
      appUse: appUse,
      dailyCalories: macros['calories']!,
      dailyProtein: macros['protein']!,
      dailyCarbs: macros['carbs']!,
      dailyFats: macros['fats']!,
      dynamicCalories: macros['calories']!,
      dynamicProtein: macros['protein']!,
      dynamicCarbs: macros['carbs']!,
      dynamicFats: macros['fats']!,
      mantra: mantra,
    );
  }

  static Map<String, int> _calculateMacros({
    required int age,
    required double weight,
    required double height,
    required String gender,
    required double goalWeight,
    required String activityLevel,
    required String dietType,
    required String appUse,
  }) {
    // BMR (Mifflin-St Jeor)
    double bmr;
    if (gender == 'male') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }

    // TDEE
    const multipliers = {
      'sedentary': 1.2,
      'light': 1.375,
      'moderate': 1.55,
      'active': 1.725,
      'athlete': 1.9,
    };
    double tdee = bmr * (multipliers[activityLevel] ?? 1.2);

    // Deficit or surplus based on goal
    double targetCalories;
    if (goalWeight < weight) {
      targetCalories = tdee - 500; // ~0.5kg/week loss
    } else if (goalWeight > weight) {
      targetCalories = tdee + 300; // lean bulk
    } else {
      targetCalories = tdee; // maintenance
    }
    targetCalories = targetCalories.clamp(1200, 4000);

    // Protein: higher for gym users and non-veg
    double proteinMultiplier = 1.6;
    if (appUse == 'gym' || appUse == 'both') proteinMultiplier = 2.0;
    if (dietType == 'nonveg') proteinMultiplier += 0.1;
    int protein = (weight * proteinMultiplier).round().clamp(100, 300);

    // Fats: 25% of total calories
    int fats = ((targetCalories * 0.25) / 9).round();

    // Carbs: remaining calories
    int carbCalories = (targetCalories - (protein * 4) - (fats * 9)).round();
    int carbs = (carbCalories / 4).round().clamp(50, 500);

    return {
      'calories': targetCalories.round(),
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
    };
  }

  // --- SERIALIZATION ---
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'age': age,
      'weight': weight,
      'height': height,
      'gender': gender,
      'goalWeight': goalWeight,
      'activityLevel': activityLevel,
      'dietType': dietType,
      'appUse': appUse,
      'dailyCalories': dailyCalories,
      'dailyProtein': dailyProtein,
      'dailyCarbs': dailyCarbs,
      'dailyFats': dailyFats,
      'dynamicCalories': dynamicCalories,
      'dynamicProtein': dynamicProtein,
      'dynamicCarbs': dynamicCarbs,
      'dynamicFats': dynamicFats,
      'hiFiveEnabled': hiFiveEnabled,
      'celebrationsEnabled': celebrationsEnabled,
      'restMessagesEnabled': restMessagesEnabled,
      'smartLoggerUsedToday': smartLoggerUsedToday,
      'smartLoggerLastResetDate': smartLoggerLastResetDate,
      'mantra': mantra,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      age: map['age']?.toInt() ?? 0,
      weight: (map['weight'] ?? 70.0).toDouble(),
      height: (map['height'] ?? 170.0).toDouble(),
      gender: map['gender'] ?? 'male',
      goalWeight: (map['goalWeight'] ?? 70.0).toDouble(),
      activityLevel: map['activityLevel'] ?? 'moderate',
      dietType: map['dietType'] ?? 'nonveg',
      appUse: map['appUse'] ?? 'both',
      dailyCalories: map['dailyCalories']?.toInt() ?? 2000,
      dailyProtein: map['dailyProtein']?.toInt() ?? 150,
      dailyCarbs: map['dailyCarbs']?.toInt() ?? 200,
      dailyFats: map['dailyFats']?.toInt() ?? 55,
      dynamicCalories: map['dynamicCalories']?.toInt() ?? 2000,
      dynamicProtein: map['dynamicProtein']?.toInt() ?? 150,
      dynamicCarbs: map['dynamicCarbs']?.toInt() ?? 200,
      dynamicFats: map['dynamicFats']?.toInt() ?? 55,
      hiFiveEnabled: map['hiFiveEnabled'] ?? true,
      celebrationsEnabled: map['celebrationsEnabled'] ?? true,
      restMessagesEnabled: map['restMessagesEnabled'] ?? true,
      smartLoggerUsedToday: map['smartLoggerUsedToday']?.toInt() ?? 0,
      smartLoggerLastResetDate: map['smartLoggerLastResetDate'] ?? '',
      mantra: map['mantra'] ?? '',
    );
  }

  UserProfile copyWith({
    int? dynamicCalories,
    int? dynamicProtein,
    int? dynamicCarbs,
    int? dynamicFats,
    bool? hiFiveEnabled,
    bool? celebrationsEnabled,
    bool? restMessagesEnabled,
    int? smartLoggerUsedToday,
    String? smartLoggerLastResetDate,
    String? mantra,
    double? weight,
  }) {
    return UserProfile(
      uid: uid,
      name: name,
      age: age,
      weight: weight ?? this.weight,
      height: height,
      gender: gender,
      goalWeight: goalWeight,
      activityLevel: activityLevel,
      dietType: dietType,
      appUse: appUse,
      dailyCalories: dailyCalories,
      dailyProtein: dailyProtein,
      dailyCarbs: dailyCarbs,
      dailyFats: dailyFats,
      dynamicCalories: dynamicCalories ?? this.dynamicCalories,
      dynamicProtein: dynamicProtein ?? this.dynamicProtein,
      dynamicCarbs: dynamicCarbs ?? this.dynamicCarbs,
      dynamicFats: dynamicFats ?? this.dynamicFats,
      hiFiveEnabled: hiFiveEnabled ?? this.hiFiveEnabled,
      celebrationsEnabled: celebrationsEnabled ?? this.celebrationsEnabled,
      restMessagesEnabled: restMessagesEnabled ?? this.restMessagesEnabled,
      smartLoggerUsedToday: smartLoggerUsedToday ?? this.smartLoggerUsedToday,
      smartLoggerLastResetDate: smartLoggerLastResetDate ?? this.smartLoggerLastResetDate,
      mantra: mantra ?? this.mantra,
    );
  }

  // BMI helper (used in onboarding real-time display)
  double get bmi => weight / ((height / 100) * (height / 100));

  String get bmiCategory {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }
}
