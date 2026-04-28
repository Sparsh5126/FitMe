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
  final String goalPace; // very_slow | slow | moderate | fast | aggressive

  final int dailyCalories;
  final int dailyProtein;
  final int dailyCarbs;
  final int dailyFats;

  final int dynamicCalories;
  final int dynamicProtein;
  final int dynamicCarbs;
  final int dynamicFats;

  final bool hiFiveEnabled;
  final bool celebrationsEnabled;
  final bool restMessagesEnabled;
  final bool morningReminderEnabled;
  final bool streakAlertsEnabled;
  final bool rebalancerUpdatesEnabled;

  final int smartLoggerUsedToday;
  final String smartLoggerLastResetDate;

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
    this.goalPace = 'moderate',
    this.hiFiveEnabled = true,
    this.celebrationsEnabled = true,
    this.restMessagesEnabled = true,
    this.morningReminderEnabled = true,
    this.streakAlertsEnabled = true,
    this.rebalancerUpdatesEnabled = true,
    this.smartLoggerUsedToday = 0,
    this.smartLoggerLastResetDate = '',
    this.mantra = '',
  });

  // ── Pace helpers ────────────────────────────────────────────────────────────
  static const _paceDeltas = <String, int>{
    'very_slow': 200,
    'slow':      350,
    'moderate':  500,
    'fast':      650,
    'aggressive':850,
  };

  static int paceDelta(String pace) => _paceDeltas[pace] ?? 500;

  static String paceLabel(String pace) {
    const labels = {
      'very_slow':  'Very Slow',
      'slow':       'Slow',
      'moderate':   'Moderate',
      'fast':       'Fast',
      'aggressive': 'Aggressive',
    };
    return labels[pace] ?? 'Moderate';
  }

  /// Expected kg change per week at this pace.
  static double weeklyChangeKg(String pace) =>
      paceDelta(pace) * 7 / 7700;

  // ── Onboarding factory ───────────────────────────────────────────────────
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
    String goalPace = 'moderate',
  }) {
    final macros = _calculateMacros(
      age: age, weight: weight, height: height, gender: gender,
      goalWeight: goalWeight, activityLevel: activityLevel,
      dietType: dietType, appUse: appUse, goalPace: goalPace,
    );

    return UserProfile(
      uid: uid, name: name, age: age, weight: weight, height: height,
      gender: gender, goalWeight: goalWeight, activityLevel: activityLevel,
      dietType: dietType, appUse: appUse, goalPace: goalPace,
      dailyCalories: macros['calories']!,
      dailyProtein:  macros['protein']!,
      dailyCarbs:    macros['carbs']!,
      dailyFats:     macros['fats']!,
      dynamicCalories: macros['calories']!,
      dynamicProtein:  macros['protein']!,
      dynamicCarbs:    macros['carbs']!,
      dynamicFats:     macros['fats']!,
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
    String goalPace = 'moderate',
  }) {
    double bmr = gender == 'male'
        ? 10 * weight + 6.25 * height - 5 * age + 5
        : 10 * weight + 6.25 * height - 5 * age - 161;

    const multipliers = {
      'sedentary': 1.2, 'light': 1.375, 'moderate': 1.55,
      'active': 1.725, 'athlete': 1.9,
    };
    final tdee = bmr * (multipliers[activityLevel] ?? 1.2);

    final delta = paceDelta(goalPace);
    double targetCalories;
    if (goalWeight < weight) {
      targetCalories = tdee - delta;
    } else if (goalWeight > weight) {
      targetCalories = tdee + (delta * 0.6).roundToDouble();
    } else {
      targetCalories = tdee;
    }
    targetCalories = targetCalories.clamp(1200, 4000);

    double proteinMultiplier = 1.6;
    if (appUse == 'gym' || appUse == 'both') proteinMultiplier = 2.0;
    if (dietType == 'nonveg') proteinMultiplier += 0.1;
    final protein = (weight * proteinMultiplier).round().clamp(100, 300);

    final fats  = ((targetCalories * 0.25) / 9).round();
    final carbCals = (targetCalories - (protein * 4) - (fats * 9)).round();
    final carbs = (carbCals / 4).round().clamp(50, 500);

    return {
      'calories': targetCalories.round(),
      'protein':  protein,
      'carbs':    carbs,
      'fats':     fats,
    };
  }

  // ── TDEE helper (used by UI widgets) ────────────────────────────────────
  double get tdee {
    double bmr = gender == 'male'
        ? 10 * weight + 6.25 * height - 5 * age + 5
        : 10 * weight + 6.25 * height - 5 * age - 161;
    const m = {'sedentary':1.2,'light':1.375,'moderate':1.55,'active':1.725,'athlete':1.9};
    return bmr * (m[activityLevel] ?? 1.2);
  }

  // ── Serialization ────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'uid': uid, 'name': name, 'age': age, 'weight': weight,
    'height': height, 'gender': gender, 'goalWeight': goalWeight,
    'activityLevel': activityLevel, 'dietType': dietType, 'appUse': appUse,
    'goalPace': goalPace,
    'dailyCalories': dailyCalories, 'dailyProtein': dailyProtein,
    'dailyCarbs': dailyCarbs, 'dailyFats': dailyFats,
    'dynamicCalories': dynamicCalories, 'dynamicProtein': dynamicProtein,
    'dynamicCarbs': dynamicCarbs, 'dynamicFats': dynamicFats,
    'hiFiveEnabled': hiFiveEnabled, 'celebrationsEnabled': celebrationsEnabled,
    'restMessagesEnabled': restMessagesEnabled,
    'morningReminderEnabled': morningReminderEnabled,
    'streakAlertsEnabled': streakAlertsEnabled,
    'rebalancerUpdatesEnabled': rebalancerUpdatesEnabled,
    'smartLoggerUsedToday': smartLoggerUsedToday,
    'smartLoggerLastResetDate': smartLoggerLastResetDate,
    'mantra': mantra,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    uid:            map['uid'] ?? '',
    name:           map['name'] ?? '',
    age:            map['age']?.toInt() ?? 0,
    weight:         (map['weight'] ?? 70.0).toDouble(),
    height:         (map['height'] ?? 170.0).toDouble(),
    gender:         map['gender'] ?? 'male',
    goalWeight:     (map['goalWeight'] ?? 70.0).toDouble(),
    activityLevel:  map['activityLevel'] ?? 'moderate',
    dietType:       map['dietType'] ?? 'nonveg',
    appUse:         map['appUse'] ?? 'both',
    goalPace:       map['goalPace'] ?? 'moderate',
    dailyCalories:  map['dailyCalories']?.toInt() ?? 2000,
    dailyProtein:   map['dailyProtein']?.toInt() ?? 150,
    dailyCarbs:     map['dailyCarbs']?.toInt() ?? 200,
    dailyFats:      map['dailyFats']?.toInt() ?? 55,
    dynamicCalories: map['dynamicCalories']?.toInt() ?? 2000,
    dynamicProtein:  map['dynamicProtein']?.toInt() ?? 150,
    dynamicCarbs:    map['dynamicCarbs']?.toInt() ?? 200,
    dynamicFats:     map['dynamicFats']?.toInt() ?? 55,
    hiFiveEnabled:          map['hiFiveEnabled'] ?? true,
    celebrationsEnabled:    map['celebrationsEnabled'] ?? true,
    restMessagesEnabled:    map['restMessagesEnabled'] ?? true,
    morningReminderEnabled: map['morningReminderEnabled'] ?? true,
    streakAlertsEnabled:    map['streakAlertsEnabled'] ?? true,
    rebalancerUpdatesEnabled: map['rebalancerUpdatesEnabled'] ?? true,
    smartLoggerUsedToday:   map['smartLoggerUsedToday']?.toInt() ?? 0,
    smartLoggerLastResetDate: map['smartLoggerLastResetDate'] ?? '',
    mantra:         map['mantra'] ?? '',
  );

  UserProfile copyWith({
    String? uid, String? name, int? age, double? weight, double? height,
    String? gender, double? goalWeight, String? activityLevel,
    String? dietType, String? appUse, String? goalPace,
    int? dailyCalories, int? dailyProtein, int? dailyCarbs, int? dailyFats,
    int? dynamicCalories, int? dynamicProtein, int? dynamicCarbs, int? dynamicFats,
    bool? hiFiveEnabled, bool? celebrationsEnabled, bool? restMessagesEnabled,
    bool? morningReminderEnabled, bool? streakAlertsEnabled,
    bool? rebalancerUpdatesEnabled,
    int? smartLoggerUsedToday, String? smartLoggerLastResetDate, String? mantra,
  }) => UserProfile(
    uid: uid ?? this.uid, name: name ?? this.name,
    age: age ?? this.age, weight: weight ?? this.weight,
    height: height ?? this.height, gender: gender ?? this.gender,
    goalWeight: goalWeight ?? this.goalWeight,
    activityLevel: activityLevel ?? this.activityLevel,
    dietType: dietType ?? this.dietType, appUse: appUse ?? this.appUse,
    goalPace: goalPace ?? this.goalPace,
    dailyCalories: dailyCalories ?? this.dailyCalories,
    dailyProtein:  dailyProtein  ?? this.dailyProtein,
    dailyCarbs:    dailyCarbs    ?? this.dailyCarbs,
    dailyFats:     dailyFats     ?? this.dailyFats,
    dynamicCalories: dynamicCalories ?? this.dynamicCalories,
    dynamicProtein:  dynamicProtein  ?? this.dynamicProtein,
    dynamicCarbs:    dynamicCarbs    ?? this.dynamicCarbs,
    dynamicFats:     dynamicFats     ?? this.dynamicFats,
    hiFiveEnabled:          hiFiveEnabled          ?? this.hiFiveEnabled,
    celebrationsEnabled:    celebrationsEnabled    ?? this.celebrationsEnabled,
    restMessagesEnabled:    restMessagesEnabled    ?? this.restMessagesEnabled,
    morningReminderEnabled: morningReminderEnabled ?? this.morningReminderEnabled,
    streakAlertsEnabled:    streakAlertsEnabled    ?? this.streakAlertsEnabled,
    rebalancerUpdatesEnabled: rebalancerUpdatesEnabled ?? this.rebalancerUpdatesEnabled,
    smartLoggerUsedToday:     smartLoggerUsedToday     ?? this.smartLoggerUsedToday,
    smartLoggerLastResetDate: smartLoggerLastResetDate ?? this.smartLoggerLastResetDate,
    mantra: mantra ?? this.mantra,
  );

  double get bmi => weight / ((height / 100) * (height / 100));

  String get bmiCategory {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }
}
