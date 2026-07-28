import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../widgets/gradient_header.dart';
import 'login_page.dart';

/// User preferences: theme mode, default reminder time, week numbers, and
/// an about card. All changes persist through SettingsService and trigger
/// the app-wide `ValueListenableBuilder` rebuild in `main.dart`.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static final ValueNotifier<bool> unsubscribing = ValueNotifier<bool>(false);

  Future<void> _unsubscribe() async {
    final phone = await AuthService.instance.phone();
    if (!mounted) return;
    if (phone == null || phone.isEmpty) {
      _snack('No phone number on file');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Unsubscribe?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Your Reminder 24 subscription will be cancelled and you will be logged out. This cannot be undone.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => unsubscribing.value = true);
    try {
      final data = await AuthService.instance.unsubscribe(phone);
      if (!mounted) return;
      final success = data['success'] == true ||
          data['statusCode']?.toString() == 'S1000' ||
          data['subscriptionStatus']?.toString().toUpperCase() ==
              'UNREGISTERED';
      if (success) {
        _snack('Unsubscribed successfully', error: false);
        await AuthService.instance.logout();
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      } else {
        final msg = (data['statusDetail']?.toString().isNotEmpty ?? false)
            ? data['statusDetail']
            : 'Unsubscribe failed. Please try again.';
        _snack(msg.toString());
      }
    } on TimeoutException {
      if (mounted) _snack('Request timed out. Please try again.');
    } catch (_) {
      if (mounted) _snack('Network problem. Please try again.');
    } finally {
      if (mounted) setState(() => unsubscribing.value = false);
    }
  }

  void _snack(String msg, {bool error = true}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: error ? scheme.error : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<AppSettings>(
          valueListenable: settings,
          builder: (context, value, _) {
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: GradientHeader(
                    height: 130,
                    title: 'Settings',
                    subtitle: 'Customize how Reminder 24 works for you',
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(
                    children: [
                      const _AccountSection(),
                      const SizedBox(height: 18),
                      _SectionLabel('Appearance'),
                      _SettingsCard(
                        children: [
                          _ThemeModeTile(
                            mode: value.themeMode,
                            onChanged: settings.setThemeMode,
                          ),
                          const _Divider(),
                          SwitchListTile.adaptive(
                            secondary: Icon(
                              Icons.calendar_view_week_rounded,
                              color: scheme.primary,
                            ),
                            title: const Text('Show week numbers'),
                            subtitle: const Text(
                              'Display week numbers in the calendar grid',
                            ),
                            value: value.showWeekNumbers,
                            onChanged: settings.setShowWeekNumbers,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel('Reminders'),
                      _SettingsCard(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.access_time_rounded,
                              color: scheme.primary,
                            ),
                            title: const Text('Default reminder time'),
                            subtitle: Text(
                              'Used when you create a new note with reminders on',
                            ),
                            trailing: TextButton(
                              onPressed: () => _pickDefaultTime(context),
                              child: Text(
                                _formatTimeOfDay(
                                  value.defaultReminderHour,
                                  value.defaultReminderMinute,
                                ),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel('About'),
                      _SettingsCard(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.event_note_rounded,
                              color: scheme.primary,
                            ),
                            title: const Text('Reminder 24'),
                            subtitle: const Text(
                              'Version 1.0.0 • Built with Flutter',
                            ),
                          ),
                          const _Divider(),
                          ListTile(
                            leading: Icon(
                              Icons.lock_outline_rounded,
                              color: scheme.primary,
                            ),
                            title: const Text('Your data stays on device'),
                            subtitle: const Text(
                              'Notes are stored locally using SharedPreferences. No cloud sync, no telemetry.',
                            ),
                          ),
                          const _Divider(),
                          ListTile(
                            leading: Icon(
                              Icons.favorite_rounded,
                              color: scheme.error,
                            ),
                            title: const Text('Enjoying the app?'),
                            subtitle: const Text(
                              'Rate Reminder 24 on the Play Store.',
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Thanks! Store rating is wired up in a future build.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickDefaultTime(BuildContext context) async {
    final s = SettingsService.instance.value;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.defaultReminderHour, minute: s.defaultReminderMinute),
    );
    if (picked != null) {
      await SettingsService.instance.setDefaultReminder(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  String _formatTimeOfDay(int hour, int minute) {
    final dt = DateTime(2000, 1, 1, hour, minute);
    return DateFormat.jm().format(dt);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
      indent: 56,
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({required this.mode, required this.onChanged});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  IconData _icon(ThemeMode m) {
    switch (m) {
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  String _label(ThemeMode m) {
    switch (m) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.palette_rounded, color: scheme.primary),
      title: const Text('Theme'),
      subtitle: const Text('Match system, force light, or force dark'),
      trailing: PopupMenuButton<ThemeMode>(
        tooltip: 'Theme mode',
        initialValue: mode,
        onSelected: onChanged,
        itemBuilder: (context) => ThemeMode.values
            .map(
              (m) => PopupMenuItem<ThemeMode>(
                value: m,
                child: Row(
                  children: [
                    Icon(_icon(m), size: 18),
                    const SizedBox(width: 10),
                    Text(_label(m)),
                  ],
                ),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon(mode), size: 18, color: scheme.onPrimaryContainer),
              const SizedBox(width: 6),
              Text(
                _label(mode),
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Account section: shows the logged-in user's name + phone and offers the
/// unsubscribe action (mirrors bdapps/lib/home_page.dart).
class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Account'),
        FutureBuilder<_AccountInfo>(
          future: _load(),
          builder: (context, snap) {
            final info = snap.data ?? const _AccountInfo(name: '', phone: '');
            return _SettingsCard(
              children: [
                ListTile(
                  leading: Icon(Icons.person_rounded, color: scheme.primary),
                  title: const Text('Signed in as'),
                  subtitle: Text(
                    info.name.isNotEmpty ? info.name : 'Reminder 24 user',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const _Divider(),
                ListTile(
                  leading: Icon(Icons.phone_iphone_rounded,
                      color: scheme.primary),
                  title: const Text('Mobile number'),
                  subtitle: Text(
                    info.phone.isNotEmpty ? info.phone : '—',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const _Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _SettingsScreenState.unsubscribing,
                    builder: (context, busy, _) {
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => _confirmUnsubscribe(context),
                          icon: busy
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.error,
                                  ),
                                )
                              : const Icon(Icons.cancel_outlined, size: 18),
                          label: Text(
                            busy ? 'Unsubscribing…' : 'Unsubscribe',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                            side: BorderSide(
                                color: scheme.error.withOpacity(0.6),
                                width: 1.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<_AccountInfo> _load() async {
    final name = await AuthService.instance.name();
    final phone = await AuthService.instance.phone();
    return _AccountInfo(name: name ?? '', phone: phone ?? '');
  }

  Future<void> _confirmUnsubscribe(BuildContext context) async {
    // The button is in a FutureBuilder → no direct access to the State of
    // _SettingsScreenState. Walk up the tree to find it.
    final state = context.findAncestorStateOfType<_SettingsScreenState>();
    if (state != null) {
      await state._unsubscribe();
    }
  }
}

class _AccountInfo {
  const _AccountInfo({required this.name, required this.phone});
  final String name;
  final String phone;
}