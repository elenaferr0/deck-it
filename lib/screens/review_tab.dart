import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../services/storage_service.dart';
import '../services/sr_service.dart';
import '../widgets/flip_card_widget.dart';
import '../widgets/sr_difficulty_buttons.dart';
import '../widgets/sr_session_complete.dart';
import '../widgets/review_deck_list.dart';

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
    if (mounted) setState(() => decks = loadedDecks);
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
    setState(() => _sessionRatings[card.id] = difficulty);
    if (currentCardIndex < currentCards.length - 1) {
      setState(() {
        currentCardIndex++;
        _hasFlipped = false;
      });
      _flipController.value = 0.0;
    } else {
      setState(() => _srSessionComplete = true);
    }
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

  Widget _buildNormalReviewScreen() {
    if (currentCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No cards in this deck'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _endReview, child: const Text('Back to Deck List')),
          ],
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: cs.primary),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (currentCardIndex + 1) / currentCards.length,
                      minHeight: 8,
                      backgroundColor: cs.primary.withOpacity(0.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlipCardWidget(
              flipController: _flipController,
              card: currentCards[currentCardIndex],
              side1Label: selectedDeck?.side1Label ?? 'Front',
              side2Label: selectedDeck?.side2Label ?? 'Back',
              answerFirst: _answerFirst,
              onTap: _toggleCard,
            ),
          ),
          AnimatedBuilder(
            animation: _flipController,
            builder: (context, _) {
              return AnimatedOpacity(
                opacity: _flipController.value < 0.5 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap card to flip',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.primary.withOpacity(0.6),
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
                  colorScheme: cs,
                ),
                _navButton(
                  icon: Icons.flip_rounded,
                  enabled: true,
                  onPressed: _toggleCard,
                  colorScheme: cs,
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
                      colorScheme: cs,
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
    if (_srSessionComplete) {
      return SRSessionComplete(
        sessionRatings: _sessionRatings,
        currentCards: currentCards,
        allCards: _allCards,
        srService: widget.srService,
        srLoadedMore: _srLoadedMore,
        srEarlyPractice: _srEarlyPractice,
        onDone: _endReview,
        onLoadMore: () => _startSRReview(loadMore: true),
        onEarlyPractice: () => _startSRReview(earlyPractice: true),
      );
    }

    if (currentCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No cards due today!'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _endReview, child: const Text('Back')),
          ],
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.psychology_rounded,
                        size: 16, color: cs.secondary),
                    const SizedBox(width: 4),
                    Text(
                      '${currentCardIndex + 1} / ${currentCards.length}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: cs.secondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value:
                          (currentCardIndex + 1) / currentCards.length,
                      minHeight: 8,
                      backgroundColor: cs.secondary.withOpacity(0.2),
                      valueColor:
                          AlwaysStoppedAnimation(cs.secondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlipCardWidget(
              flipController: _flipController,
              card: currentCards[currentCardIndex],
              side1Label: selectedDeck?.side1Label ?? 'Front',
              side2Label: selectedDeck?.side2Label ?? 'Back',
              answerFirst: _answerFirst,
              onTap: _toggleCard,
            ),
          ),
          AnimatedBuilder(
            animation: _flipController,
            builder: (context, _) {
              return AnimatedOpacity(
                opacity: _flipController.value < 0.5 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap card to flip, then rate',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.secondary.withOpacity(0.6),
                        ),
                  ),
                ),
              );
            },
          ),
          SRDifficultyButtons(
            flipController: _flipController,
            card: currentCards[currentCardIndex],
            srService: widget.srService,
            onRate: _rateSRCard,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSR = _reviewMode == _ReviewMode.spaced;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        leading: isReviewing
            ? IconButton(
                icon: const Icon(Icons.arrow_back), onPressed: _endReview)
            : null,
        title: isReviewing
            ? Row(
                children: [
                  if (isSR) ...[
                    Icon(Icons.psychology_rounded,
                        color: cs.secondary, size: 20),
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
                  Icon(Icons.visibility, color: cs.primary),
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
                    color: cs.primary,
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
          : ReviewDeckList(
              decks: decks,
              srService: widget.srService,
              answerFirst: _answerFirst,
              onAnswerFirstChanged: (v) => setState(() => _answerFirst = v),
              onStartReview: _startReview,
              onStartReviewAll: _startReviewAll,
              onStartSRReview: _startSRReview,
              onStartSRReviewEarly: () => _startSRReview(earlyPractice: true),
            ),
    );
  }
}
