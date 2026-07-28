import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/notes_repository.dart';
import '../services/notification_service.dart';
import '../widgets/gradient_header.dart';
import '../widgets/note_card.dart';
import 'add_edit_note_screen.dart';

/// Two-tab "Categories" screen:
/// 1. Overview — colorful grid of categories with per-bucket counts.
/// 2. Filtered notes view — appears when a category tile is tapped.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _repo = NotesRepository();

  List<Note> _all = const [];
  bool _loading = true;

  NoteCategory? _selectedCategory;
  bool _showCompletedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await _repo.loadAll();
    if (!mounted) return;
    setState(() {
      _all = notes;
      _loading = false;
    });
  }

  Map<NoteCategory, int> get _counts {
    final map = <NoteCategory, int>{};
    for (final c in NoteCategory.values) {
      map[c] = 0;
    }
    for (final n in _all) {
      map.update(n.category, (v) => v + 1, ifAbsent: () => 1);
    }
    return map;
  }

  List<Note> get _filtered {
    if (_selectedCategory == null) return const [];
    var list =
        _all.where((n) => n.category == _selectedCategory).toList();
    if (_showCompletedOnly && _selectedCategory == NoteCategory.task) {
      list = list.where((n) => n.completed).toList();
    } else if (_selectedCategory == NoteCategory.task) {
      list = list.where((n) => !n.completed).toList();
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
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

  Future<void> _delete(Note note) async {
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
    if (_selectedCategory == null) {
      return _buildOverview(context);
    }
    return _buildCategoryDetail(context);
  }

  Widget _buildOverview(BuildContext context) {
    final counts = _counts;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: GradientHeader(
                height: 130,
                title: 'Categories',
                subtitle: 'Browse notes by their type',
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final c = NoteCategory.values[i];
                      final count = counts[c] ?? 0;
                      return _categoryTile(
                        context,
                        c,
                        count,
                        onTap: () =>
                            setState(() => _selectedCategory = c),
                      );
                    },
                    childCount: NoteCategory.values.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => AddEditNoteScreen(
                initialDate: DateTime.now(),
              ),
            ),
          );
          if (result == true) await _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
    );
  }

  Widget _categoryTile(
    BuildContext context,
    NoteCategory category,
    int count, {
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  category.icon,
                  color: category.color,
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                category.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count note${count == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _all.isEmpty
                      ? 0
                      : (count / _all.length).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: category.color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(category.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDetail(BuildContext context) {
    final category = _selectedCategory!;
    final notes = _filtered;
    final counts = _counts;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Detail header — same gradient for continuity.
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [category.color.withOpacity(0.95), category.color],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        onPressed: () =>
                            setState(() => _selectedCategory = null),
                      ),
                      const Spacer(),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            category.icon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${counts[category] ?? 0} note${(counts[category] ?? 0) == 1 ? '' : 's'} total',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (category == NoteCategory.task)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Active'),
                      selected: !_showCompletedOnly,
                      onSelected: (_) =>
                          setState(() => _showCompletedOnly = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Completed'),
                      selected: _showCompletedOnly,
                      onSelected: (_) =>
                          setState(() => _showCompletedOnly = true),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : notes.isEmpty
                      ? EmptyState(
                          icon: category.icon,
                          title: 'No ${category.label.toLowerCase()} notes',
                          message:
                              'Tap the + button to create one in this category.',
                          action: FilledButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add note'),
                            onPressed: () async {
                              final result = await Navigator.of(context)
                                  .push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => AddEditNoteScreen(
                                    initialDate: DateTime.now(),
                                  ),
                                ),
                              );
                              if (result == true) await _load();
                            },
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: notes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final n = notes[index];
                            return NoteCard(
                              note: n,
                              onTap: () => _openEdit(n),
                              onLongPress: () => _delete(n),
                              onToggleComplete: (v) =>
                                  _toggleComplete(n, v),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: category.color,
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => AddEditNoteScreen(
                initialDate: DateTime.now(),
                presetCategory: category,
              ),
            ),
          );
          if (result == true) await _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
    );
  }
}