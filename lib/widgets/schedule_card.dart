import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class ScheduleCard extends StatelessWidget {
  final Map<int, DaySchedule> schedule;
  final bool loaded;
  final void Function(int weekday, bool enabled) onToggleDay;
  final void Function(int weekday) onEditTime;

  const ScheduleCard({
    required this.schedule,
    required this.loaded,
    required this.onToggleDay,
    required this.onEditTime,
    super.key,
  });

  Widget _buildDayRow(BuildContext context, int weekday) {
    final s = schedule[weekday]!;
    final name = NotificationService.weekdayNames[weekday - 1];
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 0,
      leading: Switch(
        value: s.enabled,
        onChanged: (v) => onToggleDay(weekday, v),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: s.enabled ? FontWeight.bold : FontWeight.normal,
          color: s.enabled
              ? null
              : Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      trailing: s.enabled
          ? GestureDetector(
              onTap: () => onEditTime(weekday),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
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
                    color: cs.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(Icons.schedule_rounded, color: cs.primary),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Schedule',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Daily reminder notifications',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            for (int weekday = 1; weekday <= 7; weekday++)
              _buildDayRow(context, weekday),
          ],
        ),
      ),
    );
  }
}
