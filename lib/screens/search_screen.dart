import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../services/notes_repository.dart';
import '../services/notification_service.dart';
import '../widgets/gradient_header.dart';
import '../widgets/note_card.dart';
import 'add_edit_note_screen.dart';

/// Full-text search across all notes with optional category and date
/// filters. Results update reactively as the user types.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _repo = NotesRepository();
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();

  List<Note> _all = const [];
  bool _loading = true;
  String _query = '';
  NoteCategory? _categoryFilter;
  DateTime? _dateFilter;
  bool _onlyWithReminders = false;

  @override
  void initState() {
    super.initState();
    _load();
    _queryController.addListener(() {
      setState(() => _query = _queryController.text);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final notes = await _repo.loadAll();
    if (!mounted) return;
    setState(() {
      _all = notes;
      _loading = false;
    });
  }

  List<Note> get _filtered {
    Iterable<Note> out = _all;
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      out = out.where((n) =>
          n.title.toLowerCase().contains(q) ||
          n.description.toLowerCase().contains(q));
    }
    if (_categoryFilter != null) {
      out = out.where((n) => n.category == _categoryFilter);
    }
    if (_dateFilter != null) {
      final target = dateOnly(_dateFilter!);
      out = out.where((n) => dateOnly(n.date) == target);
    }
    if (_onlyWithReminders) {
      out = out.where((n) => n.reminderEnabled);
    }
    final list = out.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  void _clearFilters() {
    setState(() {
      _categoryFilter = null;
      _dateFilter = null;
      _onlyWithReminders = false;
    });
  }

  Future<void> _openEdit(Note note) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditNoteScreen(
          initialDate: note.date,
          existingNote: note,
        ),
      ),
    );
    if (result == true) {
      await _load();
    }
  }

  Future<void> _deleteNote(Note note) async {
    await _repo.delete(note.id);
    await NotificationService.instance.cancelReminder(note);
    await _load();
  }

  Future<void> _toggleComplete(Note note, bool v) async {
    final updated = note.copyWith(completed: v);
    await _repo.upsert(updated);
    if (v) {
      await NotificationService.instance.cancelReminder(updated);
    } else if (updated.reminderEnabled && updated.reminderTime != null) {
      await NotificationService.instance.scheduleReminder(updated);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results = _filtered;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Gradient header with search field.
            GradientHeader(
              height: 130,
              title: 'Search',
              subtitle:
                  _query.isEmpty && !_hasFilter
                      ? 'Find any note by title or content'
                      : '${results.length} result${results.length == 1 ? '' : 's'}',
              trailing: _query.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white),
                      onPressed: () => _queryController.clear(),
                    )
                  : null,
            ),
            // Search bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Icon(
                        Icons.search_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Search notes…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16),
                          filled: false,
                          hintStyle: TextStyle(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _queryController.clear,
                      ),
                  ],
                ),
              ),
            ),
            // Filter chips.
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                children: [
                  _filterChip(
                    label: _dateFilter == null
                        ? 'Any date'
                        : DateFormat('MMM d').format(_dateFilter!),
                    icon: Icons.event_rounded,
                    selected: _dateFilter != null,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dateFilter ?? DateTime.now(),
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _dateFilter = dateOnly(picked));
                      }
                    },
                    onClear:
                        _dateFilter == null ? null : () => setState(() => _dateFilter = null),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    label: 'Has reminder',
                    icon: Icons.notifications_active_outlined,
                    selected: _onlyWithReminders,
                    onTap: () =>
                        setState(() => _onlyWithReminders = !_onlyWithReminders),
                  ),
                  const SizedBox(width: 8),
                  for (final c in NoteCategory.values) ...[
                    _filterChip(
                      label: c.label,
                      icon: c.icon,
                      selected: _categoryFilter == c,
                      color: c.color,
                      onTap: () => setState(() => _categoryFilter =
                          _categoryFilter == c ? null : c),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (_hasFilter)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reset'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Results.
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                      ? EmptyState(
                          icon: _query.isEmpty
                              ? Icons.search_rounded
                              : Icons.search_off_rounded,
                          title: _query.isEmpty && !_hasFilter
                              ? 'Search your notes'
                              : 'No results',
                          message: _query.isEmpty && !_hasFilter
                              ? 'Type a title, keyword, or pick a category to find notes.'
                              : 'Try a different keyword or clear your filters.',
                          action: _query.isEmpty
                              ? null
                              : FilledButton.tonal(
                                  onPressed: () {
                                    _queryController.clear();
                                    _clearFilters();
                                  },
                                  child: const Text('Clear filters'),
                                ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final note = results[index];
                            return NoteCard(
                              note: note,
                              onTap: () => _openEdit(note),
                              onLongPress: () => _deleteNote(note),
                              onToggleComplete: (v) =>
                                  _toggleComplete(note, v),
                              showDate: true,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasFilter =>
      _categoryFilter != null || _dateFilter != null || _onlyWithReminders;

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    Color? color,
    VoidCallback? onClear,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.18) : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c : scheme.outlineVariant.withOpacity(0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? c : scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? c : scheme.onSurface,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 14, color: c),
              ),
            ],
          ],
        ),
      ),
    );
  }
}