import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../services/storage_service.dart';
import '../services/sr_service.dart';

final _rng = math.Random();

enum _ReviewMode { normal, spaced }

class ReviewTab extends StatefulWidget {
  final StorageService storage;
  final SRService srService;
  const ReviewTab({required this.storage, required this.srService, super.key});

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab>
    with SingleTickerProviderStateMixin {
  List<Deck> decks = [];
  List<FlashCard> currentCards = [];
  int currentCardIndex = 0;
  bool isReviewing = false;
  bool _hasFlipped = false;
  bool _answerFirst = false;
  Deck? selectedDeck;
  _ReviewMode _reviewMode = _ReviewMode.normal;

  // SR session state
  final Map<String, Difficulty> _sessionRatings = {};
  bool _srSessionComplete = false;
  bool _srLoadedMore = false;
  bool _srEarlyPractice = false;

  late final AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadDecks();
    _setupPeriodicUpdates();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _setupPeriodicUpdates() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _refreshCurrentDeck();
        _setupPeriodicUpdates();
      }
    });
  }

  Future<void> _refreshCurrentDeck() async {
    if (isReviewing && selectedDeck == null) return;
    if (selectedDeck != null) {
      final updatedDecks = await widget.storage.getDecks();
      final updatedDeck = updatedDecks.firstWhere(
        (deck) => deck.id == selectedDeck!.id,
        orElse: () => selectedDeck!,
      );
      if (mounted) {
        setState(() {
          decks = updatedDecks;
          selectedDeck = updatedDeck;
          if (_reviewMode == _ReviewMode.normal) {
            currentCards = updatedDeck.cards;
            if (currentCardIndex >= currentCards.length) {
              currentCardIndex =
                  currentCards.isEmpty ? 0 : currentCards.length - 1;
            }
          }
        });
      }
    } else {
      _loadDecks();
    }
  }

  Future<void> _loadDecks() async {
    final loadedDecks = await widget.storage.getDecks();
    if (mounted) {
      setState(() {
        decks = loadedDecks;
      });
    }
  }

  List<FlashCard> get _allCards => decks.expand((d) => d.cards).toList();

  void _startReview(Deck deck) {
    _flipController.value = 0.0;
    final shuffled = List<FlashCard>.from(deck.cards)..shuffle(_rng);
    setState(() {
      selectedDeck = deck;
      currentCards = shuffled;
      currentCardIndex = 0;
      _hasFlipped = false;
      isReviewing = true;
      _reviewMode = _ReviewMode.normal;
      _srSessionComplete = false;
      _sessionRatings.clear();
    });
  }

  void _startReviewAll() {
    final allCards = _allCards..shuffle(_rng);
    if (allCards.isEmpty) return;
    _flipController.value = 0.0;
    setState(() {
      selectedDeck = null;
      currentCards = allCards;
      currentCardIndex = 0;
      _hasFlipped = false;
      isReviewing = true;
      _reviewMode = _ReviewMode.normal;
      _srSessionComplete = false;
      _sessionRatings.clear();
    });
  }

  void _startSRReview({bool loadMore = false, bool earlyPractice = false}) {
    final all = _allCards;
    final List<FlashCard> cards;
    if (earlyPractice) {
      cards = widget.srService.getUpcomingCards(all);
    } else if (loadMore) {
      cards = widget.srService.getAllDueCards(all);
    } else {
      cards = widget.srService.getDueCards(all);
    }
    if (cards.isEmpty) return;
    _flipController.value = 0.0;
    setState(() {
      selectedDeck = null;
      currentCards = cards;
      currentCardIndex = 0;
      _hasFlipped = false;
      isReviewing = true;
      _reviewMode = _ReviewMode.spaced;
      _srSessionComplete = false;
      _srLoadedMore = loadMore;
      _srEarlyPractice = earlyPractice;
      _sessionRatings.clear();
    });
  }

  void _endReview() {
    _flipController.value = 0.0;
    setState(() {
      isReviewing = false;
      selectedDeck = null;
      currentCards = [];
      currentCardIndex = 0;
      _hasFlipped = false;
      _srSessionComplete = false;
      _sessionRatings.clear();
    });
  }

  void _nextCard() {
    if (!_hasFlipped || _flipController.isAnimating) return;
    if (currentCardIndex < currentCards.length - 1) {
      setState(() {
        currentCardIndex++;
        _hasFlipped = false;
      });
      _flipController.value = 0.0;
    }
  }

  void _previousCard() {
    if (_flipController.isAnimating) return;
    if (currentCardIndex > 0) {
      setState(() {
        currentCardIndex--;
        _hasFlipped = false;
      });
      _flipController.value = 0.0;
    }
  }

  void _toggleCard() {
    if (_flipController.isAnimating) return;
    if (_flipController.value < 0.5) {
      _flipController.forward().then((_) {
        if (mounted) setState(() => _hasFlipped = true);
      });
    } else {
      _flipController.reverse();
    }
  }

  void _toggleDirection() {
    _flipController.value = 0.0;
    setState(() {
      _answerFirst = !_answerFirst;
      _hasFlipped = false;
    });
  }

  void _rateSRCard(Difficulty difficulty) {
    final card = currentCards[currentCardIndex];
    widget.srService.rateCard(card.id, difficulty);
    setState(() {
      _sessionRatings[card.id] = difficulty;
    });

    if (currentCardIndex < currentCards.length - 1) {
      setState(() {
        currentCardIndex++;
        _hasFlipped = false;
      });
      _flipController.value = 0.0;
    } else {
      // Session done
      setState(() => _srSessionComplete = true);
    }
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildFlipCard() {
    final card = currentCards[currentCardIndex];
    final colorScheme = Theme.of(context).colorScheme;

    final side1 = (selectedDeck?.side1Label ?? 'Front').toUpperCase();
    final side2 = (selectedDeck?.side2Label ?? 'Back').toUpperCase();
    final frontText = _answerFirst ? card.answer : card.question;
    final backText = _answerFirst ? card.question : card.answer;
    final frontLabel = _answerFirst ? side2 : side1;
    final backLabel = _answerFirst ? side1 : side2;
    final hasBack = backText.trim().isNotEmpty;

    return GestureDetector(
      onTap: _toggleCard,
      child: AnimatedBuilder(
        animation: _flipController,
        builder: (context, _) {
          final angle = _flipController.value * math.pi;
          final isShowingFront = _flipController.value <= 0.5;

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(isShowingFront ? angle : angle - math.pi);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              elevation: 4,
              color: isShowingFront
                  ? colorScheme.surface
                  : colorScheme.primaryContainer.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isShowingFront
                    ? BorderSide.none
                    : BorderSide(
                        color: colorScheme.primary.withOpacity(0.3), width: 1),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 32),
                                  Text(
                                    isShowingFront ? frontLabel : backLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    isShowingFront
                                        ? frontText
                                        : (hasBack
                                            ? backText
                                            : 'No answer provided'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                    textAlign: TextAlign.center,
                                  ),
                                  if (!isShowingFront && !hasBack) ...[
                                    const SizedBox(height: 16),
                                    Icon(
                                      Icons.warning_rounded,
                                      size: 48,
                                      color: colorScheme.error.withOpacity(0.6),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceDim.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isShowingFront
                            ? Icons.visibility_off
                            : (!isShowingFront && !hasBack
                                ? Icons.warning_rounded
                                : Icons.visibility),
                        color: (!isShowingFront && !hasBack)
                            ? colorScheme.error
                            : colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSRDifficultyButtons() {
    return AnimatedBuilder(
      animation: _flipController,
      builder: (context, _) {
        final flipped = _flipController.value >= 0.5;
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
                      _diffButton(Difficulty.again, Colors.red.shade400),
                      const SizedBox(width: 8),
                      _diffButton(Difficulty.hard, Colors.orange.shade400),
                      const SizedBox(width: 8),
                      _diffButton(Difficulty.good, Colors.green.shade500),
                      const SizedBox(width: 8),
                      _diffButton(Difficulty.easy, Colors.blue.shade400),
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

  Widget _diffButton(Difficulty diff, Color color) {
    final card = currentCards[currentCardIndex];
    final interval = widget.srService.previewInterval(card.id, diff);
    final intervalLabel = interval == 1 ? '1d' : '${interval}d';

    return Expanded(
      child: GestureDetector(
        onTap: () => _rateSRCard(diff),
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
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                intervalLabel,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSRSessionComplete() {
    final cs = Theme.of(context).colorScheme;
    final counts = {
      Difficulty.again: 0,
      Difficulty.hard: 0,
      Difficulty.good: 0,
      Difficulty.easy: 0,
    };
    for (final d in _sessionRatings.values) {
      counts[d] = (counts[d] ?? 0) + 1;
    }

    final all = _allCards;
    final allDueCount = widget.srService.getDueCount(all);
    final remainingExtra = allDueCount - currentCards.length;
    final upcomingCount = widget.srService.getUpcomingCards(all).length;
    final canPracticeEarly = remainingExtra <= 0 && !_srEarlyPractice && upcomingCount > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: cs.primary, size: 72),
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
              'Reviewed ${_sessionRatings.length} cards',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 24),
            _buildSummaryRow(
                'Again', counts[Difficulty.again]!, Colors.red.shade400),
            const SizedBox(height: 8),
            _buildSummaryRow(
                'Hard', counts[Difficulty.hard]!, Colors.orange.shade400),
            const SizedBox(height: 8),
            _buildSummaryRow(
                'Good', counts[Difficulty.good]!, Colors.green.shade500),
            const SizedBox(height: 8),
            _buildSummaryRow(
                'Easy', counts[Difficulty.easy]!, Colors.blue.shade400),
            const SizedBox(height: 32),
            if (!_srLoadedMore && remainingExtra > 0) ...[
              FilledButton.icon(
                onPressed: () => _startSRReview(loadMore: true),
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
                onPressed: () => _startSRReview(earlyPractice: true),
                icon: Icon(Icons.bolt_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary),
                label: Text(
                  'Practice Early ($upcomingCount upcoming)',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.4)),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: _endReview,
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

  Widget _buildSummaryRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('$count',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildDeckList() {
    final colorScheme = Theme.of(context).colorScheme;

    if (decks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_disabled_rounded,
              size: 64,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Decks Yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
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

    final allCards = _allCards;
    final dueCount = widget.srService.getDueCount(allCards);
    final dailyLimit = widget.srService.dailyLimit;
    final sessionCount = dueCount.clamp(0, dailyLimit);

    return Column(
      children: [
        // Direction toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                'Front side:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Side 1'),
                selected: !_answerFirst,
                onSelected: (_) => setState(() => _answerFirst = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Side 2'),
                selected: _answerFirst,
                onSelected: (_) => setState(() => _answerFirst = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: decks.length + 2, // +1 SR card, +1 all-decks
            itemBuilder: (context, index) {
              // SR review card at index 0
              if (index == 0) {
                return _buildSRCard(
                    dueCount, sessionCount, allCards.isEmpty, colorScheme);
              }
              // All decks at index 1
              if (index == 1) {
                final total = decks.fold(0, (s, d) => s + d.cards.length);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: colorScheme.primaryContainer.withOpacity(0.35),
                  child: ListTile(
                    onTap: total == 0 ? null : _startReviewAll,
                    leading:
                        Icon(Icons.layers_rounded, color: colorScheme.primary),
                    title: Text(
                      'All Decks',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: total == 0
                            ? colorScheme.onSurface.withOpacity(0.4)
                            : null,
                      ),
                    ),
                    subtitle: Text('$total cards total'),
                    trailing: Icon(
                      Icons.play_circle_filled,
                      color: total == 0
                          ? colorScheme.onSurface.withOpacity(0.2)
                          : colorScheme.primary,
                      size: 32,
                    ),
                  ),
                );
              }
              final deck = decks[index - 2];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap:
                      deck.cards.isEmpty ? null : () => _startReview(deck),
                  title: Text(
                    deck.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: deck.cards.isEmpty
                          ? colorScheme.onSurface.withOpacity(0.4)
                          : null,
                    ),
                  ),
                  subtitle: Text('${deck.cards.length} cards'),
                  trailing: Icon(
                    Icons.play_circle_filled,
                    color: deck.cards.isEmpty
                        ? colorScheme.onSurface.withOpacity(0.2)
                        : colorScheme.primary,
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

  Widget _buildSRCard(
      int dueCount, int sessionCount, bool noCards, ColorScheme cs) {
    final hasDue = dueCount > 0 && !noCards;
    final upcomingCount = noCards
        ? 0
        : widget.srService.getUpcomingCards(_allCards).length;
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
                    onPressed: _startSRReview,
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
                onPressed: () => _startSRReview(earlyPractice: true),
                icon: Icon(Icons.bolt_rounded,
                    size: 18, color: cs.secondary),
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

  Widget _buildNormalReviewScreen() {
    if (currentCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No cards in this deck'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _endReview,
              child: const Text('Back to Deck List'),
            ),
          ],
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  '${currentCardIndex + 1} / ${currentCards.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (currentCardIndex + 1) / currentCards.length,
                      minHeight: 8,
                      backgroundColor: colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildFlipCard()),
          AnimatedBuilder(
            animation: _flipController,
            builder: (context, _) {
              final notFlipped = _flipController.value < 0.5;
              return AnimatedOpacity(
                opacity: notFlipped ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap card to flip',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary.withOpacity(0.6),
                        ),
                  ),
                ),
              );
            },
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navButton(
                  icon: Icons.arrow_back_rounded,
                  enabled: currentCardIndex > 0,
                  onPressed: _previousCard,
                  colorScheme: colorScheme,
                ),
                _navButton(
                  icon: Icons.flip_rounded,
                  enabled: true,
                  onPressed: _toggleCard,
                  colorScheme: colorScheme,
                ),
                AnimatedBuilder(
                  animation: _flipController,
                  builder: (context, _) {
                    final canNext = _hasFlipped &&
                        currentCardIndex < currentCards.length - 1;
                    return _navButton(
                      icon: Icons.arrow_forward_rounded,
                      enabled: canNext,
                      onPressed: _nextCard,
                      colorScheme: colorScheme,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSRReviewScreen() {
    if (_srSessionComplete) return _buildSRSessionComplete();

    if (currentCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No cards due today!'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _endReview,
              child: const Text('Back'),
            ),
          ],
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final total = currentCards.length;

    return SafeArea(
      child: Column(
        children: [
          // Progress header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.psychology_rounded,
                        size: 16, color: colorScheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      '${currentCardIndex + 1} / $total',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.secondary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (currentCardIndex + 1) / total,
                      minHeight: 8,
                      backgroundColor: colorScheme.secondary.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(colorScheme.secondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildFlipCard()),
          AnimatedBuilder(
            animation: _flipController,
            builder: (context, _) {
              final notFlipped = _flipController.value < 0.5;
              return AnimatedOpacity(
                opacity: notFlipped ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap card to flip, then rate',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.secondary.withOpacity(0.6),
                        ),
                  ),
                ),
              );
            },
          ),
          _buildSRDifficultyButtons(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? colorScheme.primaryContainer.withOpacity(0.2)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: enabled ? onPressed : null,
        color: enabled ? colorScheme.primary : Colors.grey,
        iconSize: 28,
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSR = _reviewMode == _ReviewMode.spaced;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: isReviewing
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _endReview,
              )
            : null,
        title: isReviewing
            ? Row(
                children: [
                  if (isSR) ...[
                    Icon(Icons.psychology_rounded,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _srSessionComplete
                          ? 'Session Complete'
                          : _srEarlyPractice
                              ? 'Early Practice'
                              : 'Spaced Repetition',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ] else
                    Text(
                      selectedDeck?.name ?? 'All Decks',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                ],
              )
            : Row(
                children: [
                  Icon(
                    Icons.visibility,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Review',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
        automaticallyImplyLeading: !isReviewing,
        actions: isReviewing && !isSR
            ? [
                IconButton(
                  icon: Icon(
                    _answerFirst
                        ? Icons.question_answer_rounded
                        : Icons.swap_horiz_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: _answerFirst
                      ? 'Front: ${selectedDeck?.side2Label ?? 'Back'}'
                      : 'Front: ${selectedDeck?.side1Label ?? 'Front'}',
                  onPressed: _toggleDirection,
                ),
              ]
            : null,
      ),
      body: isReviewing
          ? (isSR ? _buildSRReviewScreen() : _buildNormalReviewScreen())
          : _buildDeckList(),
    );
  }
}
