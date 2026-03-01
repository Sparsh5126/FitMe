class UserProfile {
  final int dailyCalories;
  final int dailyProtein;
  final int dailyCarbs;
  final int dailyFats;

  UserProfile({
    required this.dailyCalories,
    required this.dailyProtein,
    required this.dailyCarbs,
    required this.dailyFats,
  });

  // A default profile for brand new users (e.g., 2000 cals)
  factory UserProfile.defaultProfile() {
    return UserProfile(
      dailyCalories: 2000,
      dailyProtein: 150,  // 30% of 2000 / 4
      dailyCarbs: 200,    // 40% of 2000 / 4
      dailyFats: 66,      // 30% of 2000 / 9
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailyCalories': dailyCalories,
      'dailyProtein': dailyProtein,
      'dailyCarbs': dailyCarbs,
      'dailyFats': dailyFats,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      dailyCalories: map['dailyCalories']?.toInt() ?? 2000,
      dailyProtein: map['dailyProtein']?.toInt() ?? 150,
      dailyCarbs: map['dailyCarbs']?.toInt() ?? 200,
      dailyFats: map['dailyFats']?.toInt() ?? 66,
    );
  }
}