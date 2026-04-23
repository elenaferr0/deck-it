import 'package:flutter/material.dart';
import '../services/sr_service.dart';

class SRSettingsCard extends StatefulWidget {
  final SRService srService;

  const SRSettingsCard({required this.srService, super.key});

  @override
  State<SRSettingsCard> createState() => _SRSettingsCardState();
}

class _SRSettingsCardState extends State<SRSettingsCard> {
  late int _dailyLimit;

  @override
  void initState() {
    super.initState();
    _dailyLimit = widget.srService.dailyLimit;
  }

  @override
  Widget build(BuildContext context) {
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
                    color: cs.secondaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(Icons.psychology_rounded, color: cs.secondary),
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
                    Text('Daily card review limit',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Cards per day:',
                    style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_dailyLimit',
                    style: TextStyle(
                        color: cs.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
              ],
            ),
            Slider(
              value: _dailyLimit.toDouble(),
              min: 5,
              max: 100,
              divisions: 19,
              activeColor: cs.secondary,
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
                    color: cs.onSurface.withOpacity(0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
