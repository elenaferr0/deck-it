import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/sr_service.dart';
import '../providers/theme_provider.dart';

class SettingsTab extends StatefulWidget {
  final StorageService storage;
  final ThemeProvider themeProvider;
  final SRService srService;

  const SettingsTab({
    required this.storage,
    required this.themeProvider,
    required this.srService,
    super.key,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _storagePath = '';
  Map<int, DaySchedule> _schedule = {};
  bool _scheduleLoaded = false;
  late int _dailyLimit;

  @override
  void initState() {
    super.initState();
    _dailyLimit = widget.srService.dailyLimit;
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

  Widget _iconBadge(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _iconBadge(icon),
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
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: content,
            ),
          ],
        ),
      ),
    );
  }

  // Compact single-row card: icon + title + trailing widget, no bottom content.
  Widget _buildRowCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required Widget trailing,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _iconBadge(icon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSRSettingsCard() {
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
                    color: colorScheme.secondaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.psychology_rounded,
                      color: colorScheme.secondary),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spaced Repetition',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daily card review limit',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Cards per day:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_dailyLimit',
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _dailyLimit.toDouble(),
              min: 5,
              max: 100,
              divisions: 19,
              activeColor: colorScheme.secondary,
              label: '$_dailyLimit cards',
              onChanged: (v) => setState(() => _dailyLimit = v.round()),
              onChangeEnd: (v) async {
                final newLimit = v.round();
                setState(() => _dailyLimit = newLimit);
                await widget.srService.setDailyLimit(newLimit);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5', style: Theme.of(context).textTheme.bodySmall),
                Text('100', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You can always review more than this limit in a session.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
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

  Widget _buildColorButton({Color? color, required String label, IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isSelected = widget.themeProvider.seedColor == color;

    final MaterialColor? mc = color == null ? null : _toMaterialColor(color);
    final bgColor = color == null
        ? cs.primaryContainer.withOpacity(isSelected ? 0.5 : 0.2)
        : (brightness == Brightness.light
            ? mc![50]!.withOpacity(isSelected ? 1 : 0.7)
            : mc![700]!.withOpacity(isSelected ? 0.5 : 0.2));
    final fgColor = color == null
        ? cs.primary
        : (brightness == Brightness.light ? mc![900]! : mc![50]!);
    final borderColor = isSelected
        ? (color == null ? cs.primary : (brightness == Brightness.light ? mc! : mc![300]!))
        : Colors.transparent;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => widget.themeProvider.setSeedColor(color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(color: fgColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  MaterialColor _toMaterialColor(Color color) {
    if (color == Colors.lime) return Colors.lime;
    if (color == Colors.indigo) return Colors.indigo;
    if (color == Colors.blueGrey) return Colors.blueGrey;
    return Colors.indigo;
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
            title: 'Appearance',
            icon: Icons.brightness_auto_rounded,
            subtitle: 'Light, dark, or follow system',
            content: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                  tooltip: 'System',
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                  tooltip: 'Light',
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                  tooltip: 'Dark',
                ),
              ],
              selected: {widget.themeProvider.themeMode},
              onSelectionChanged: (s) =>
                  widget.themeProvider.setThemeMode(s.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          _buildSettingCard(
            title: 'Color Theme',
            icon: Icons.palette_rounded,
            subtitle: 'Choose accent color',
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildColorButton(
                  color: null,
                  label: 'Dynamic',
                  icon: Icons.auto_awesome_rounded,
                ),
                _buildColorButton(color: Colors.lime, label: 'Lime'),
                _buildColorButton(color: Colors.indigo, label: 'Indigo'),
                _buildColorButton(color: Colors.blueGrey, label: 'Blue'),
              ],
            ),
          ),
          _buildSRSettingsCard(),
          _buildScheduleCard(),
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
