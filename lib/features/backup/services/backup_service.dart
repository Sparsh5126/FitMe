import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Backup + Restore service.
/// - Guests: no-op (return false/empty)
/// - Logged in: write to Firestore, read back on new device
///
/// Backs up:
///   - nutrition_logs (meals)
///   - streak data
///   - recipe favorites
///   - custom meals
///   - profile settings
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
        'recipe_favorites': await _collectRecipeFavorites(uid),
        'custom_meals': await _collectCustomMeals(uid),
      };

      await _db.collection('backups').doc(uid).set(backup);
      return DateTime.now();
    } catch (e) {
      debugPrint('Backup failed: $e');
      return null;
    }
  }

  // ── Restore all data ─────────────────────────────────
  
  /// Restore all data components.
  Future<int> restoreAll() async {
    if (!_isLoggedIn) return 0;
    final uid = _uid!;

    try {
      final backup = await _db.collection('backups').doc(uid).get();
      if (!backup.exists) return 0;

      final data = backup.data()!;
      int count = 0;

      // Restore logs
      count += await _restoreCollection(uid, 'logs', data['nutrition_logs']);
      
      // Restore favorites
      count += await _restoreCollection(uid, 'favorites', data['recipe_favorites']);
      
      // Restore custom meals
      count += await _restoreCollection(uid, 'custom_meals', data['custom_meals']);
      
      // Restore streak
      await restoreStreakData();

      return count;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return 0;
    }
  }

  Future<int> _restoreCollection(String uid, String collectionName, dynamic items) async {
    if (items == null || items is! List || items.isEmpty) return 0;
    
    final batch = _db.batch();
    final colRef = _db.collection('users').doc(uid).collection(collectionName);
    
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        // Use ID if available, otherwise let Firestore generate
        final id = item['id'] ?? item['name']?.toString().toLowerCase().replaceAll(' ', '_');
        final ref = id != null ? colRef.doc(id) : colRef.doc();
        batch.set(ref, item);
      }
    }
    
    await batch.commit();
    return items.length;
  }

  /// Restore streak milestones + counts.
  Future<bool> restoreStreakData() async {
    if (!_isLoggedIn) return false;
    final uid = _uid!;

    try {
      final backup = await _db.collection('backups').doc(uid).get();
      if (!backup.exists) return false;

      final streakData =
          (backup.data()?['streak_data'] as Map?)?.cast<String, dynamic>() ??
          {};
      if (streakData.isEmpty) return false;

      await _db.collection('users').doc(uid).update(streakData);
      return true;
    } catch (e) {
      debugPrint('Restore streak failed: $e');
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
      debugPrint('Delete backup failed: $e');
      return false;
    }
  }

  // ── Check backup status ──────────────────────────────
  Future<BackupStatus?> getBackupStatus() async {
    if (!_isLoggedIn) return null;
    try {
      final backup = await _db.collection('backups').doc(_uid!).get();
      if (!backup.exists) return BackupStatus.noBackup();

      final data = backup.data()!;
      final ts = (data['timestamp'] as Timestamp?);
      
      int totalItems = 0;
      totalItems += (data['nutrition_logs'] as List? ?? []).length;
      totalItems += (data['recipe_favorites'] as List? ?? []).length;
      totalItems += (data['custom_meals'] as List? ?? []).length;

      return BackupStatus(
        lastBackup: ts?.toDate(),
        logsCount: totalItems,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _collectNutritionLogs(String uid) async {
    return _collectCollection(uid, 'logs');
  }

  Future<List<Map<String, dynamic>>> _collectRecipeFavorites(String uid) async {
    return _collectCollection(uid, 'favorites');
  }

  Future<List<Map<String, dynamic>>> _collectCustomMeals(String uid) async {
    return _collectCollection(uid, 'custom_meals');
  }

  Future<List<Map<String, dynamic>>> _collectCollection(String uid, String col) async {
    try {
      final snap = await _db.collection('users').doc(uid).collection(col).get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Failed to collect $col: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _collectStreakData(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
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
}

// ── Data class ─────────────────────────────────────────
class BackupStatus {
  final DateTime? lastBackup;
  final int logsCount;

  const BackupStatus({required this.lastBackup, required this.logsCount});

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
