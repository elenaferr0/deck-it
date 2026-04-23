import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../services/sr_service.dart';

class ReviewDeckList extends StatelessWidget {
  final List<Deck> decks;
  final SRService srService;
  final bool answerFirst;
  final void Function(bool) onAnswerFirstChanged;
  final void Function(Deck) onStartReview;
  final VoidCallback onStartReviewAll;
  final VoidCallback onStartSRReview;
  final VoidCallback onStartSRReviewEarly;

  const ReviewDeckList({
    required this.decks,
    required this.srService,
    required this.answerFirst,
    required this.onAnswerFirstChanged,
    required this.onStartReview,
    required this.onStartReviewAll,
    required this.onStartSRReview,
    required this.onStartSRReviewEarly,
    super.key,
  });

  List<FlashCard> get _allCards => decks.expand((d) => d.cards).toList();

  Widget _buildSRCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allCards = _allCards;
    final noCards = allCards.isEmpty;
    final dueCount = srService.getDueCount(allCards);
    final sessionCount = dueCount.clamp(0, srService.dailyLimit);
    final hasDue = dueCount > 0 && !noCards;
    final upcomingCount =
        noCards ? 0 : srService.getUpcomingCards(allCards).length;
    final canPracticeEarly = !hasDue && upcomingCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: hasDue
          ? cs.secondaryContainer.withOpacity(0.5)
          : cs.surfaceContainerHighest.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: hasDue
            ? BorderSide(color: cs.secondary.withOpacity(0.4), width: 1)
            : BorderSide.none,
      ),
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
                    color: cs.secondaryContainer.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.psychology_rounded, color: cs.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spaced Repetition',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        noCards
                            ? 'No cards yet'
                            : hasDue
                                ? '$dueCount due · $sessionCount in session'
                                : 'All caught up for today!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                if (hasDue)
                  FilledButton.tonal(
                    onPressed: onStartSRReview,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.secondary,
                      foregroundColor: cs.onSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Start'),
                  ),
              ],
            ),
            if (hasDue && dueCount > sessionCount) ...[
              const SizedBox(height: 10),
              Text(
                '${dueCount - sessionCount} more available beyond daily limit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.5),
                    ),
              ),
            ],
            if (canPracticeEarly) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onStartSRReviewEarly,
                icon: Icon(Icons.bolt_rounded, size: 18, color: cs.secondary),
                label: Text(
                  'Practice Early ($upcomingCount upcoming)',
                  style: TextStyle(color: cs.secondary),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.secondary.withOpacity(0.4)),
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (decks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_disabled_rounded,
                size: 64, color: cs.primary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No Decks Yet',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Create your first card to start reviewing!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('Front side:',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Side 1'),
                selected: !answerFirst,
                onSelected: (_) => onAnswerFirstChanged(false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Side 2'),
                selected: answerFirst,
                onSelected: (_) => onAnswerFirstChanged(true),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: decks.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return _buildSRCard(context);
              if (index == 1) {
                final total =
                    decks.fold(0, (s, d) => s + d.cards.length);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: cs.primaryContainer.withOpacity(0.35),
                  child: ListTile(
                    onTap: total == 0 ? null : onStartReviewAll,
                    leading: Icon(Icons.layers_rounded, color: cs.primary),
                    title: Text(
                      'All Decks',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: total == 0
                            ? cs.onSurface.withOpacity(0.4)
                            : null,
                      ),
                    ),
                    subtitle: Text('$total cards total'),
                    trailing: Icon(
                      Icons.play_circle_filled,
                      color: total == 0
                          ? cs.onSurface.withOpacity(0.2)
                          : cs.primary,
                      size: 32,
                    ),
                  ),
                );
              }
              final deck = decks[index - 2];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: deck.cards.isEmpty
                      ? null
                      : () => onStartReview(deck),
                  title: Text(
                    deck.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: deck.cards.isEmpty
                          ? cs.onSurface.withOpacity(0.4)
                          : null,
                    ),
                  ),
                  subtitle: Text('${deck.cards.length} cards'),
                  trailing: Icon(
                    Icons.play_circle_filled,
                    color: deck.cards.isEmpty
                        ? cs.onSurface.withOpacity(0.2)
                        : cs.primary,
                    size: 32,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
