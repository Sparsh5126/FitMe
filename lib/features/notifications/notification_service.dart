import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../core/models/user_profile.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'fitme_main';
  static const _channelName = 'FitMe Notifications';

  // ─────────────────────────────────────────
  // INIT — call once in main.dart
  // ─────────────────────────────────────────
  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  // ─────────────────────────────────────────
  // SCHEDULE ALL RECURRING NOTIFICATIONS
  // Call after onboarding and on settings change
  // ─────────────────────────────────────────
  static Future<void> scheduleAll(UserProfile profile) async {
    await _plugin.cancelAll();
    await _scheduleMorning(profile);
    await _scheduleWeeklyReset();
  }

  // 8 AM daily — morning prompt
  static Future<void> _scheduleMorning(UserProfile profile) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      1,
      'Good morning, ${profile.name.split(' ').first}! 👋',
      'What are you fueling up with today?',
      scheduled,
      _channel(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Sunday 9 PM — weekly reset reminder
  static Future<void> _scheduleWeeklyReset() async {
    final now = tz.TZDateTime.now(tz.local);
    final daysUntilSunday = (7 - now.weekday) % 7;
    var sunday = tz.TZDateTime(tz.local, now.year, now.month, now.day + daysUntilSunday, 21);
    if (sunday.isBefore(now)) sunday = sunday.add(const Duration(days: 7));

    await _plugin.zonedSchedule(
      2,
      'Weekly Reset Tonight 🔄',
      'Goals resetting to base targets for Monday. Finish strong!',
      sunday,
      _channel(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // ─────────────────────────────────────────
  // CONTEXTUAL — call from app logic
  // ─────────────────────────────────────────

  // Show when user misses macro goal at end of day
  static Future<void> showMissedGoal(String macro, int logged, int goal) async {
    await _show(
      id: 10,
      title: 'Almost there! 💪',
      body: 'You logged ${logged}g of ${goal}g $macro today. The re-balancer has you covered for tomorrow.',
    );
  }

  // Show when streak milestone hit
  static Future<void> showStreakMilestone(int days, UserProfile profile) async {
    final messages = {
      3: '3 days in a row! You\'re building something real. 🔥',
      5: '5-day streak! Your discipline is showing. Keep going.',
      7: 'One full week! That\'s consistency. 💯',
      14: '2 weeks strong! You\'re in the zone now. ⚡',
      30: '30 DAYS! You\'re not the same person who started. 🏆',
    };
    final body = messages[days] ?? '$days day streak! ${profile.mantra.isNotEmpty ? profile.mantra : "Keep going!"}';

    await _show(id: 11, title: '🔥 $days-Day Streak!', body: body);
  }

  // Show when re-balancer adjusts goals
  static Future<void> showRebalancerUpdate(int proteinAdj, int carbsAdj) async {
    final parts = <String>[];
    if (proteinAdj != 0) parts.add('Protein ${proteinAdj > 0 ? '+' : ''}${proteinAdj}g');
    if (carbsAdj != 0) parts.add('Carbs ${carbsAdj > 0 ? '+' : ''}${carbsAdj}g');
    if (parts.isEmpty) return;

    await _show(
      id: 12,
      title: 'Goals Adjusted 🎯',
      body: '${parts.join(', ')} to keep you on track for the week.',
    );
  }

  // Show after skipped workout
  static Future<void> showSkippedWorkout() async {
    await _show(
      id: 13,
      title: 'Rest day? No worries. 💤',
      body: 'Tomorrow\'s a fresh start. What\'s one set you can commit to?',
    );
  }

  // Show mantra on tough days (when user logs late or misses)
  static Future<void> showMantra(UserProfile profile) async {
    if (profile.mantra.isEmpty) return;
    await _show(
      id: 14,
      title: 'Remember why you started 💭',
      body: '"${profile.mantra}"',
    );
  }

  // Show when user bounces back after a miss
  static Future<void> showRedemptionArc() async {
    await _show(
      id: 15,
      title: 'Back on track! 🙌',
      body: 'You pushed through. That\'s the hardest part. You\'re stronger for it.',
    );
  }

  // Show smart rescue — low calories remaining
  static Future<void> showSmartRescue(int remaining, String suggestion) async {
    await _show(
      id: 16,
      title: '${remaining} kcal left today 🍽️',
      body: 'Try: $suggestion to fill the gap.',
    );
  }

  // Show consistency over intensity (macros hit, no PR)
  static Future<void> showConsistencyWin() async {
    await _show(
      id: 17,
      title: 'Macro goals crushed! 💪',
      body: 'You hit your targets this week. That\'s a different kind of strength.',
    );
  }

  // Show coach memory notification (references past achievement)
  static Future<void> showCoachMemory(String achievement) async {
    await _show(
      id: 18,
      title: 'Look how far you\'ve come 📈',
      body: achievement,
    );
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────
  static Future<void> _show({required int id, required String title, required String body}) async {
    await _plugin.show(id, title, body, _channel());
  }

  static NotificationDetails _channel() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId, _channelName,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );
  }

  static Future<void> cancelAll() async => _plugin.cancelAll();
}