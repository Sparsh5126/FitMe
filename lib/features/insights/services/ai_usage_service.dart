import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitme/features/dashboard/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI USAGE SERVICE
// Unified quota system for all AI-powered features:
// - Auth Users: 10 uses per day (synced via Firestore)
// - Guests: 5 uses per month (tracked locally via SharedPreferences)
// ─────────────────────────────────────────────────────────────────────────────

const String kGuestAiUsageKey = 'guest_ai_use_count';
const String kGuestAiUsageMonthKey = 'guest_ai_use_month';
const int kAuthDailyLimit = 10;
const int kGuestMonthlyLimit = 5;

final remainingAiUsesProvider = FutureProvider<int>((ref) async {
  // Watch user profile to refresh when usage changes
  ref.watch(userProfileProvider);
  return AiUsageService.getRemainingUses();
});

class AiUsageService {
  /// Returns the number of AI calls remaining for the current period.
  static Future<int> getRemainingUses() async {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null;

    if (isGuest) {
      return _getGuestRemaining();
    } else {
      return _getAuthRemaining(user.uid);
    }
  }

  /// Deducts AI credits. Defaults to 1.
  /// Returns `true` if allowed, `false` if the limit is already hit.
  static Future<bool> consume([int count = 1]) async {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null;

    if (isGuest) {
      return _consumeGuest(count);
    } else {
      return _consumeAuth(user.uid, count);
    }
  }

  // ── INTERNAL GUEST LOGIC (Monthly) ────────────────────────────────────────

  static Future<int> _getGuestRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final currentMonth = _monthStr();
    
    if ((prefs.getString(kGuestAiUsageMonthKey) ?? '') != currentMonth) {
      await prefs.setInt(kGuestAiUsageKey, 0);
      await prefs.setString(kGuestAiUsageMonthKey, currentMonth);
      return kGuestMonthlyLimit;
    }
    
    final used = prefs.getInt(kGuestAiUsageKey) ?? 0;
    return (kGuestMonthlyLimit - used).clamp(0, kGuestMonthlyLimit).toInt();
  }

  static Future<bool> _consumeGuest(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final currentMonth = _monthStr();
    
    if ((prefs.getString(kGuestAiUsageMonthKey) ?? '') != currentMonth) {
      await prefs.setInt(kGuestAiUsageKey, count);
      await prefs.setString(kGuestAiUsageMonthKey, currentMonth);
      return true;
    }
    
    final used = prefs.getInt(kGuestAiUsageKey) ?? 0;
    if (used + count > kGuestMonthlyLimit) return false;
    
    await prefs.setInt(kGuestAiUsageKey, used + count);
    return true;
  }

  // ── INTERNAL AUTH LOGIC (Daily) ──────────────────────────────────────────

  static Future<int> _getAuthRemaining(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    final today = _todayStr();
    
    final lastReset = data['smartLoggerLastResetDate'] ?? '';
    final used = lastReset == today ? (data['smartLoggerUsedToday'] ?? 0) : 0;
    
    return (kAuthDailyLimit - used).clamp(0, kAuthDailyLimit).toInt();
  }

  static Future<bool> _consumeAuth(String uid, int count) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await ref.get();
    final data = doc.data() ?? {};
    final today = _todayStr();
    
    final lastReset = data['smartLoggerLastResetDate'] ?? '';
    final used = lastReset == today ? (data['smartLoggerUsedToday'] ?? 0) : 0;
    
    if (used + count > kAuthDailyLimit) return false;
    
    await ref.update({
      'smartLoggerUsedToday': used + count,
      'smartLoggerLastResetDate': today,
    });
    return true;
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  static String _todayStr() => DateTime.now().toIso8601String().substring(0, 10);
  static String _monthStr() => DateTime.now().toIso8601String().substring(0, 7);
}
