import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI USAGE SERVICE
// Shared 10-uses-per-day counter for AI-powered features.
// Used by DietAnalysisScreen and DietPlanScreen.
// ─────────────────────────────────────────────────────────────────────────────

const String kAiUsageKey     = 'ai_use_count';
const String kAiUsageDateKey = 'ai_use_date';
const int    kAiDailyLimit   = 10;

class AiUsageService {
  /// Returns the number of AI calls remaining for today.
  static Future<int> getRemainingUses() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    if ((prefs.getString(kAiUsageDateKey) ?? '') != today) {
      await prefs.setInt(kAiUsageKey, 0);
      await prefs.setString(kAiUsageDateKey, today);
      return kAiDailyLimit;
    }
    final used = prefs.getInt(kAiUsageKey) ?? 0;
    return (kAiDailyLimit - used).clamp(0, kAiDailyLimit);
  }

  /// Deducts one AI credit.
  /// Returns `true` if allowed, `false` if the daily limit is already hit.
  static Future<bool> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    if ((prefs.getString(kAiUsageDateKey) ?? '') != today) {
      await prefs.setInt(kAiUsageKey, 1);
      await prefs.setString(kAiUsageDateKey, today);
      return true;
    }
    final used = prefs.getInt(kAiUsageKey) ?? 0;
    if (used >= kAiDailyLimit) return false;
    await prefs.setInt(kAiUsageKey, used + 1);
    return true;
  }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);
}
