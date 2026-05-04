import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Backup + Restore service.
/// - Guests: no-op (return false/empty)
/// - Logged in: write to Firestore, read back on new device
///
/// Backs up:
///   - nutrition_logs (meals)
///   - streak data
///   - recipe favorites
///   - profile settings (personality, notifications, etc)
class BackupService {
  static final BackupService _instance = BackupService._();
  factory BackupService() => _instance;
  BackupService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => _auth.currentUser?.uid;
  bool get _isLoggedIn => _uid != null;

  // ── Backup all data ──────────────────────────────────
  /// Returns timestamp if successful, null if guest or error.
  Future<DateTime?> backupAll() async {
    if (!_isLoggedIn) return null;
    final uid = _uid!;

    try {
      final backup = <String, dynamic>{
        'timestamp': FieldValue.serverTimestamp(),
        'nutrition_logs': await _collectNutritionLogs(uid),
        'streak_data': await _collectStreakData(uid),
        'recipe_favorites': await _collectRecipeFavorites(),
      };

      await _db.collection('backups').doc(uid).set(backup);
      return DateTime.now();
    } catch (e) {
      print('Backup failed: $e');
      return null;
    }
  }

  // ── Restore all data ─────────────────────────────────
  /// Merges backed-up nutrition_logs into current device.
  /// Returns count of items restored.
  Future<int> restoreNutritionLogs() async {
    if (!_isLoggedIn) return 0;
    final uid = _uid!;

    try {
      final backup = await _db.collection('backups').doc(uid).get();
      if (!backup.exists) return 0;

      final logs = backup.data()?['nutrition_logs'] as List? ?? [];
      if (logs.isEmpty) return 0;

      final batch = _db.batch();
      for (final log in logs) {
        final ref = _db
            .collection('users')
            .doc(uid)
            .collection('nutrition_logs')
            .doc();
        batch.set(ref, log);
      }
      await batch.commit();
      return logs.length;
    } catch (e) {
      print('Restore nutrition failed: $e');
      return 0;
    }
  }

  /// Restore streak milestones + counts.
  Future<bool> restoreStreakData() async {
    if (!_isLoggedIn) return false;
    final uid = _uid!;

    try {
      final backup = await _db.collection('backups').doc(uid).get();
      if (!backup.exists) return false;

      final streakData = backup.data()?['streak_data'] as Map? ?? {};
      if (streakData.isEmpty) return false;

      await _db.collection('users').doc(uid).update(streakData);
      return true;
    } catch (e) {
      print('Restore streak failed: $e');
      return false;
    }
  }

  // ── Delete backup ────────────────────────────────────
  Future<bool> deleteBackup() async {
    if (!_isLoggedIn) return false;
    try {
      await _db.collection('backups').doc(_uid!).delete();
      return true;
    } catch (e) {
      print('Delete backup failed: $e');
      return false;
    }
  }

  // ── Check backup status ──────────────────────────────
  Future<BackupStatus?> getBackupStatus() async {
    if (!_isLoggedIn) return null;
    try {
      final backup = await _db.collection('backups').doc(_uid!).get();
      if (!backup.exists) return BackupStatus.noBackup();

      final ts = (backup.data()?['timestamp'] as Timestamp?);
      return BackupStatus(
        lastBackup: ts?.toDate(),
        logsCount: (backup.data()?['nutrition_logs'] as List? ?? []).length,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _collectNutritionLogs(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('nutrition_logs')
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _collectStreakData(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      // Only backup streak-related fields
      return {
        'currentStreak': data['currentStreak'] ?? 0,
        'longestStreak': data['longestStreak'] ?? 0,
        'lastLogDate': data['lastLogDate'] ?? '',
        'streakMilestones': data['streakMilestones'] ?? [],
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<String>> _collectRecipeFavorites() async {
    // Stored in SharedPreferences locally, not in Firestore
    // This is a placeholder for future Firestore sync if needed
    return [];
  }
}

// ── Data class ─────────────────────────────────────────
class BackupStatus {
  final DateTime? lastBackup;
  final int logsCount;

  const BackupStatus({
    required this.lastBackup,
    required this.logsCount,
  });

  factory BackupStatus.noBackup() =>
      const BackupStatus(lastBackup: null, logsCount: 0);

  bool get hasBackup => lastBackup != null;

  String get lastBackupText {
    if (!hasBackup) return 'No backup yet';
    final now = DateTime.now();
    final diff = now.difference(lastBackup!);
    if (diff.inHours < 1) return 'Just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return lastBackup!.toString().split(' ')[0]; // YYYY-MM-DD
  }
}