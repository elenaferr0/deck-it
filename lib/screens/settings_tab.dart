import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../services/sr_service.dart';
import '../services/storage_service.dart';
import '../widgets/setting_card.dart';
import '../widgets/sr_settings_card.dart';
import '../widgets/schedule_card.dart';

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
      _schedule[weekday] =
          current.copyWith(hour: picked.hour, minute: picked.minute);
    });
    await _saveAndApply();
  }

  Future<void> _loadStoragePath() async {
    final directory = await getApplicationDocumentsDirectory();
    setState(() => _storagePath = directory.path);
  }

  Future<void> _launchURL(String urlString) async {
    final Uri? uri = Uri.tryParse(urlString);
    if (uri == null) {
      _showErrorSnackBar('Invalid URL format');
      return;
    }
    try {
      if (!await canLaunchUrl(uri)) {
        _showErrorSnackBar('Cannot handle this URL');
        return;
      }
      final bool launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched) _showErrorSnackBar('Failed to open URL');
    } catch (e) {
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
        ? (color == null
            ? cs.primary
            : (brightness == Brightness.light ? mc! : mc![300]!))
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
                style:
                    TextStyle(color: fgColor, fontWeight: FontWeight.bold)),
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.settings_rounded, color: cs.primary),
            const SizedBox(width: 12),
            const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: cs.inversePrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          SettingCard(
            title: 'Appearance',
            icon: Icons.brightness_auto_rounded,
            subtitle: 'Light, dark, AMOLED, or follow system',
            content: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                  tooltip: 'System',
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                  tooltip: 'Light',
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                  tooltip: 'Dark',
                ),
                ButtonSegment(
                  value: AppThemeMode.amoled,
                  icon: Icon(Icons.nights_stay_rounded, size: 18),
                  tooltip: 'AMOLED',
                ),
              ],
              selected: {widget.themeProvider.appThemeMode},
              onSelectionChanged: (s) =>
                  widget.themeProvider.setAppThemeMode(s.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          SettingCard(
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
          SRSettingsCard(srService: widget.srService),
          ScheduleCard(
            schedule: _schedule,
            loaded: _scheduleLoaded,
            onToggleDay: _toggleDay,
            onEditTime: _editTime,
          ),
          SettingCard(
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
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Made by Nihar',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.primary),
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
