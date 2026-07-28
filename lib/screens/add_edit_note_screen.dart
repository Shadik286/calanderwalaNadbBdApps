import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import '../services/notes_repository.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/gradient_header.dart';

/// Add or edit a note. Builds a nicer form with category chips, priority
/// pills, a date picker row, and an inline reminder card.
class AddEditNoteScreen extends StatefulWidget {
  const AddEditNoteScreen({
    super.key,
    required this.initialDate,
    this.existingNote,
    this.presetCategory,
  });

  final DateTime initialDate;
  final Note? existingNote;

  /// Optional default category for new notes. Ignored when editing.
  final NoteCategory? presetCategory;

  @override
  State<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends State<AddEditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = NotesRepository();
  final _titleFocus = FocusNode();
  final _descFocus = FocusNode();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late DateTime _date;
  late bool _reminderEnabled;
  late TimeOfDay _reminderTimeOfDay;
  late NoteCategory _category;
  late NotePriority _priority;
  late bool _completed;
  bool _saving = false;

  bool get _isEditing => widget.existingNote != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingNote;
    final defaults = SettingsService.instance.value;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descController = TextEditingController(text: existing?.description ?? '');
    _date = dateOnly(existing?.date ?? widget.initialDate);
    _reminderEnabled = existing?.reminderEnabled ?? false;
    final existingTime = existing?.reminderTime;
    if (existingTime != null) {
      _reminderTimeOfDay =
          TimeOfDay(hour: existingTime.hour, minute: existingTime.minute);
    } else {
      _reminderTimeOfDay = TimeOfDay(
        hour: defaults.defaultReminderHour,
        minute: defaults.defaultReminderMinute,
      );
    }
    _category = existing?.category ??
        widget.presetCategory ??
        NoteCategory.personal;
    _priority = existing?.priority ?? NotePriority.none;
    _completed = existing?.completed ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _date = dateOnly(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTimeOfDay,
    );
    if (picked != null) {
      setState(() => _reminderTimeOfDay = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final reminderDateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _reminderTimeOfDay.hour,
      _reminderTimeOfDay.minute,
    );

    final note = Note(
      id: widget.existingNote?.id ?? const Uuid().v4(),
      date: _date,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      reminderEnabled: _reminderEnabled,
      reminderTime: _reminderEnabled ? reminderDateTime : null,
      category: _category,
      priority: _priority,
      completed: _completed,
    );

    await _repo.upsert(note);
    if (_reminderEnabled && !_completed) {
      await NotificationService.instance.scheduleReminder(note);
    } else {
      await NotificationService.instance.cancelReminder(note);
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final note = widget.existingNote;
    if (note == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('Delete "${note.title}" and its reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.delete(note.id);
    await NotificationService.instance.cancelReminder(note);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 110,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                if (_isEditing)
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: _delete,
                  ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: GradientHeader(
                  height: 110,
                  title: _isEditing ? 'Edit note' : 'New note',
                  subtitle:
                      DateFormat('EEEE, MMM d, yyyy').format(_date),
                  leading: const SizedBox.shrink(),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Title.
                  TextFormField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _descFocus.requestFocus(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'What is this note about?',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Please enter a title'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  // Description.
                  TextFormField(
                    controller: _descController,
                    focusNode: _descFocus,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Add details, links, anything…',
                      alignLabelWithHint: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 22),
                  // Category chips.
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: NoteCategory.values.map((c) {
                      final selected = c == _category;
                      return GestureDetector(
                        onTap: () => setState(() => _category = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? c.color.withOpacity(0.18)
                                : scheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? c.color
                                  : scheme.outlineVariant.withOpacity(0.5),
                              width: selected ? 1.6 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(c.icon,
                                  size: 16,
                                  color: selected
                                      ? c.color
                                      : scheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(
                                c.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? c.color
                                      : scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  // Priority pills.
                  Text(
                    'Priority',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: NotePriority.values.map((p) {
                      final selected = p == _priority;
                      final color = switch (p) {
                        NotePriority.high => const Color(0xFFEF4444),
                        NotePriority.medium => const Color(0xFFF59E0B),
                        NotePriority.low => const Color(0xFF10B981),
                        NotePriority.none => scheme.onSurfaceVariant,
                      };
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _priority = p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color.withOpacity(0.18)
                                    : scheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? color
                                      : scheme.outlineVariant.withOpacity(0.5),
                                  width: selected ? 1.6 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                p.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? color
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  // Date + reminder card.
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: scheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppPalette.seed.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.event_rounded,
                              color: AppPalette.seed,
                              size: 18,
                            ),
                          ),
                          title: const Text('Date'),
                          subtitle: Text(
                            DateFormat('EEEE, MMM d, yyyy').format(_date),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _pickDate,
                        ),
                        const Divider(height: 1, indent: 64),
                        SwitchListTile(
                          secondary: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppPalette.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.notifications_active_outlined,
                              color: AppPalette.accent,
                              size: 18,
                            ),
                          ),
                          title: const Text('Reminder'),
                          subtitle: Text(
                            _reminderEnabled
                                ? 'Notify me on the day'
                                : 'No reminder set',
                          ),
                          value: _reminderEnabled,
                          onChanged: (v) =>
                              setState(() => _reminderEnabled = v),
                        ),
                        if (_reminderEnabled)
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppPalette.accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.schedule_rounded,
                                color: AppPalette.accent,
                                size: 18,
                              ),
                            ),
                            title: const Text('Time'),
                            subtitle: Text(_reminderTimeOfDay.format(context)),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _pickTime,
                          ),
                      ],
                    ),
                  ),
                  if (_category == NoteCategory.task) ...[
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: scheme.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: SwitchListTile(
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                        ),
                        title: const Text('Completed'),
                        subtitle: Text(
                          _completed
                              ? 'Marked as done'
                              : 'Not completed yet',
                        ),
                        value: _completed,
                        onChanged: (v) => setState(() => _completed = v),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isEditing
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                            ),
                      label: Text(
                        _isEditing ? 'Save changes' : 'Add note',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}