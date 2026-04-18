import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../services/storage_service.dart';

class ReviewTab extends StatefulWidget {
  final StorageService storage;
  const ReviewTab({required this.storage, super.key});

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
          currentCards = updatedDeck.cards;
          if (currentCardIndex >= currentCards.length) {
            currentCardIndex =
                currentCards.isEmpty ? 0 : currentCards.length - 1;
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

  void _startReview(Deck deck) {
    _flipController.value = 0.0;
    setState(() {
      selectedDeck = deck;
      currentCards = deck.cards;
      currentCardIndex = 0;
      _hasFlipped = false;
      isReviewing = true;
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

  Widget _buildFlipCard() {
    final card = currentCards[currentCardIndex];
    final colorScheme = Theme.of(context).colorScheme;

    final side1 = selectedDeck!.side1Label.toUpperCase();
    final side2 = selectedDeck!.side2Label.toUpperCase();
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

          // Rotate front 0→90°, back -90°→0 (so it appears unmirrored)
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(isShowingFront ? angle : angle - math.pi);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                                      color:
                                          colorScheme.error.withOpacity(0.6),
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

  Widget _buildDeckList() {
    if (decks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_disabled_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
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
                onSelected: (_) => setState(() {
                  _answerFirst = false;
                }),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Side 2'),
                selected: _answerFirst,
                onSelected: (_) => setState(() {
                  _answerFirst = true;
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: decks.length,
            itemBuilder: (context, index) {
              final deck = decks[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    deck.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${deck.cards.length} cards'),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle_filled),
                    color: Theme.of(context).colorScheme.primary,
                    iconSize: 32,
                    onPressed:
                        deck.cards.isEmpty ? null : () => _startReview(deck),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewScreen() {
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
          // Progress
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
          // Flip card
          Expanded(child: _buildFlipCard()),
          // Hint when card not yet flipped
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
          // Navigation
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
            ? Text(
                selectedDeck?.name ?? '',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
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
        actions: isReviewing
            ? [
                IconButton(
                  icon: Icon(
                    _answerFirst
                        ? Icons.question_answer_rounded
                        : Icons.swap_horiz_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: _answerFirst
                      ? 'Front: ${selectedDeck!.side2Label}'
                      : 'Front: ${selectedDeck!.side1Label}',
                  onPressed: _toggleDirection,
                ),
              ]
            : null,
      ),
      body: isReviewing ? _buildReviewScreen() : _buildDeckList(),
    );
  }
}
