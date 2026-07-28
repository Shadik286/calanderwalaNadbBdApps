import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/note.dart';
import '../services/notes_repository.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/gradient_header.dart';
import '../widgets/note_card.dart';
import 'add_edit_note_screen.dart';

/// The main Home tab. Renders a greeting header, stats row, upcoming
/// reminders, the calendar with category-colored event dots, and the
/// list of notes for the selected day. When [embedded] is true the
/// screen is hosted inside [HomeShell] and skips the AppBar.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _repo = NotesRepository();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = dateOnly(DateTime.now());
  CalendarFormat _format = CalendarFormat.month;

  Map<DateTime, List<Note>> _notesByDay = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  List<Note> get _allNotes => _notesByDay.values.expand((e) => e).toList();

  Future<void> _loadNotes() async {
    final notes = await _repo.loadAll();
    final grouped = <DateTime, List<Note>>{};
    for (final note in notes) {
      final key = dateOnly(note.date);
      grouped.putIfAbsent(key, () => []).add(note);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final taskCompare =
            (a.completed ? 1 : 0).compareTo(b.completed ? 1 : 0);
        if (taskCompare != 0) return taskCompare;
        final byPriority = b.priority.weight.compareTo(a.priority.weight);
        if (byPriority != 0) return byPriority;
        final at = a.reminderTime;
        final bt = b.reminderTime;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      });
    }
    if (!mounted) return;
    setState(() {
      _notesByDay = grouped;
      _loading = false;
    });
  }

  List<Note> _notesFor(DateTime day) =>
      _notesByDay[dateOnly(day)] ?? const [];

  Future<void> _openAddEdit({Note? note, DateTime? forDate}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditNoteScreen(
          initialDate: forDate ?? _selectedDay,
          existingNote: note,
        ),
      ),
    );
    if (result == true) {
      await _loadNotes();
    }
  }

  Future<void> _deleteNote(Note note) async {
    await _repo.delete(note.id);
    await NotificationService.instance.cancelReminder(note);
    await _loadNotes();
  }

  Future<void> _toggleComplete(Note note, bool value) async {
    final updated = note.copyWith(completed: value);
    await _repo.upsert(updated);
    if (value) {
      await NotificationService.instance.cancelReminder(updated);
    } else if (updated.reminderEnabled && updated.reminderTime != null) {
      await NotificationService.instance.scheduleReminder(updated);
    }
    await _loadNotes();
  }

  Color _accentColorFor(DateTime day) {
    final notes = _notesFor(day);
    if (notes.isEmpty) return Theme.of(context).colorScheme.primary;
    final sorted = [...notes]
      ..sort((a, b) => b.priority.weight.compareTo(a.priority.weight));
    return sorted.first.accentColor;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Working late';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = _loading ? null : _repo.stats(_allNotes);
    final upcoming =
        _loading ? const <Note>[] : _repo.upcomingReminders(_allNotes);
    final selectedNotes = _notesFor(_selectedDay);
    final today = dateOnly(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEdit(forDate: _selectedDay),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotes,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Greeting + gradient header.
            SliverToBoxAdapter(
              child: GradientHeader(
                height: 160,
                title: _greeting(),
                subtitle:
                    '${DateFormat('EEEE, MMM d').format(DateTime.now())} • ${selectedNotes.length} note${selectedNotes.length == 1 ? '' : 's'} today',
                trailing: IconButton(
                  tooltip: 'Add note',
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  onPressed: () => _openAddEdit(forDate: _selectedDay),
                ),
              ),
            ),
            // Stats row (loading placeholder when not yet ready).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _StatsRow(stats: stats),
              ),
            ),
            // Upcoming reminders card.
            if (upcoming.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _UpcomingCard(
                    notes: upcoming,
                    onTap: (n) => _openAddEdit(note: n, forDate: n.date),
                  ),
                ),
              ),
            // Calendar.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
                child: Material(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: scheme.outlineVariant.withOpacity(0.4),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TableCalendar<Note>(
                      firstDay: DateTime.utc(2015, 1, 1),
                      lastDay: DateTime.utc(2035, 12, 31),
                      focusedDay: _focusedDay,
                      currentDay: today,
                      rowHeight: 46,
                      daysOfWeekHeight: 24,
                      selectedDayPredicate: (day) =>
                          dateOnly(day) == _selectedDay,
                      calendarFormat: _format,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month',
                        CalendarFormat.twoWeeks: '2 weeks',
                        CalendarFormat.week: 'Week',
                      },
                      onFormatChanged: (format) =>
                          setState(() => _format = format),
                      eventLoader: _notesFor,
                      onDaySelected: (selected, focused) {
                        if (!isSameDay(selected, _selectedDay)) {
                          setState(() {
                            _selectedDay = dateOnly(selected);
                            _focusedDay = focused;
                          });
                        } else {
                          setState(() => _focusedDay = focused);
                        }
                      },
                      onPageChanged: (focused) => _focusedDay = focused,
                      calendarBuilders: CalendarBuilders<Note>(
                        markerBuilder: (context, day, notes) {
                          if (notes.isEmpty) return const SizedBox.shrink();
                          final color = _accentColorFor(day);
                          final visible = notes.length > 3
                              ? notes.take(3).toList()
                              : notes;
                          return Positioned(
                            bottom: 4,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: visible.map((n) {
                                return Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: n.accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        cellMargin: const EdgeInsets.all(4),
                        todayDecoration: BoxDecoration(
                          color: _accentColorFor(today).withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: TextStyle(
                          color: _accentColorFor(today),
                          fontWeight: FontWeight.w700,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: AppPalette.seed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.seed.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        weekendTextStyle: TextStyle(
                          color: scheme.onSurface.withOpacity(0.7),
                        ),
                        defaultTextStyle: TextStyle(color: scheme.onSurface),
                        markersMaxCount: 0,
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonShowsNext: false,
                        titleCentered: true,
                        formatButtonDecoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        formatButtonTextStyle: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                        titleTextStyle: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left_rounded,
                          color: scheme.onSurface,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurface,
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        weekendStyle: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Selected-day notes list.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: SectionHeader(
                  icon: Icons.event_note_outlined,
                  title: DateFormat('EEEE, MMM d').format(_selectedDay),
                  subtitle:
                      '${selectedNotes.length} note${selectedNotes.length == 1 ? '' : 's'}',
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (selectedNotes.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'Nothing planned',
                    message:
                        'Tap the + button to add a note for ${DateFormat('MMM d').format(_selectedDay)}.',
                    action: FilledButton.icon(
                      onPressed: () => _openAddEdit(forDate: _selectedDay),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add note'),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList.separated(
                  itemCount: selectedNotes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final note = selectedNotes[index];
                    return Dismissible(
                      key: ValueKey('cal-${note.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete note?'),
                                content: Text(
                                  'Delete "${note.title}" and its reminder?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      onDismissed: (_) => _deleteNote(note),
                      child: NoteCard(
                        note: note,
                        onTap: () =>
                            _openAddEdit(note: note, forDate: _selectedDay),
                        onLongPress: () => _deleteNote(note),
                        onToggleComplete: (v) => _toggleComplete(note, v),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact horizontal row of stat cards on the home dashboard.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final NoteStats? stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = this.stats;
    if (stats == null) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final cards = <_StatTile>[
      _StatTile(
        label: 'Total notes',
        value: '${stats.total}',
        icon: Icons.sticky_note_2_outlined,
        color: AppPalette.seed,
      ),
      _StatTile(
        label: 'Tasks done',
        value: '${stats.tasksCompleted}/${stats.tasksTotal}',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF10B981),
        progress: stats.taskProgress,
      ),
      _StatTile(
        label: 'Upcoming',
        value: '${stats.upcomingReminders}',
        icon: Icons.notifications_active_outlined,
        color: AppPalette.accent,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.progress,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Up next" card — quick access to the next few scheduled reminders.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.notes, required this.onTap});

  final List<Note> notes;
  final ValueChanged<Note> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withOpacity(0.95),
            scheme.tertiary.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Up next',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${notes.length} reminder${notes.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onTap(n),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(n.category.icon, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title.isEmpty
                                    ? '(Untitled reminder)'
                                    : n.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('EEE, MMM d • h:mm a')
                                    .format(n.reminderTime!),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
