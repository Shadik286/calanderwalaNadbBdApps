import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

/// Stores notes as a JSON-encoded list in SharedPreferences.
/// Simple on-device persistence — no server, no sync.
class NotesRepository {
  static const _storageKey = 'calendar_wala_notes';

  Future<List<Note>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    return raw
        .map((s) => Note.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAll(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = notes.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_storageKey, raw);
  }

  Future<void> upsert(Note note) async {
    final notes = await loadAll();
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      notes[index] = note;
    } else {
      notes.add(note);
    }
    await _saveAll(notes);
  }

  Future<void> delete(String id) async {
    final notes = await loadAll();
    notes.removeWhere((n) => n.id == id);
    await _saveAll(notes);
  }

  /// Bulk delete (used for cleanup / category filters).
  Future<void> deleteMany(Iterable<String> ids) async {
    final notes = await loadAll();
    notes.removeWhere((n) => ids.contains(n.id));
    await _saveAll(notes);
  }

  /// Toggle completion for tasks. Returns the updated note (or null if
  /// the id was not found).
  Future<Note?> toggleCompleted(String id) async {
    final notes = await loadAll();
    final index = notes.indexWhere((n) => n.id == id);
    if (index < 0) return null;
    final updated = notes[index].copyWith(completed: !notes[index].completed);
    notes[index] = updated;
    await _saveAll(notes);
    return updated;
  }

  /// Case-insensitive substring search across title and description.
  /// Empty query returns the full list.
  List<Note> search(List<Note> source, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.description.toLowerCase().contains(q);
    }).toList();
  }

  /// Filter notes by a single category.
  List<Note> byCategory(List<Note> source, NoteCategory category) {
    return source.where((n) => n.category == category).toList();
  }

  /// Notes whose reminder is enabled and still in the future. Sorted
  /// soonest first. Used by the home dashboard.
  List<Note> upcomingReminders(List<Note> source, {int limit = 5}) {
    final now = DateTime.now();
    final list = source.where((n) {
      return n.reminderEnabled &&
          n.reminderTime != null &&
          n.reminderTime!.isAfter(now);
    }).toList()
      ..sort((a, b) => a.reminderTime!.compareTo(b.reminderTime!));
    if (list.length > limit) return list.sublist(0, limit);
    return list;
  }

  /// Count how many notes fall on each date — drives calendar dots.
  Map<DateTime, int> countByDay(List<Note> source) {
    final out = <DateTime, int>{};
    for (final n in source) {
      final key = dateOnly(n.date);
      out.update(key, (v) => v + 1, ifAbsent: () => 1);
    }
    return out;
  }

  /// Per-category counts, used by the categories grid.
  Map<NoteCategory, int> countsByCategory(List<Note> source) {
    final out = <NoteCategory, int>{};
    for (final c in NoteCategory.values) {
      out[c] = 0;
    }
    for (final n in source) {
      out.update(n.category, (v) => v + 1, ifAbsent: () => 1);
    }
    return out;
  }

  /// Lightweight stats shown on the home dashboard.
  NoteStats stats(List<Note> source) {
    final now = DateTime.now();
    final today = dateOnly(now);
    final tasksCompleted = source
        .where((n) => n.category == NoteCategory.task && n.completed)
        .length;
    final tasksTotal = source.where((n) => n.category == NoteCategory.task).length;
    final upcoming = source.where((n) =>
        n.reminderEnabled && n.reminderTime != null && n.reminderTime!.isAfter(now)).length;
    final hasToday = source.any((n) => dateOnly(n.date) == today);
    return NoteStats(
      total: source.length,
      tasksCompleted: tasksCompleted,
      tasksTotal: tasksTotal,
      upcomingReminders: upcoming,
      hasAnyToday: hasToday,
    );
  }
}

class NoteStats {
  const NoteStats({
    required this.total,
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.upcomingReminders,
    required this.hasAnyToday,
  });

  final int total;
  final int tasksCompleted;
  final int tasksTotal;
  final int upcomingReminders;
  final bool hasAnyToday;

  double get taskProgress =>
      tasksTotal == 0 ? 0 : tasksCompleted / tasksTotal;
}
