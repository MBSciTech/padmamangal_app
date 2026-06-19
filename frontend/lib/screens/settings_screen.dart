import 'package:flutter/material.dart';
import '../main.dart';
import '../state/app_state.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();

  // ── Font scale labels ────────────────────────────────────────────────
  static const _fontScales = [0.85, 1.0, 1.15, 1.3];
  static const _fontLabels = ['Small', 'Normal', 'Large', 'X-Large'];

  // ── Helper ───────────────────────────────────────────────────────────
  int _fontIdx(double scale) => _fontScales.indexOf(scale).clamp(0, _fontScales.length - 1);

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out of Padma Mangal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(ctx).colorScheme.primary, Theme.of(ctx).colorScheme.secondary],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 16),
            const Text('Padma Mangal',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Version 1.0.0',
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            const Text(
              'A private, secure space for your family to chat, share notices, and stay connected — always.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.6),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [

          // ── Appearance ───────────────────────────────────────────────
          _SettingsSection(
            label: 'Appearance',
            icon: Icons.palette_outlined,
            iconColor: cs.primary,
            children: [

              // Theme mode
              _SettingsTile(
                icon: Icons.brightness_6_rounded,
                iconColor: Colors.indigo,
                title: 'Theme',
                subtitle: _themeModeLabel(appState.themeMode),
                onTap: () => _showThemePicker(appState, cs),
                trailing: _ThemeDot(mode: appState.themeMode),
              ),

              // Chat background
              _SettingsTile(
                icon: Icons.wallpaper_rounded,
                iconColor: Colors.teal,
                title: 'Chat Background',
                subtitle: AppState.chatBgLabels[appState.chatBgIndex],
                onTap: () => _showBgPicker(appState),
                trailing: Container(
                  width: 32, height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppState.chatBgPresets[appState.chatBgIndex]),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                ),
              ),

              // Font size
              _SettingsTile(
                icon: Icons.text_fields_rounded,
                iconColor: Colors.orange,
                title: 'Text Size',
                subtitle: _fontLabels[_fontIdx(appState.fontScale)],
                onTap: () => _showFontSizePicker(appState, cs),
              ),

              // Compact bubbles
              _SettingsSwitch(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: Colors.blue,
                title: 'Compact Bubbles',
                subtitle: 'Reduce padding in message bubbles',
                value: appState.compactBubbles,
                onChanged: (v) => appState.setCompactBubbles(v),
              ),
            ],
          ),

          // ── Chat Behaviour ───────────────────────────────────────────
          _SettingsSection(
            label: 'Chat Behaviour',
            icon: Icons.chat_rounded,
            iconColor: Colors.green,
            children: [
              _SettingsSwitch(
                icon: Icons.keyboard_return_rounded,
                iconColor: Colors.green,
                title: 'Send on Enter',
                subtitle: 'Press Enter to send a message',
                value: appState.sendOnEnter,
                onChanged: (v) => appState.setSendOnEnter(v),
              ),
              _SettingsSwitch(
                icon: Icons.access_time_rounded,
                iconColor: Colors.grey.shade600,
                title: 'Show Timestamps',
                subtitle: 'Display time below each message',
                value: appState.showTimestamps,
                onChanged: (v) => appState.setShowTimestamps(v),
              ),
              _SettingsSwitch(
                icon: Icons.account_circle_outlined,
                iconColor: Colors.purple,
                title: 'Show Avatars',
                subtitle: 'Display profile pictures in chat',
                value: appState.showAvatars,
                onChanged: (v) => appState.setShowAvatars(v),
              ),
            ],
          ),

          // ── Notifications ────────────────────────────────────────────
          _SettingsSection(
            label: 'Notifications',
            icon: Icons.notifications_outlined,
            iconColor: Colors.amber.shade700,
            children: [
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                iconColor: Colors.amber.shade700,
                title: 'Message Notifications',
                subtitle: 'Manage how you get notified',
                onTap: () => _showComingSoon('Notification settings'),
              ),
              _SettingsTile(
                icon: Icons.event_note_rounded,
                iconColor: Colors.pink,
                title: 'Event Reminders',
                subtitle: 'Get reminders for upcoming events',
                onTap: () => _showComingSoon('Event reminders'),
              ),
            ],
          ),

          // ── Privacy ──────────────────────────────────────────────────
          _SettingsSection(
            label: 'Privacy & Security',
            icon: Icons.lock_outline_rounded,
            iconColor: Colors.red.shade600,
            children: [
              _SettingsTile(
                icon: Icons.password_rounded,
                iconColor: Colors.red.shade600,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showComingSoon('Password change'),
              ),
              _SettingsTile(
                icon: Icons.delete_outline_rounded,
                iconColor: Colors.red.shade700,
                title: 'Clear Chat History',
                subtitle: 'Delete all local message cache',
                onTap: () => _confirmClear(),
              ),
            ],
          ),

          // ── About ────────────────────────────────────────────────────
          _SettingsSection(
            label: 'About',
            icon: Icons.info_outline_rounded,
            iconColor: Colors.blueGrey,
            children: [
              _SettingsTile(
                icon: Icons.family_restroom_rounded,
                iconColor: cs.primary,
                title: 'About Padma Mangal',
                subtitle: 'Version 1.0.0',
                onTap: () => _showAboutDialog(context),
              ),
              _SettingsTile(
                icon: Icons.feedback_outlined,
                iconColor: Colors.teal,
                title: 'Send Feedback',
                subtitle: 'Help us improve the app',
                onTap: () => _showComingSoon('Feedback'),
              ),
            ],
          ),

          // ── Sign Out ─────────────────────────────────────────────────
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _logout,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:  return 'Light';
      case ThemeMode.dark:   return 'Dark';
      case ThemeMode.system: return 'System Default';
    }
  }

  void _showThemePicker(AppState appState, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
            )),
            const SizedBox(height: 16),
            const Text('Choose Theme', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...ThemeMode.values.map((mode) {
              final selected = appState.themeMode == mode;
              return ListTile(
                leading: Icon(
                  mode == ThemeMode.light ? Icons.light_mode_rounded
                    : mode == ThemeMode.dark ? Icons.dark_mode_rounded
                    : Icons.brightness_auto_rounded,
                  color: selected ? cs.primary : null,
                ),
                title: Text(_themeModeLabel(mode),
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? cs.primary : null,
                  )),
                trailing: selected ? Icon(Icons.check_circle_rounded, color: cs.primary) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: selected ? cs.primary.withValues(alpha: 0.08) : null,
                onTap: () {
                  appState.setThemeMode(mode);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showBgPicker(AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              )),
              const SizedBox(height: 16),
              const Text('Chat Background', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.4,
                ),
                itemCount: AppState.chatBgPresets.length,
                itemBuilder: (ctx, i) {
                  final selected = appState.chatBgIndex == i;
                  return GestureDetector(
                    onTap: () {
                      appState.setChatBgIndex(i);
                      setModal(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: AppState.chatBgPresets[i]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                            ? Theme.of(ctx).colorScheme.primary
                            : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: selected ? [
                          BoxShadow(
                            color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                          )
                        ] : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (selected)
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              AppState.chatBgLabels[i],
                              style: const TextStyle(fontSize: 11, color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black38)]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFontSizePicker(AppState appState, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              )),
              const SizedBox(height: 16),
              const Text('Text Size', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'The quick brown fox jumps over the lazy dog.',
                  style: TextStyle(
                    fontSize: 15 * appState.fontScale,
                    height: 1.5,
                  ),
                ),
              ),
              Row(
                children: _fontScales.asMap().entries.map((entry) {
                  final i = entry.key;
                  final scale = entry.value;
                  final selected = appState.fontScale == scale;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () {
                          appState.setFontScale(scale);
                          setModal(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? cs.primary : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _fontLabels[i],
                            style: TextStyle(
                              fontSize: 11 * scale,
                              color: selected ? Colors.white : cs.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Chat History', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This will clear locally cached messages. Server data is not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Local cache cleared'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }
}

// ─── Settings Section ─────────────────────────────────────────────────────────
class _SettingsSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SettingsSection({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
          child: Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children.asMap().entries.map((e) {
              final isFirst = e.key == 0;
              final isLast  = e.key == children.length - 1;
              return ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: isFirst ? const Radius.circular(18) : Radius.zero,
                  bottom: isLast ? const Radius.circular(18) : Radius.zero,
                ),
                child: e.value,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Settings Switch ──────────────────────────────────────────────────────────
class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }
}

// ─── Theme Dot indicator ──────────────────────────────────────────────────────
class _ThemeDot extends StatelessWidget {
  final ThemeMode mode;
  const _ThemeDot({required this.mode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: mode == ThemeMode.system
          ? const LinearGradient(colors: [Colors.black, Colors.white])
          : null,
        color: mode == ThemeMode.dark ? Colors.grey.shade900
          : mode == ThemeMode.light ? Colors.amber.shade100
          : null,
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Icon(
        mode == ThemeMode.light ? Icons.light_mode_rounded
          : mode == ThemeMode.dark ? Icons.dark_mode_rounded
          : Icons.brightness_auto_rounded,
        size: 16,
        color: mode == ThemeMode.dark ? Colors.white70 : Colors.grey.shade700,
      ),
    );
  }
}
