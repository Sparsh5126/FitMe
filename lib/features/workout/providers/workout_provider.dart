import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/workout.dart';
import '../../../core/models/exercise.dart';
import '../repositories/workout_repository.dart';
import '../../gamification/services/fitpoints_service.dart';
import '../../notifications/notification_service.dart';
import '../../dashboard/providers/user_provider.dart';

final _repo = WorkoutRepository();

// ─────────────────────────────────────────────
// ACTIVE WORKOUT (stream from Firestore)
// ─────────────────────────────────────────────
final activeWorkoutProvider = StreamProvider<Workout?>((ref) {
  return _repo.watchActiveWorkout();
});

// ─────────────────────────────────────────────
// WORKOUT HISTORY
// ─────────────────────────────────────────────
final workoutHistoryProvider = StreamProvider<List<Workout>>((ref) {
  return _repo.watchWorkoutHistory();
});

// ─────────────────────────────────────────────
// EXERCISE LIBRARY
// ─────────────────────────────────────────────
final exerciseLibraryProvider = StreamProvider<List<Exercise>>((ref) {
  return _repo.watchExerciseLibrary();
});

// ─────────────────────────────────────────────
// PROGRESSION TREES (loaded from JSON)
// ─────────────────────────────────────────────
final progressionTreesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final jsonStr = await rootBundle.loadString('assets/progression_trees.json');
  final List data = jsonDecode(jsonStr);
  return data.cast<Map<String, dynamic>>();
});

// ─────────────────────────────────────────────
// WORKOUT ACTIONS
// ─────────────────────────────────────────────
final workoutActionsProvider = Provider<WorkoutActions>((ref) => WorkoutActions(ref));

class WorkoutActions {
  final Ref _ref;
  WorkoutActions(this._ref);

  // ── Session management ────────────────────

  Future<Workout> startWorkout(String name) async {
    return _repo.createWorkout(name);
  }

  Future<void> addExercise(Workout workout, Exercise exercise) async {
    final updated = workout.copyWith(
      exercises: [...workout.exercises, exercise],
    );
    await _repo.saveWorkout(updated);
  }

  Future<void> removeExercise(Workout workout, String exerciseId) async {
    final updated = workout.copyWith(
      exercises: workout.exercises.where((e) => e.id != exerciseId).toList(),
    );
    await _repo.saveWorkout(updated);
  }

  // ── Set management ────────────────────────

  // Mark a set complete with actual reps/weight
  Future<void> completeSet({
    required Workout workout,
    required String exerciseId,
    required int setIndex,
    required int reps,
    required double weight,
  }) async {
    final exIndex = workout.exercises.indexWhere((e) => e.id == exerciseId);
    if (exIndex == -1) return;

    final exercise = workout.exercises[exIndex];
    final updatedSets = List<ExerciseSet>.from(exercise.sets);
    updatedSets[setIndex] = updatedSets[setIndex].copyWith(
      actualReps: reps,
      actualWeight: weight,
      status: SetStatus.completed,
    );

    final updatedExercise = exercise.copyWith(sets: updatedSets);
    final updatedExercises = List<Exercise>.from(workout.exercises);
    updatedExercises[exIndex] = updatedExercise;

    final updatedWorkout = workout.copyWith(exercises: updatedExercises);
    await _repo.saveWorkout(updatedWorkout);

    // Check for top set → suggest progression
    if (updatedSets[setIndex].isTopSet && updatedExercise.hitTopSet) {
      await _suggestProgression(updatedExercise);
    }
  }

  // Add a new set to an exercise (auto-filled from previous)
  Future<void> addSet(Workout workout, String exerciseId) async {
    final exIndex = workout.exercises.indexWhere((e) => e.id == exerciseId);
    if (exIndex == -1) return;

    final exercise = workout.exercises[exIndex];
    final newSet = exercise.buildNextSet(exercise.sets.length + 1);
    final updatedExercise = exercise.copyWith(sets: [...exercise.sets, newSet]);
    final updatedExercises = List<Exercise>.from(workout.exercises);
    updatedExercises[exIndex] = updatedExercise;

    await _repo.saveWorkout(workout.copyWith(exercises: updatedExercises));
  }

  // ── Complete session ──────────────────────

  Future<Workout> finishWorkout(Workout workout) async {
    final completed = await _repo.completeWorkout(workout);
    final profile = _ref.read(userProfileProvider).value;

    // Check for any PRs
    final hasPR = workout.exercises.any((e) {
      final updated = e.withUpdatedPR();
      return (updated.prReps ?? 0) > (e.prReps ?? 0) ||
          (updated.prWeight ?? 0) > (e.prWeight ?? 0);
    });

    await FitPointsService.awardWorkout(isPR: hasPR);

    if (hasPR && profile != null) {
      await NotificationService.showCoachMemory(
        'New PR today! You\'re getting stronger every session. 💪',
      );
    }

    return completed;
  }

  Future<void> discardWorkout(Workout workout) async {
    await _repo.deleteWorkout(workout.id);
  }

  // ── Progression ───────────────────────────

  Future<void> _suggestProgression(Exercise exercise) async {
    if (exercise.progressionTreeId.isEmpty) return;

    final trees = await _ref.read(progressionTreesProvider.future);
    final tree = trees.cast<Map<String, dynamic>?>().firstWhere(
      (t) => t?['id'] == exercise.progressionTreeId,
      orElse: () => null,
    );
    if (tree == null) return;

    final levels = tree['levels'] as List;
    final nextLevelIndex = levels.indexWhere(
      (l) => (l['level'] as int) == exercise.currentProgressionLevel + 1,
    );
    if (nextLevelIndex == -1) return;

    final nextLevel = levels[nextLevelIndex] as Map<String, dynamic>;
    await NotificationService.showCoachMemory(
      '💡 Level Up! Try ${nextLevel['name']} (${nextLevel['reps']}) next session.',
    );
  }

  Future<void> levelUpExercise(String exerciseId, int newLevel) async {
    await _repo.updateProgressionLevel(exerciseId, newLevel);
  }

  // ── Exercise library ──────────────────────

  Future<void> saveExercise(Exercise exercise) async {
    await _repo.saveExercise(exercise);
  }

  Future<void> deleteExercise(String exerciseId) async {
    await _repo.deleteExercise(exerciseId);
  }

  // ── Weekly volume ──────────────────────────

  Future<Map<String, int>> getWeeklyVolume() async {
    return _repo.getWeeklyVolume();
  }
}

// ─────────────────────────────────────────────
// HELPER: Build exercise from progression tree
// ─────────────────────────────────────────────
Exercise exerciseFromTree(Map<String, dynamic> tree, int level) {
  final levels = tree['levels'] as List;
  final levelData = levels.firstWhere(
    (l) => (l['level'] as int) == level,
    orElse: () => levels.first,
  ) as Map<String, dynamic>;

  final topSet = levelData['topSet'] as Map<String, dynamic>;
  final sets = List.generate(
    topSet['sets'] as int,
    (i) => ExerciseSet(
      setNumber: i + 1,
      targetReps: topSet['reps'] as int,
      targetWeight: 0,
    ),
  );

  return Exercise(
    id: '${tree['id']}_${DateTime.now().millisecondsSinceEpoch}',
    name: levelData['name'] as String,
    muscleGroup: tree['muscle'] as String,
    progressionTreeId: tree['id'] as String,
    currentProgressionLevel: level,
    sets: sets,
    isBodyweight: true,
  );
}