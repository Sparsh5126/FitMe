import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/food_item.dart';

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // Text model
  static String get _textUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey';

  // Vision model (same endpoint – flash is multimodal)
  static String get _visionUrl => _textUrl;

  static const _systemPrompt = '''
You are a nutrition assistant. The user will describe what they ate, OR you will receive a photo of food.
Return ONLY a valid JSON array (no markdown, no explanation, no code fences) with this exact structure:
[
  {
    "name": "Food name in English",
    "calories": 300,
    "protein": 20,
    "carbs": 35,
    "fats": 8
  }
]
Rules:
- Split multi-item meals into separate objects (e.g. "roti and dal" → 2 objects).
- Use realistic Indian and global nutrition data. MUST use these accurate values:
  roti/chapati≈104kcal/piece(3P,18C,3F), paratha≈200kcal/piece, aloo paratha≈260kcal
  dal/lentils≈150kcal/katori(9P,22C,3F), moong dal≈147kcal/katori, chana dal≈200kcal/katori
  rice/chawal≈206kcal/katori(4P,45C,0F), dal chawal≈350kcal/plate
  paneer≈265kcal/100g(18P,3C,20F), paneer butter masala≈280kcal/katori
  chicken breast≈165kcal/100g(31P,0C,4F), chicken curry≈280kcal/katori
  biryani≈490kcal/plate, butter chicken≈320kcal/katori
  sabzi/vegetable curry≈120kcal/katori, aloo gobi≈170kcal/katori
  dosa≈168kcal/piece, idli≈58kcal/piece, sambar≈90kcal/katori
  egg≈78kcal/piece(6P,1C,5F), omelette≈154kcal
  milk≈150kcal/glass, curd/dahi≈98kcal/katori
- All values must be integers.
- If you cannot identify any food, return exactly: []
- Do NOT return markdown, prose, or anything other than the JSON array.
''';

  // ── Text logging ──────────────────────────────────────────────────────────

  /// Parse a natural language description. Throws on API errors.
  static Future<List<FoodItem>> parseFood(String input) async {
    _assertApiKey();
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': '$_systemPrompt\n\nUser input: $input'}
          ]
        }
      ],
      'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 512},
    });
    final raw = await _post(_textUrl, body);
    return _parseResponse(raw);
  }

  /// Like [parseFood] but never throws — returns [] on any error.
  static Future<List<FoodItem>> parseFoodSafe(String input) async {
    try {
      if (_apiKey.isEmpty) return [];
      return await parseFood(input).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[GeminiService] parseFoodSafe silent: $e');
      return [];
    }
  }

  // ── Photo logging ─────────────────────────────────────────────────────────

  /// Parse food from an image file. Throws on API errors.
  static Future<List<FoodItem>> parseFoodFromImage(File imageFile) async {
    _assertApiKey();

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _mimeType(imageFile.path);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': '$_systemPrompt\n\nIdentify all food items visible in this photo and return their nutrition data.'},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 512},
    });

    final raw = await _post(_visionUrl, body);
    return _parseResponse(raw);
  }

  // ── Voice logging ─────────────────────────────────────────────────────────

  /// Parse food from a speech-to-text transcript.
  /// (Speech recognition is done by the caller; this just parses the text.)
  static Future<List<FoodItem>> parseFoodFromVoice(String transcript) =>
      parseFood(transcript);

  // ── Barcode lookup ────────────────────────────────────────────────────────

  /// Ask Gemini to estimate nutrition for a product by barcode/name when
  /// OpenFoodFacts returns nothing.
  static Future<List<FoodItem>> parseFoodFromBarcode(String productName) =>
      parseFood('Product: $productName (packaged food)');

  // ── Private helpers ───────────────────────────────────────────────────────

  static void _assertApiKey() {
    if (_apiKey.isEmpty) {
      throw Exception(
          'GEMINI_API_KEY is not set in .env. Add it and restart the app.');
    }
  }

  static Future<String> _post(String url, String body) async {
    debugPrint('[GeminiService] POST');
    final response = await http
        .post(Uri.parse(url),
            headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 10));
    debugPrint('[GeminiService] status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception('Gemini API error ${response.statusCode}');
    }
    return response.body;
  }

  static List<FoodItem> _parseResponse(String responseBody) {
    final data = jsonDecode(responseBody);

    // Extract text from response
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      debugPrint('[GeminiService] No candidates in response');
      return [];
    }

    final text =
        candidates[0]['content']['parts'][0]['text'] as String? ?? '';
    debugPrint('[GeminiService] raw text: $text');

    // Strip any accidental markdown fences
    final cleaned = text
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();

    // Find the JSON array in the response even if there's surrounding text
    final arrayStart = cleaned.indexOf('[');
    final arrayEnd = cleaned.lastIndexOf(']');
    if (arrayStart == -1 || arrayEnd == -1) {
      debugPrint('[GeminiService] No JSON array found in: $cleaned');
      return [];
    }

    final jsonStr = cleaned.substring(arrayStart, arrayEnd + 1);
    debugPrint('[GeminiService] parsed JSON: $jsonStr');

    final List parsed = jsonDecode(jsonStr);

    return parsed.map((item) {
      final id = 'gemini_${DateTime.now().microsecondsSinceEpoch}_${item['name'].hashCode}';
      return FoodItem(
        id: id,
        name: item['name'] ?? 'Unknown',
        calories: _toInt(item['calories']),
        protein: _toInt(item['protein']),
        carbs: _toInt(item['carbs']),
        fats: _toInt(item['fats']),
        consumedAmount: 1,
        consumedUnit: 'serving',
        isAiLogged: true,
      );
    }).where((f) => f.calories > 0).toList();
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  static String _mimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}