import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user_profile.dart';
import '../../nutrition/models/food_item.dart';
import '../../nutrition/repositories/nutrition_repository.dart';
import '../../notifications/notification_service.dart';

class StreakService {
  static final _db = FirebaseFirestore.instance;
  static final _repo = NutritionRepository();
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static const _milestones = [3, 5, 7, 14, 30, 60, 100];

  // ─────────────────────────────────────────
  // CALL ON APP OPEN / AFTER FOOD LOG
  // ─────────────────────────────────────────
  static Future<void> evaluate(UserProfile profile) async {
    final today = FoodItem.dateFor(DateTime.now());
    final doc = await _db.collection('users').doc(_uid).get();
    final data = doc.data() ?? {};

    final lastEvaluated = data['streakLastEvaluated'] as String? ?? '';
    if (lastEvaluated == today) return; // already ran today

    final hitDays = await _getHitDays(90);
    final current = _calculateStreak(hitDays);
    final longest = (data['longestStreak'] as int? ?? 0);
    final newLongest = current > longest ? current : longest;
    final prevStreak = data['currentStreak'] as int? ?? 0;

    await _db.collection('users').doc(_uid).update({
      'currentStreak': current,
      'longestStreak': newLongest,
      'streakLastEvaluated': today,
    });

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