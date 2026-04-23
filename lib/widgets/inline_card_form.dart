import 'package:flutter/material.dart';

class InlineCardForm extends StatelessWidget {
  final TextEditingController side1Controller;
  final TextEditingController side2Controller;
  final FocusNode side1Focus;
  final FocusNode side2Focus;
  final String side1Label;
  final String side2Label;
  final int cardCount;
  final VoidCallback onSubmit;

  const InlineCardForm({
    required this.side1Controller,
    required this.side2Controller,
    required this.side1Focus,
    required this.side2Focus,
    required this.side1Label,
    required this.side2Label,
    required this.cardCount,
    required this.onSubmit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.add_card_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'New card',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Text(
                '$cardCount cards',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: side1Controller,
            focusNode: side1Focus,
            decoration: InputDecoration(
              labelText: side1Label,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => side2Focus.requestFocus(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: side2Controller,
                  focusNode: side2Focus,
                  decoration: InputDecoration(
                    labelText: side2Label,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                child: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
