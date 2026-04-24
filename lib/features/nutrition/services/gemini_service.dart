import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';

class GeminiService {
  static const _apiKey = 'YOUR_GEMINI_API_KEY'; // move to .env
  static const _url =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey';

  /// Parse a natural language food log into a list of FoodItems.
  static Future<List<FoodItem>> parseFood(String input) async {
    const systemPrompt = '''
You are a nutrition assistant. The user will describe what they ate.
Return ONLY a valid JSON array (no markdown, no explanation) with this structure:
[
  {
    "name": "Food name",
    "calories": 300,
    "protein": 20,
    "carbs": 35,
    "fats": 8
  }
]
- Split multi-item meals into separate objects (e.g. "roti and dal" = 2 objects).
- Use realistic Indian/global nutrition data.
- All values must be integers.
- If you cannot parse the input, return an empty array [].
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': '$systemPrompt\n\nUser input: $input'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 512,
      }
    });

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode != 200) throw Exception('Gemini API error ${response.statusCode}');

      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'] as String;

      // Strip any accidental markdown fences
      final cleaned = text.replaceAll(RegExp(r'```json|```'), '').trim();
      final List parsed = jsonDecode(cleaned);

      return parsed.map((item) {
        return FoodItem(
          id: DateTime.now().millisecondsSinceEpoch.toString() + item['name'].hashCode.toString(),
          name: item['name'] ?? 'Unknown',
          calories: (item['calories'] ?? 0).toInt(),
          protein: (item['protein'] ?? 0).toInt(),
          carbs: (item['carbs'] ?? 0).toInt(),
          fats: (item['fats'] ?? 0).toInt(),
          consumedAmount: 1,
          consumedUnit: 'serving',
          isAiLogged: true,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}