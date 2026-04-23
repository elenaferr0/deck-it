import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../services/sr_service.dart';

class SRDifficultyButtons extends StatelessWidget {
  final AnimationController flipController;
  final FlashCard card;
  final SRService srService;
  final void Function(Difficulty) onRate;

  const SRDifficultyButtons({
    required this.flipController,
    required this.card,
    required this.srService,
    required this.onRate,
    super.key,
  });

  Widget _diffButton(BuildContext context, Difficulty diff, Color color) {
    final interval = srService.previewInterval(card.id, diff);
    final intervalLabel = interval == 1 ? '1d' : '${interval}d';
    return Expanded(
      child: GestureDetector(
        onTap: () => onRate(diff),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                diff.label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                intervalLabel,
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flipController,
      builder: (context, _) {
        final flipped = flipController.value >= 0.5;
        return AnimatedOpacity(
          opacity: flipped ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !flipped,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How well did you recall?',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _diffButton(context, Difficulty.again, Colors.red.shade400),
                      const SizedBox(width: 8),
                      _diffButton(context, Difficulty.hard, Colors.orange.shade400),
                      const SizedBox(width: 8),
                      _diffButton(context, Difficulty.good, Colors.green.shade500),
                      const SizedBox(width: 8),
                      _diffButton(context, Difficulty.easy, Colors.blue.shade400),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
