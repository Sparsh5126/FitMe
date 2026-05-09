import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user_profile.dart';
import '../../nutrition/models/food_item.dart';
import '../../nutrition/repositories/nutrition_repository.dart';
import '../../notifications/notification_service.dart';
import '../../nutrition/services/local_nutrition_service.dart';

class StreakService {
  static final _db = FirebaseFirestore.instance;
  static final _repo = NutritionRepository();
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static const _milestones = [3, 5, 7, 14, 30, 60, 100];
  static const _thresholds = [0, 8, 22, 45, 90, 180];
  static const _labels = [
    'Light Dumbbell',
    'Heavy Dumbbell',
    'Iron Beast',
    'Titan',
    'Legendary',
    'Max Level',
  ];

  // ─────────────────────────────────────────
  // CALL ON APP OPEN / AFTER FOOD LOG
  // ─────────────────────────────────────────
  static Future<void> evaluate(UserProfile profile, {bool force = false}) async {
    final today = FoodItem.dateFor(DateTime.now());
    
    int longest = 0;
    int prevStreak = 0;
    String lastEvaluated = '';
    
    if (_uid.isNotEmpty) {
      final doc = await _db.collection('users').doc(_uid).get();
      final data = doc.data() ?? {};
      lastEvaluated = data['streakLastEvaluated'] as String? ?? '';
      longest = (data['longestStreak'] as int? ?? 0);
      prevStreak = data['currentStreak'] as int? ?? 0;
    } else {
      // Guest mode
      longest = profile.longestStreak;
      prevStreak = profile.currentStreak;
      lastEvaluated = profile.streakLastEvaluated;
    }

    if (!force && lastEvaluated == today) return; // already ran today, and not forced

    final hitDays = await _getHitDays(90);
    final current = _calculateStreak(hitDays);
    final newLongest = current > longest ? current : longest;

    if (_uid.isNotEmpty) {
      await _db.collection('users').doc(_uid).update({
        'currentStreak': current,
        'longestStreak': newLongest,
        'streakLastEvaluated': today,
      });
    } else {
      // Guest mode
      final updated = profile.copyWith(
        currentStreak: current,
        longestStreak: newLongest,
        streakLastEvaluated: today,
      );
      await LocalNutritionService.saveProfile(updated);
    }

    // Fire milestone notification if newly crossed
    for (final m in _milestones) {
      if (current >= m && prevStreak < m) {
        await NotificationService.showStreakMilestone(m, profile);
        break;
      }
    }

    // Redemption arc: was 0 yesterday, now > 0 today
    if (prevStreak == 0 && current > 0) {
      await NotificationService.showRedemptionArc();
    }
  }

  // ─────────────────────────────────────────
  // FULL 90-DAY HIT DAYS (for streak screen)
  // ─────────────────────────────────────────
  static Future<Set<String>> getHitDays() async => _getHitDays(90);

  static Future<Set<String>> _getHitDays(int days) async {
    final now = DateTime.now();
    final hitDays = <String>{};

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = FoodItem.dateFor(date);
      final logs = await _repo.getLogsForDate(dateStr);
      if (logs.isNotEmpty) hitDays.add(dateStr);
    }
    return hitDays;
  }

  // Consecutive days from today backwards
  static int _calculateStreak(Set<String> hitDays) {
    final now = DateTime.now();
    int streak = 0;
    for (int i = 0; i < 90; i++) {
      final key = FoodItem.dateFor(now.subtract(Duration(days: i)));
      if (hitDays.contains(key)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}