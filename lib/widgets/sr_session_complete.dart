import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../services/sr_service.dart';

class SRSessionComplete extends StatelessWidget {
  final Map<String, Difficulty> sessionRatings;
  final List<FlashCard> currentCards;
  final List<FlashCard> allCards;
  final SRService srService;
  final bool srLoadedMore;
  final bool srEarlyPractice;
  final VoidCallback onDone;
  final VoidCallback onLoadMore;
  final VoidCallback onEarlyPractice;

  const SRSessionComplete({
    required this.sessionRatings,
    required this.currentCards,
    required this.allCards,
    required this.srService,
    required this.srLoadedMore,
    required this.srEarlyPractice,
    required this.onDone,
    required this.onLoadMore,
    required this.onEarlyPractice,
    super.key,
  });

  Widget _summaryRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('$count',
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final counts = {
      Difficulty.again: 0,
      Difficulty.hard: 0,
      Difficulty.good: 0,
      Difficulty.easy: 0,
    };
    for (final d in sessionRatings.values) {
      counts[d] = (counts[d] ?? 0) + 1;
    }

    final allDueCount = srService.getDueCount(allCards);
    final remainingExtra = allDueCount - currentCards.length;
    final upcomingCount = srService.getUpcomingCards(allCards).length;
    final canPracticeEarly =
        remainingExtra <= 0 && !srEarlyPractice && upcomingCount > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: cs.primary, size: 72),
            const SizedBox(height: 16),
            Text(
              'Session Complete!',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Reviewed ${sessionRatings.length} cards',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 24),
            _summaryRow('Again', counts[Difficulty.again]!, Colors.red.shade400),
            const SizedBox(height: 8),
            _summaryRow('Hard', counts[Difficulty.hard]!, Colors.orange.shade400),
            const SizedBox(height: 8),
            _summaryRow('Good', counts[Difficulty.good]!, Colors.green.shade500),
            const SizedBox(height: 8),
            _summaryRow('Easy', counts[Difficulty.easy]!, Colors.blue.shade400),
            const SizedBox(height: 32),
            if (!srLoadedMore && remainingExtra > 0) ...[
              FilledButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(Icons.add_rounded),
                label: Text('Review $remainingExtra More Cards'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (canPracticeEarly) ...[
              OutlinedButton.icon(
                onPressed: onEarlyPractice,
                icon: Icon(Icons.bolt_rounded, size: 18, color: cs.secondary),
                label: Text(
                  'Practice Early ($upcomingCount upcoming)',
                  style: TextStyle(color: cs.secondary),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.secondary.withOpacity(0.4)),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: onDone,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
