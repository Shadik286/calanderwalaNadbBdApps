import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';

/// Reusable note card used across the dashboard, calendar, search,
/// categories, and reminders list. Tapping or long-pressing invokes
/// the supplied callbacks so each screen can wire its own behavior.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onLongPress,
    this.onToggleComplete,
    this.dense = false,
    this.showDate = true,
  });

  final Note note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onToggleComplete;
  final bool dense;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = note.accentColor;
    final isTask = note.category == NoteCategory.task;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withOpacity(0.4),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: dense ? 12 : 14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category icon avatar.
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(note.category.icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              // Title, description, meta.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title.isEmpty ? '(Untitled)' : note.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                              decoration: note.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (note.priority != NotePriority.none) ...[
                          const SizedBox(width: 6),
                          _priorityChip(note.priority),
                        ],
                      ],
                    ),
                    if (note.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note.description,
                        maxLines: dense ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (showDate)
                          _metaChip(
                            context,
                            Icons.event_outlined,
                            DateFormat('MMM d').format(note.date),
                            accent,
                          ),
                        if (note.reminderEnabled && note.reminderTime != null)
                          _metaChip(
                            context,
                            Icons.notifications_active_outlined,
                            DateFormat('h:mm a').format(note.reminderTime!),
                            scheme.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Trailing: task checkbox or chevron.
              const SizedBox(width: 8),
              if (onToggleComplete != null && isTask)
                Transform.scale(
                  scale: 1.1,
                  child: Checkbox(
                    value: note.completed,
                    onChanged: (v) => onToggleComplete!(v ?? false),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: BorderSide(
                      color: accent.withOpacity(0.7),
                      width: 2,
                    ),
                  ),
                )
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withOpacity(0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(BuildContext context, IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _priorityChip(NotePriority p) {
    final color = switch (p) {
      NotePriority.high => const Color(0xFFEF4444),
      NotePriority.medium => const Color(0xFFF59E0B),
      NotePriority.low => const Color(0xFF10B981),
      NotePriority.none => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        p.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}