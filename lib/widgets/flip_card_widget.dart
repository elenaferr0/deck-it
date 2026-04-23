import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/deck.dart';

class FlipCardWidget extends StatelessWidget {
  final AnimationController flipController;
  final FlashCard card;
  final String side1Label;
  final String side2Label;
  final bool answerFirst;
  final VoidCallback onTap;

  const FlipCardWidget({
    required this.flipController,
    required this.card,
    required this.side1Label,
    required this.side2Label,
    required this.answerFirst,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final side1 = side1Label.toUpperCase();
    final side2 = side2Label.toUpperCase();
    final frontText = answerFirst ? card.answer : card.question;
    final backText = answerFirst ? card.question : card.answer;
    final frontLabel = answerFirst ? side2 : side1;
    final backLabel = answerFirst ? side1 : side2;
    final hasBack = backText.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: flipController,
        builder: (context, _) {
          final angle = flipController.value * math.pi;
          final isShowingFront = flipController.value <= 0.5;

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
}
