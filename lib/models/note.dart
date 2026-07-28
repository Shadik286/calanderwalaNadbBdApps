import 'package:flutter/material.dart';

/// A note category with a built-in color and icon. Categories are stored
/// as a stable string id in JSON so they survive renames / reorderings.
enum NoteCategory {
  personal('personal', 'Personal', Icons.person_outline, Color(0xFF6C63FF)),
  work('work', 'Work', Icons.work_outline, Color(0xFF1E88E5)),
  birthday('birthday', 'Birthday', Icons.cake_outlined, Color(0xFFEC407A)),
  holiday('holiday', 'Holiday', Icons.beach_access_outlined, Color(0xFF26A69A)),
  task('task', 'Task', Icons.check_circle_outline, Color(0xFFFFA726)),
  health('health', 'Health', Icons.favorite_outline, Color(0xFFEF5350)),
  study('study', 'Study', Icons.school_outlined, Color(0xFF7E57C2)),
  other('other', 'Other', Icons.label_outline, Color(0xFF78909C));

  const NoteCategory(this.id, this.label, this.icon, this.color);

  final String id;
  final String label;
  final IconData icon;
  final Color color;

  static NoteCategory fromId(String? id) {
    return NoteCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => NoteCategory.other,
    );
  }
}

/// Lightweight priority hint. Drives sorting and a small badge in the UI.
enum NotePriority {
  none('none', 'No priority', 0),
  low('low', 'Low', 1),
  medium('medium', 'Medium', 2),
  high('high', 'High', 3);

  const NotePriority(this.id, this.label, this.weight);

  final String id;
  final String label;
  final int weight;

  static NotePriority fromId(String? id) {
    return NotePriority.values.firstWhere(
      (p) => p.id == id,
      orElse: () => NotePriority.none,
    );
  }
}

class Note {
  final String id;
  final DateTime date;
  final String title;
  final String description;
  final bool reminderEnabled;
  final DateTime? reminderTime;

  /// Optional category. Null means "uncategorized" (renders as Other).
  final NoteCategory category;

  /// Higher weight = more important. Drives sort order in lists.
  final NotePriority priority;

  /// Whether the user marked the note as completed. Only meaningful for
  /// category == task but stored on every note for flexibility.
  final bool completed;

  const Note({
    required this.id,
    required this.date,
    required this.title,
    required this.description,
    required this.reminderEnabled,
    this.reminderTime,
    this.category = NoteCategory.other,
    this.priority = NotePriority.none,
    this.completed = false,
  });

  /// Notification IDs must fit in a signed 32-bit int, so we derive one
  /// deterministically from the note's unique id instead of storing it.
  int get notificationId => id.hashCode & 0x7fffffff;

  /// Effective color used for category dots, headers, and category chips.
  Color get accentColor => category.color;

  Note copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? description,
    bool? reminderEnabled,
    DateTime? reminderTime,
    NoteCategory? category,
    NotePriority? priority,
    bool? completed,
    bool clearReminderTime = false,
  }) {
    return Note(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      description: description ?? this.description,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime:
          clearReminderTime ? null : (reminderTime ?? this.reminderTime),
      category: category ?? this.category,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'description': description,
        'reminderEnabled': reminderEnabled,
        'reminderTime': reminderTime?.toIso8601String(),
        'category': category.id,
        'priority': priority.id,
        'completed': completed,
      };

  /// Backward compatible: older notes stored without category/priority
  /// fields fall back to sensible defaults.
  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        reminderEnabled: json['reminderEnabled'] as bool? ?? false,
        reminderTime: json['reminderTime'] == null
            ? null
            : DateTime.parse(json['reminderTime'] as String),
        category: NoteCategory.fromId(json['category'] as String?),
        priority: NotePriority.fromId(json['priority'] as String?),
        completed: json['completed'] as bool? ?? false,
      );
}

/// Normalizes a DateTime to just its calendar day (strips time-of-day),
/// so notes can be grouped and compared by date regardless of time.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
