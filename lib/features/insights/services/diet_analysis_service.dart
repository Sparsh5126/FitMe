import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../nutrition/models/food_item.dart';
import '../../../core/models/user_profile.dart';

class DietAnalysisResult {
  final String proteinGaps;
  final String calorieTrends;
  final String mealTiming;
  final String junkFrequency;
  final String micronutrientWarnings;

  DietAnalysisResult({
    required this.proteinGaps,
    required this.calorieTrends,
    required this.mealTiming,
    required this.junkFrequency,
    required this.micronutrientWarnings,
  });

  factory DietAnalysisResult.fromMap(Map<String, dynamic> map) {
    return DietAnalysisResult(
      proteinGaps: map['proteinGaps'] ?? 'No data found.',
      calorieTrends: map['calorieTrends'] ?? 'No data found.',
      mealTiming: map['mealTiming'] ?? 'No data found.',
      junkFrequency: map['junkFrequency'] ?? 'No data found.',
      micronutrientWarnings: map['micronutrientWarnings'] ?? 'No data found.',
    );
  }
}

class DietAnalysisService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<DietAnalysisResult?> analyze7Days(List<FoodItem> logs, UserProfile profile) async {
    if (_apiKey.isEmpty || logs.isEmpty) return null;

    final logsByDate = <String, List<Map<String, dynamic>>>{};
    for (final food in logs) {
      if (!logsByDate.containsKey(food.dateString)) {
        logsByDate[food.dateString] = [];
      }
      final timeStr = DateTime.fromMillisecondsSinceEpoch(food.timestamp)
          .toLocal()
          .toString()
          .substring(11, 16); 
          
      logsByDate[food.dateString]!.add({
        'name': food.name,
        'time': timeStr,
        'calories': food.calories,
        'protein': food.protein,
        'carbs': food.carbs,
        'fats': food.fats,
      });
    }

    final prompt = '''
Analyze the user's 7-day food logs against their profile goals and provide specific, actionable insights. Speak directly to the user (e.g., "You fell short...", "Try adding..."). Keep it concise and highly specific to the foods logged.

User Profile:
- Diet Type: ${profile.dietType}
- Goal: ${profile.goalPace} (Weight: ${profile.weight}kg -> ${profile.goalWeight}kg)
- Daily Targets: ${profile.dailyCalories} kcal, ${profile.dailyProtein}g Protein, ${profile.dailyCarbs}g Carbs, ${profile.dailyFats}g Fats.

Last 7 Days Logs:
${jsonEncode(logsByDate)}

Identify and return exactly these 5 keys in valid JSON format:
1. proteinGaps: Point out days or meals where protein was missed and suggest fixes based on their diet type.
2. calorieTrends: Analyze if they are hitting their calorie goals for their weight pace.
3. mealTiming: Identify skipping meals, late night eating, or irregular patterns based on the logged times.
4. junkFrequency: Point out ultra-processed, high-sugar, or low-nutrient foods they consumed.
5. micronutrientWarnings: Suggest missing vitamins/minerals based on the food variety (e.g., missing greens, iron, calcium).
''';

    final config = {
      'temperature': 0.2, 
      'responseMimeType': 'application/json',
      'responseSchema': {
        'type': 'OBJECT',
        'properties': {
          'proteinGaps': {'type': 'STRING'},
          'calorieTrends': {'type': 'STRING'},
          'mealTiming': {'type': 'STRING'},
          'junkFrequency': {'type': 'STRING'},
          'micronutrientWarnings': {'type': 'STRING'}
        },
        'required': ['proteinGaps', 'calorieTrends', 'mealTiming', 'junkFrequency', 'micronutrientWarnings']
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
      return DietAnalysisResult.fromMap(jsonDecode(text));
    } catch (e) {
      debugPrint('Diet Analysis Exception: $e');
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