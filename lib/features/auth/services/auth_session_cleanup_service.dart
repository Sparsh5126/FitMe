import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

/// Service responsible for clearing account-bound local data during sign-out.
/// It specifically targets cached insights, histories, and preferences that
/// should not leak between different user accounts on the same device.
///
/// It preserves Guest Mode data (LocalNutritionService keys) so that guest
/// progress is not accidentally wiped when a user logs out of their main account.
class AuthSessionCleanupService {
  static const String _tag = 'SessionCleanup';

  /// Clears all account-bound local data.
  static Future<void> clear() async {
    dev.log('Starting session cleanup...', name: _tag);
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    int removedCount = 0;

    for (final key in allKeys) {
      // 1. Smart Logger History
      if (key.startsWith('smart_logger_history_')) {
        await prefs.remove(key);
        removedCount++;
        continue;
      }

      // 2. Oil Preferences
      if (key.startsWith('oil_pref_')) {
        await prefs.remove(key);
        removedCount++;
        continue;
      }

      // 3. AI Usage Counters
      if (key == 'ai_use_count' || key == 'ai_use_date') {
        await prefs.remove(key);
        removedCount++;
        continue;
      }
      
      // 4. Recipes/Favourites caches (if any specific ones exist)
      // Currently, recipes seem to be fetched live or using general recents.
    }

    // 5. Hive Boxes (if any)
    // Note: If Hive is added later for user_insights, it should be cleared here:
    // if (Hive.isBoxOpen('user_insights')) {
    //   await Hive.box('user_insights').clear();
    // }

    dev.log('Session cleanup complete. Removed $removedCount keys.', name: _tag);
  }
}
