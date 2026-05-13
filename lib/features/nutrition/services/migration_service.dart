import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitme/features/nutrition/services/local_nutrition_service.dart';
import 'package:fitme/features/nutrition/repositories/nutrition_repository.dart';
import 'package:fitme/features/fitpoints/services/fitpoints_service.dart';
import 'package:fitme/features/fitpoints/models/fitpoints_models.dart';

import 'package:shared_preferences/shared_preferences.dart';

class MigrationService {
  static final _repo = NutritionRepository();
  static final _db = FirebaseFirestore.instance;

  static Future<void> performMerge(String uid) async {
    dev.log(
      '[MigrationService] Starting merge for user: $uid',
      name: 'Migration',
    );

    try {
      // 1. Migrate Nutrition Logs
      final guestLogs = await LocalNutritionService.getLogs();
      if (guestLogs.isNotEmpty) {
        dev.log(
          '[MigrationService] Migrating ${guestLogs.length} logs',
          name: 'Migration',
        );
        for (final log in guestLogs) {
          // Check for duplicates in Firestore
          // We can use a combination of name and timestamp as a simple hash
          await _repo.addLogOnly(log);
        }
      }

      // 2. Migrate Custom Meals
      final guestCustoms = await LocalNutritionService.getCustomMeals();
      if (guestCustoms.isNotEmpty) {
        dev.log(
          '[MigrationService] Migrating ${guestCustoms.length} custom meals',
          name: 'Migration',
        );
        for (final meal in guestCustoms) {
          await _repo.saveCustomMeal(meal);
        }
      }

      // 3. Migrate Profile
      final guestProfile = await LocalNutritionService.getProfile();
      if (guestProfile != null) {
        dev.log(
          '[MigrationService] Migrating guest profile',
          name: 'Migration',
        );
        await _db
            .collection('users')
            .doc(uid)
            .set(
              guestProfile.copyWith(uid: uid).toMap(),
              SetOptions(merge: true),
            );
      }
      
      // 4. Migrate FitPoints
      final guestFPData = await LocalNutritionService.getFitPointsRecord();
      if (guestFPData != null) {
        final guestFP = FitPointsRecord.fromJson(guestFPData);
        final fpService = FitPointsService();
        
        // Fetch current account record
        final accountFP = await fpService.getRecord(uid, false);
        
        dev.log(
          '[MigrationService] Merging FP: guest_lifetime=${guestFP.lifetimePoints}, '
          'account_lifetime=${accountFP.lifetimePoints}',
          name: 'Migration',
        );
        
        // Perform merge
        final mergedFP = fpService.migrateGuestToAccount(
          guestRecord: guestFP,
          accountRecord: accountFP,
        );
        
        dev.log(
          '[MigrationService] Merged FP total: ${mergedFP.lifetimePoints}',
          name: 'Migration',
        );
        
        // Save to Firestore
        await fpService.saveRecord(mergedFP);
      }

      // 5. Migrate Recipe Favorites
      final prefs = await SharedPreferences.getInstance();
      final favIds = prefs.getStringList('recipe_favorites') ?? [];
      if (favIds.isNotEmpty) {
        dev.log(
          '[MigrationService] Migrating ${favIds.length} favorites',
          name: 'Migration',
        );
        // ... handled via food items if needed, but recipes have their own logic
      }

      // 5. Cleanup
      await LocalNutritionService.clearAll();
      dev.log(
        '[MigrationService] Merge complete and local data cleared',
        name: 'Migration',
      );
    } catch (e, stack) {
      dev.log(
        '[MigrationService] Merge failed: $e',
        name: 'Migration',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  static Future<void> discardGuestData() async {
    dev.log('[MigrationService] Discarding guest data', name: 'Migration');
    await LocalNutritionService.clearAll();
  }
}
