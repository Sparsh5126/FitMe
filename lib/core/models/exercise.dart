class ExerciseSet {
  final int setNumber;
  final int targetReps;
  final double targetWeight;    // kg, 0 for bodyweight
  final int? actualReps;
  final double? actualWeight;
  final SetStatus status;
  final int restSeconds;        // planned rest after this set
  final int? actualRestSeconds; // how long they actually rested

  const ExerciseSet({
    required this.setNumber,
    required this.targetReps,
    this.targetWeight = 0,
    this.actualReps,
    this.actualWeight,
    this.status = SetStatus.pending,
    this.restSeconds = 90,
    this.actualRestSeconds,
  });

  // Volume for this set
  int get volume {
    final reps = actualReps ?? 0;
    final weight = actualWeight ?? targetWeight;
    // Bodyweight sets count reps only as volume
    return weight > 0 ? (reps * weight).round() : reps;
  }

  bool get isCompleted => status == SetStatus.completed;

  bool get isTopSet {
    // Top set = hit or exceeded target reps and weight
    if (actualReps == null) return false;
    return actualReps! >= targetReps &&
        (actualWeight ?? targetWeight) >= targetWeight;
  }

  Map<String, dynamic> toMap() {
    return {
      'setNumber': setNumber,
      'targetReps': targetReps,
      'targetWeight': targetWeight,
      'actualReps': actualReps,
      'actualWeight': actualWeight,
      'status': status.name,
      'restSeconds': restSeconds,
      'actualRestSeconds': actualRestSeconds,
    };
  }

  factory ExerciseSet.fromMap(Map<String, dynamic> map) {
    return ExerciseSet(
      setNumber: map['setNumber'] ?? 1,
      targetReps: map['targetReps'] ?? 10,
      targetWeight: (map['targetWeight'] ?? 0).toDouble(),
      actualReps: map['actualReps'],
      actualWeight: map['actualWeight']?.toDouble(),
      status: SetStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SetStatus.pending,
      ),
      restSeconds: map['restSeconds'] ?? 90,
      actualRestSeconds: map['actualRestSeconds'],
    );
  }

  ExerciseSet copyWith({
    int? actualReps,
    double? actualWeight,
    SetStatus? status,
    int? actualRestSeconds,
    int? restSeconds,
    double? targetWeight,
    int? targetReps,
  }) {
    return ExerciseSet(
      setNumber: setNumber,
      targetReps: targetReps ?? this.targetReps,
      targetWeight: targetWeight ?? this.targetWeight,
      actualReps: actualReps ?? this.actualReps,
      actualWeight: actualWeight ?? this.actualWeight,
      status: status ?? this.status,
      restSeconds: restSeconds ?? this.restSeconds,
      actualRestSeconds: actualRestSeconds ?? this.actualRestSeconds,
    );
  }
}

enum SetStatus { pending, active, completed, skipped }

// ─────────────────────────────────────────────

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String progressionTreeId; // maps to progression_trees.json id
  final int currentProgressionLevel;
  final List<ExerciseSet> sets;
  final bool isBodyweight;
  final String notes;

  // Personal records
  final int? prReps;            // most reps in a single set
  final double? prWeight;       // most weight in a single set

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.progressionTreeId = '',
    this.currentProgressionLevel = 1,
    required this.sets,
    this.isBodyweight = true,
    this.notes = '',
    this.prReps,
    this.prWeight,
  });

  int get totalVolume => sets.fold(0, (sum, s) => sum + s.volume);

  int get completedSets => sets.where((s) => s.isCompleted).length;

  bool get allSetsCompleted => sets.every((s) => s.isCompleted || s.status == SetStatus.skipped);

  // True if any set hit or exceeded the top set threshold for this progression level
  bool get hitTopSet => sets.any((s) => s.isTopSet);

  // Next set to do (first pending)
  ExerciseSet? get nextSet => sets.cast<ExerciseSet?>().firstWhere(
    (s) => s?.status == SetStatus.pending,
    orElse: () => null,
  );

  // Pre-fill next set based on previous set performance
  ExerciseSet buildNextSet(int setNumber) {
    final prev = sets.isNotEmpty ? sets.last : null;
    return ExerciseSet(
      setNumber: setNumber,
      targetReps: prev?.targetReps ?? 10,
      targetWeight: prev?.actualWeight ?? prev?.targetWeight ?? 0,
      restSeconds: _defaultRestSeconds(),
    );
  }

  int _defaultRestSeconds() {
    // Heavier compound: 120s, lighter: 90s
    if (!isBodyweight && (sets.isNotEmpty && (sets.last.targetWeight) > 20)) return 120;
    return 90;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'progressionTreeId': progressionTreeId,
      'currentProgressionLevel': currentProgressionLevel,
      'sets': sets.map((s) => s.toMap()).toList(),
      'isBodyweight': isBodyweight,
      'notes': notes,
      'prReps': prReps,
      'prWeight': prWeight,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      muscleGroup: map['muscleGroup'] ?? '',
      progressionTreeId: map['progressionTreeId'] ?? '',
      currentProgressionLevel: map['currentProgressionLevel'] ?? 1,
      sets: (map['sets'] as List? ?? [])
          .map((s) => ExerciseSet.fromMap(s as Map<String, dynamic>))
          .toList(),
      isBodyweight: map['isBodyweight'] ?? true,
      notes: map['notes'] ?? '',
      prReps: map['prReps'],
      prWeight: map['prWeight']?.toDouble(),
    );
  }

  Exercise copyWith({
    List<ExerciseSet>? sets,
    int? currentProgressionLevel,
    int? prReps,
    double? prWeight,
    String? notes,
  }) {
    return Exercise(
      id: id,
      name: name,
      muscleGroup: muscleGroup,
      progressionTreeId: progressionTreeId,
      currentProgressionLevel: currentProgressionLevel ?? this.currentProgressionLevel,
      sets: sets ?? this.sets,
      isBodyweight: isBodyweight,
      notes: notes ?? this.notes,
      prReps: prReps ?? this.prReps,
      prWeight: prWeight ?? this.prWeight,
    );
  }

  // Update PR if this session beat it
  Exercise withUpdatedPR() {
    final completedSets = sets.where((s) => s.isCompleted);
    if (completedSets.isEmpty) return this;

    final maxReps = completedSets.map((s) => s.actualReps ?? 0).reduce((a, b) => a > b ? a : b);
    final maxWeight = completedSets.map((s) => s.actualWeight ?? 0).reduce((a, b) => a > b ? a : b);

    final newPrReps = (prReps == null || maxReps > prReps!) ? maxReps : prReps;
    final newPrWeight = (prWeight == null || maxWeight > prWeight!) ? maxWeight : prWeight;

    return copyWith(prReps: newPrReps, prWeight: (newPrWeight != null && newPrWeight > 0) ? newPrWeight : null);
  }
}