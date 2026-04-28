import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/workout.dart';
import '../../../core/models/exercise.dart';

class WorkoutRepository {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference get _workouts =>
      _db.collection('users').doc(_uid).collection('workouts');

  CollectionReference get _exercises =>
      _db.collection('users').doc(_uid).collection('exercises');

  // ─────────────────────────────────────────
  // WORKOUTS
  // ─────────────────────────────────────────

  // Watch active (incomplete) workout for today
  Stream<Workout?> watchActiveWorkout() {
    final today = _today();
    return _workouts
        .where('dateString', isEqualTo: today)
        .where('isCompleted', isEqualTo: false)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return Workout.fromMap(snap.docs.first.data() as Map<String, dynamic>);
    });
  }

  Stream<List<Workout>> watchWorkoutHistory() {
    return _workouts
        .where('isCompleted', isEqualTo: true)
        .orderBy('startTimestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Workout.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<Workout?> getWorkoutById(String id) async {
    final doc = await _workouts.doc(id).get();
    if (!doc.exists) return null;
    return Workout.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<List<Workout>> getWorkoutsForDate(String dateString) async {
    final snap = await _workouts
        .where('dateString', isEqualTo: dateString)
        .where('isCompleted', isEqualTo: true)
        .get();
    return snap.docs
        .map((d) => Workout.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  // Create new workout session
  Future<Workout> createWorkout(String name) async {
    final id = 'workout_${DateTime.now().millisecondsSinceEpoch}';
    final workout = Workout(id: id, name: name, exercises: []);
    await _workouts.doc(id).set(workout.toMap());
    return workout;
  }

  // Save full workout state (called frequently during active session)
  Future<void> saveWorkout(Workout workout) async {
    await _workouts.doc(workout.id).set(workout.toMap());
  }

  // Complete workout — calculates totals and saves
  Future<Workout> completeWorkout(Workout workout) async {
    int totalVolume = 0;
    int totalSets = 0;

    for (final ex in workout.exercises) {
      totalVolume += ex.totalVolume;
      totalSets += ex.completedSets;
    }

    final completed = workout.copyWith(
      isCompleted: true,
      endTimestamp: DateTime.now().millisecondsSinceEpoch,
      totalVolume: totalVolume,
      totalSets: totalSets,
    );

    await _workouts.doc(completed.id).set(completed.toMap());

    // Update workoutsCompleted counter on user doc
    await _db.collection('users').doc(_uid).update({
      'workoutsCompleted': FieldValue.increment(1),
    });

    // Update PRs for each exercise
    for (final ex in workout.exercises) {
      await _updateExercisePR(ex.withUpdatedPR());
    }

    return completed;
  }

  Future<void> deleteWorkout(String id) async {
    await _workouts.doc(id).delete();
  }

  // ─────────────────────────────────────────
  // EXERCISES (persistent across sessions)
  // Stores per-exercise history and PRs
  // ─────────────────────────────────────────

  Stream<List<Exercise>> watchExerciseLibrary() {
    return _exercises
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Exercise.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<List<Exercise>> getExerciseLibrary() async {
    final snap = await _exercises.orderBy('name').get();
    return snap.docs
        .map((d) => Exercise.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveExercise(Exercise exercise) async {
    await _exercises.doc(exercise.id).set(exercise.toMap());
  }

  Future<void> deleteExercise(String id) async {
    await _exercises.doc(id).delete();
  }

  // Update progression level when user levels up
  Future<void> updateProgressionLevel(String exerciseId, int newLevel) async {
    await _exercises.doc(exerciseId).update({
      'currentProgressionLevel': newLevel,
    });
  }

  Future<void> _updateExercisePR(Exercise exercise) async {
    final existing = await _exercises.doc(exercise.id).get();
    if (!existing.exists) {
      await _exercises.doc(exercise.id).set(exercise.toMap());
      return;
    }

    final existingData = existing.data() as Map<String, dynamic>;
    final existingPrReps = existingData['prReps'] as int? ?? 0;
    final existingPrWeight = (existingData['prWeight'] as num?)?.toDouble() ?? 0;

    final updates = <String, dynamic>{};
    if ((exercise.prReps ?? 0) > existingPrReps) updates['prReps'] = exercise.prReps;
    if ((exercise.prWeight ?? 0) > existingPrWeight) updates['prWeight'] = exercise.prWeight;

    if (updates.isNotEmpty) await _exercises.doc(exercise.id).update(updates);
  }

  // ─────────────────────────────────────────
  // VOLUME HISTORY (for insights)
  // ─────────────────────────────────────────
  Future<Map<String, int>> getWeeklyVolume() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayStr = _dateFor(monday);

    final snap = await _workouts
        .where('dateString', isGreaterThanOrEqualTo: mondayStr)
        .where('isCompleted', isEqualTo: true)
        .get();

    final result = <String, int>{};
    for (final doc in snap.docs) {
      final w = Workout.fromMap(doc.data() as Map<String, dynamic>);
      result[w.dateString] = (result[w.dateString] ?? 0) + w.totalVolume;
    }
    return result;
  }

  static String _today() {
    final now = DateTime.now();
    return _dateFor(now);
  }

  static String _dateFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}