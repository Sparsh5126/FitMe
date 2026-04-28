import 'exercise.dart';

class Workout {
  final String id;
  final String name;
  final List<Exercise> exercises;
  final String dateString;      // YYYY-MM-DD
  final int startTimestamp;
  final int? endTimestamp;
  final bool isCompleted;
  final int totalVolume;        // sum of all reps × weight across session
  final int totalSets;
  final String notes;

  Workout({
    required this.id,
    required this.name,
    required this.exercises,
    String? dateString,
    int? startTimestamp,
    this.endTimestamp,
    this.isCompleted = false,
    this.totalVolume = 0,
    this.totalSets = 0,
    this.notes = '',
  })  : dateString = dateString ?? _today(),
        startTimestamp = startTimestamp ?? DateTime.now().millisecondsSinceEpoch;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int get durationMinutes {
    if (endTimestamp == null) return 0;
    return ((endTimestamp! - startTimestamp) / 60000).round();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'dateString': dateString,
      'startTimestamp': startTimestamp,
      'endTimestamp': endTimestamp,
      'isCompleted': isCompleted,
      'totalVolume': totalVolume,
      'totalSets': totalSets,
      'notes': notes,
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Workout',
      exercises: (map['exercises'] as List? ?? [])
          .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
          .toList(),
      dateString: map['dateString'] ?? _today(),
      startTimestamp: map['startTimestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      endTimestamp: map['endTimestamp'],
      isCompleted: map['isCompleted'] ?? false,
      totalVolume: map['totalVolume'] ?? 0,
      totalSets: map['totalSets'] ?? 0,
      notes: map['notes'] ?? '',
    );
  }

  Workout copyWith({
    List<Exercise>? exercises,
    int? endTimestamp,
    bool? isCompleted,
    int? totalVolume,
    int? totalSets,
    String? notes,
    String? name,
  }) {
    return Workout(
      id: id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      dateString: dateString,
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      isCompleted: isCompleted ?? this.isCompleted,
      totalVolume: totalVolume ?? this.totalVolume,
      totalSets: totalSets ?? this.totalSets,
      notes: notes ?? this.notes,
    );
  }
}