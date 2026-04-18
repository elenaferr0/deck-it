import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const String _channelId = 'deck_it_review';
const String _channelName = 'Review Reminders';
const int _snoozeNotificationId = 0;

/// Required top-level stub for background notification responses.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // All action handling is done in the foreground via onDidReceiveNotificationResponse.
}

// ---------------------------------------------------------------------------

class DaySchedule {
  final bool enabled;
  final int hour;
  final int minute;

  const DaySchedule({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  DaySchedule copyWith({bool? enabled, int? hour, int? minute}) => DaySchedule(
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
  };

  factory DaySchedule.fromJson(Map<String, dynamic> json) => DaySchedule(
    enabled: json['enabled'] ?? false,
    hour: json['hour'] ?? 9,
    minute: json['minute'] ?? 0,
  );
}

// ---------------------------------------------------------------------------

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;

  static const String _scheduleKey = 'notification_schedule';

  static const List<String> weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // -------------------------------------------------------------------------
  // Initialisation
  // -------------------------------------------------------------------------

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));
    } catch (_) {
      // Fall back to UTC; scheduled times will be off by UTC offset but won't crash.
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'review_reminder',
          actions: [
            DarwinNotificationAction.plain(
              'snooze_1h',
              'Snooze 1h',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              'custom_time',
              'Choose time',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Re-apply persisted schedule (e.g. after reinstall or plugin re-init).
    final schedule = await loadSchedule();
    await applySchedule(schedule);
  }

  // -------------------------------------------------------------------------
  // Permissions
  // -------------------------------------------------------------------------

  Future<bool> requestPermissions() async {
    bool granted = false;

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      granted = await androidImpl.requestNotificationsPermission() ?? false;
    }

    final darwinImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (darwinImpl != null) {
      granted =
          await darwinImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return granted;
  }

  Future<bool> hasPermission() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      return await androidImpl.areNotificationsEnabled() ?? false;
    }
    return true; // Assume granted on iOS/other after request.
  }

  // -------------------------------------------------------------------------
  // Schedule persistence
  // -------------------------------------------------------------------------

  Future<Map<int, DaySchedule>> loadSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scheduleKey);
    if (raw == null) return _defaultSchedule();

    final Map<String, dynamic> decoded = jsonDecode(raw);
    return {
      for (final e in decoded.entries)
        int.parse(e.key): DaySchedule.fromJson(e.value as Map<String, dynamic>),
    };
  }

  Future<void> saveSchedule(Map<int, DaySchedule> schedule) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      for (final e in schedule.entries) '${e.key}': e.value.toJson(),
    });
    await prefs.setString(_scheduleKey, encoded);
  }

  Map<int, DaySchedule> _defaultSchedule() => {
    for (int i = 1; i <= 7; i++)
      i: const DaySchedule(enabled: false, hour: 9, minute: 0),
  };

  // -------------------------------------------------------------------------
  // Scheduling
  // -------------------------------------------------------------------------

  Future<void> applySchedule(Map<int, DaySchedule> schedule) async {
    for (int i = 1; i <= 7; i++) {
      await _plugin.cancel(id: i);
    }
    for (final entry in schedule.entries) {
      if (entry.value.enabled) {
        await _scheduleWeekly(entry.key, entry.value.hour, entry.value.minute);
      }
    }
  }

  Future<void> _scheduleWeekly(int weekday, int hour, int minute) async {
    await _plugin.zonedSchedule(
      id: weekday,
      title: '📚 Review time!',
      body: "Don't forget to review your flashcards today.",
      scheduledDate: _nextInstanceOfWeekdayAndTime(weekday, hour, minute),
      notificationDetails: _buildNotificationDetails(withActions: true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> scheduleSnooze(Duration duration) async {
    final snoozeTime = tz.TZDateTime.now(tz.local).add(duration);
    await _plugin.zonedSchedule(
      id: _snoozeNotificationId,
      title: '📚 Review time!',
      body: "Don't forget to review your flashcards!",
      scheduledDate: snoozeTime,
      notificationDetails: _buildNotificationDetails(withActions: true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // -------------------------------------------------------------------------
  // Notification details
  // -------------------------------------------------------------------------

  NotificationDetails _buildNotificationDetails({required bool withActions}) {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Reminders to review your DeckIt flashcards',
      importance: Importance.high,
      priority: Priority.high,
      actions: withActions
          ? const [
              AndroidNotificationAction(
                'snooze_1h',
                'Snooze 1h',
                showsUserInterface: true,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'custom_time',
                'Choose time',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ]
          : null,
    );

    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'review_reminder',
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  // -------------------------------------------------------------------------
  // Time helpers
  // -------------------------------------------------------------------------

  tz.TZDateTime _nextInstanceOfWeekdayAndTime(
    int weekday,
    int hour,
    int minute,
  ) {
    tz.TZDateTime candidate = _nextInstanceOfTime(hour, minute);
    while (candidate.weekday != weekday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  // -------------------------------------------------------------------------
  // Response handling
  // -------------------------------------------------------------------------

  void _onNotificationResponse(NotificationResponse response) {
    switch (response.actionId) {
      case 'snooze_1h':
        scheduleSnooze(const Duration(hours: 1));
        _showSnackbar('Snoozed for 1 hour');
        break;
      case 'custom_time':
        _showCustomSnoozeDialog();
        break;
      default:
        // Notification body tapped — app brought to foreground, nothing more needed.
        break;
    }
  }

  void _showSnackbar(String message) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCustomSnoozeDialog() async {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Remind me at',
    );
    if (picked == null) return;

    final now = DateTime.now();
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    await scheduleSnooze(target.difference(now));

    if (context.mounted) {
      _showSnackbar('Reminder set for ${picked.format(context)}');
    }
  }
}
