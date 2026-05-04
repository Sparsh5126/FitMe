import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/models/user_profile.dart';

class DietMealPlan {
  final String mealName;
  final String time;
  final String foodDescription; 
  final int calories;
  final int protein;
  final int carbs;
  final int fats;

  DietMealPlan({
    required this.mealName,
    required this.time,
    required this.foodDescription,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  factory DietMealPlan.fromMap(Map<String, dynamic> map) {
    return DietMealPlan(
      mealName: map['mealName'] ?? '',
      time: map['time'] ?? '',
      foodDescription: map['foodDescription'] ?? '',
      calories: map['calories'] ?? 0,
      protein: map['protein'] ?? 0,
      carbs: map['carbs'] ?? 0,
      fats: map['fats'] ?? 0,
    );
  }
}

class DietPlanService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<List<DietMealPlan>?> generatePlan({
    required UserProfile profile,
    required String planType,
    required String lifestyle,
    required String budget,
  }) async {
    if (_apiKey.isEmpty) return null;

    final prompt = '''
You are an elite nutritionist and meal planner. Create a highly specific 1-day master diet plan for the user based on the parameters below.

USER PROFILE:
- Target Calories: ${profile.dailyCalories} kcal
- Target Macros: ${profile.dailyProtein}g P, ${profile.dailyCarbs}g C, ${profile.dailyFats}g F
- Goal: ${profile.goalPace} (Weight: ${profile.weight}kg -> ${profile.goalWeight}kg)

PREFERENCES & CONSTRAINTS:
- Diet Type: $planType (STRICTLY adhere to this)
- Lifestyle/Schedule: $lifestyle (Adjust meal prep time and portability based on this)
- Budget: $budget (Recommend ingredients that fit this financial constraint)

Create 4 to 5 meals (e.g., Breakfast, Snack, Lunch, Evening Snack, Dinner) that total up exactly to their target calories and macros (within a 5% margin of error).
Foods must be realistic, culturally appropriate (default to Indian/Global mix), and practical for their lifestyle.
''';

    final config = {
      'temperature': 0.3,
      'responseMimeType': 'application/json',
      'responseSchema': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'mealName': {'type': 'STRING'},
            'time': {'type': 'STRING'},
            'foodDescription': {'type': 'STRING'},
            'calories': {'type': 'INTEGER'},
            'protein': {'type': 'INTEGER'},
            'carbs': {'type': 'INTEGER'},
            'fats': {'type': 'INTEGER'}
          },
          'required': ['mealName', 'time', 'foodDescription', 'calories', 'protein', 'carbs', 'fats']
        }
      }
    };

    final body = jsonEncode({
      'contents': [{'role': 'user', 'parts': [{'text': prompt}]}],
      'generationConfig': config,
    });

    try {
      final rawResponse = await _postWithFallback(body);
      final data = jsonDecode(rawResponse);
      final text = data['candidates'][0]['content']['parts'][0]['text'];
      final List parsedList = jsonDecode(text);
      return parsedList.map((m) => DietMealPlan.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Diet Plan Exception: $e');
    }
    return null;
  }

// ── SMART FALLBACK ROUTING ──────────────────────────────────────────────
  static Future<String> _postWithFallback(String body) async {
    final List<int> delays = [1, 2]; 
    // Changed fallback from 1.5-pro to 1.5-flash to avoid the 404 error
    final models = ['gemini-2.5-flash', 'gemini-1.5-flash'];

    for (String model in models) {
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey';

      for (int i = 0; i <= delays.length; i++) {
        try {
          final response = await http
              .post(Uri.parse(url),
                  headers: {'Content-Type': 'application/json'}, body: body)
              // INCREASED TIMEOUT TO 35 SECONDS FOR COMPLEX JSON GENERATION
              .timeout(const Duration(seconds: 35)); 
              
          if (response.statusCode == 200) {
            return response.body;
          }

          debugPrint('⚠️ [Diet AI] $model Attempt ${i + 1} failed. Status: ${response.statusCode}');

          if (response.statusCode == 429 && response.body.contains('limit: 0')) {
              throw Exception('API Quota exhausted. Try a different API key.');
          }

          if ((response.statusCode == 503 || response.statusCode == 404) && i == delays.length) {
             debugPrint('🔄 [Diet AI] $model unavailable. Switching to fallback...');
             break; 
          }

          if (i == delays.length && model == models.last) {
             throw Exception('Gemini API error ${response.statusCode}: ${response.body}');
          }
          
          if (i < delays.length) {
            await Future.delayed(Duration(seconds: delays[i]));
          }
        } catch (e) {
          debugPrint('⚠️ [Diet AI] $model network/timeout error: $e');
          if (i == delays.length && model == models.last) rethrow;
          
          if (i < delays.length) {
            await Future.delayed(Duration(seconds: delays[i]));
          }
        }
      }
    }
    throw Exception('Failed to connect to Gemini API across all models.');
  }
}