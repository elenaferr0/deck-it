import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../providers/theme_provider.dart';

class SettingsTab extends StatefulWidget {
  final StorageService storage;
  final ThemeProvider themeProvider;

  const SettingsTab({
    required this.storage,
    required this.themeProvider,
    super.key,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _storagePath = '';
  Map<int, DaySchedule> _schedule = {};
  bool _scheduleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStoragePath();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final schedule = await NotificationService.instance.loadSchedule();
    setState(() {
      _schedule = schedule;
      _scheduleLoaded = true;
    });
  }

  Future<void> _saveAndApply() async {
    await NotificationService.instance.saveSchedule(_schedule);
    await NotificationService.instance.applySchedule(_schedule);
  }

  Future<void> _toggleDay(int weekday, bool enabled) async {
    if (enabled) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted && mounted) {
        _showErrorSnackBar('Notification permission denied');
        return;
      }
      if (!mounted) return;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: _schedule[weekday]!.hour,
          minute: _schedule[weekday]!.minute,
        ),
        helpText: 'Set reminder time',
      );
      if (!mounted) return;
      setState(() {
        _schedule[weekday] = _schedule[weekday]!.copyWith(
          enabled: true,
          hour: picked?.hour ?? _schedule[weekday]!.hour,
          minute: picked?.minute ?? _schedule[weekday]!.minute,
        );
      });
    } else {
      setState(() {
        _schedule[weekday] = _schedule[weekday]!.copyWith(enabled: false);
      });
    }
    await _saveAndApply();
  }

  Future<void> _editTime(int weekday) async {
    final current = _schedule[weekday]!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'Set reminder time',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _schedule[weekday] = current.copyWith(hour: picked.hour, minute: picked.minute);
    });
    await _saveAndApply();
  }

  Future<void> _loadStoragePath() async {
    final directory = await getApplicationDocumentsDirectory();
    setState(() {
      _storagePath = directory.path;
    });
  }

  Future<void> _launchURL(String urlString) async {
    final Uri? uri = Uri.tryParse(urlString);

    if (uri == null) {
      debugPrint('Failed to parse URI: $urlString');
      _showErrorSnackBar('Invalid URL format');
      return;
    }

    try {
      if (!await canLaunchUrl(uri)) {
        _showErrorSnackBar('Cannot handle this URL');
        return;
      }

      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (!launched) {
        _showErrorSnackBar('Failed to open URL');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      _showErrorSnackBar('Error opening URL: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        showCloseIcon: true,
        closeIconColor: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required IconData icon,
    required Widget content,
    String? subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (content is! Switch) const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    if (!_scheduleLoaded) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.schedule_rounded, color: colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Schedule',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daily reminder notifications',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            for (int weekday = 1; weekday <= 7; weekday++)
              _buildDayRow(weekday),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(int weekday) {
    final s = _schedule[weekday]!;
    final name = NotificationService.weekdayNames[weekday - 1];
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 0,
      leading: Switch(
        value: s.enabled,
        onChanged: (v) => _toggleDay(weekday, v),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: s.enabled ? FontWeight.bold : FontWeight.normal,
          color: s.enabled ? null : Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      trailing: s.enabled
          ? GestureDetector(
              onTap: () => _editTime(weekday),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildColorButton(MaterialColor color, String label) {
    final brightness = Theme.of(context).brightness;
    final backgroundColor = brightness == Brightness.light
        ? color[50]!
        : color[700]!.withOpacity(0.3);
    final borderColor =
        brightness == Brightness.light ? color : color[300]!;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.themeProvider.toggleSeedColor(color),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: brightness == Brightness.light ? color[900] : color[50],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.settings_rounded,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: colorScheme.inversePrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSettingCard(
            title: 'Dark Mode',
            icon: Icons.dark_mode_rounded,
            subtitle: 'Toggle app theme',
            content: Align(
              alignment: Alignment.centerRight,
              child: Switch(
                value: widget.themeProvider.isDarkMode,
                onChanged: (_) => widget.themeProvider.toggleTheme(),
              ),
            ),
          ),
          _buildSettingCard(
            title: 'Color Theme',
            icon: Icons.palette_rounded,
            subtitle: 'Choose your preferred color scheme',
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorButton(Colors.lime, 'Lime'),
                _buildColorButton(Colors.indigo, 'Indigo'),
                _buildColorButton(Colors.blueGrey, 'Blue'),
              ],
            ),
          ),
          _buildSettingCard(
            title: 'Storage Location',
            icon: Icons.folder_rounded,
            content: Text(
              _storagePath,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ),
          _buildScheduleCard(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () =>
                      _launchURL('https://github.com/nuanv/DeckIt'),
                  icon: const Icon(Icons.code_rounded),
                  label: const Text('DeckIt on GitHub'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Made by Nihar',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
