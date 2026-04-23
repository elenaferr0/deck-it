import 'package:flutter/material.dart';
import 'package:fuzzy/fuzzy.dart';
import '../models/deck.dart';
import '../widgets/edit_card_dialog.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../services/storage_service.dart';
import '../services/csv_service.dart';

class DeckDetailScreen extends StatefulWidget {
  final Deck deck;
  final StorageService storage;
  final List<Deck> decks;

  const DeckDetailScreen({
    required this.deck,
    required this.storage,
    required this.decks,
    super.key,
  });

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  final _side1Controller = TextEditingController();
  final _side2Controller = TextEditingController();
  final _side1Focus = FocusNode();
  final _side2Focus = FocusNode();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _side1Controller.dispose();
    _side2Controller.dispose();
    _side1Focus.dispose();
    _side2Focus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<FlashCard> get _filteredCards {
    if (_searchQuery.isEmpty) return widget.deck.cards;
    final fuse = Fuzzy<FlashCard>(
      widget.deck.cards,
      options: FuzzyOptions(keys: [
        WeightedKey(name: 'question', getter: (c) => c.question, weight: 0.6),
        WeightedKey(name: 'answer', getter: (c) => c.answer, weight: 0.4),
      ]),
    );
    return fuse.search(_searchQuery).map((r) => r.item).toList();
  }

  Future<void> _submitInlineCard() async {
    final s1 = _side1Controller.text.trim();
    final s2 = _side2Controller.text.trim();
    if (s1.isEmpty) {
      _side1Focus.requestFocus();
      return;
    }
    setState(() {
      widget.deck.cards.add(FlashCard(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        question: s1,
        answer: s2,
      ));
    });
    await widget.storage.saveDecks(widget.decks);
    _side1Controller.clear();
    _side2Controller.clear();
    _side1Focus.requestFocus();
  }

  Future<void> _editCard(int index) async {
    final card = widget.deck.cards[index];
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => EditCardDialog(
        initialQuestion: card.question,
        initialAnswer: card.answer,
        side1Label: widget.deck.side1Label,
        side2Label: widget.deck.side2Label,
      ),
    );
    if (result != null) {
      setState(() {
        widget.deck.cards[index] = FlashCard(
          id: card.id,
          question: result['question']!,
          answer: result['answer']!,
        );
      });
      await widget.storage.saveDecks(widget.decks);
    }
  }

  Future<void> _exportDeck() async {
    if (widget.deck.cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards to export.')),
      );
      return;
    }
    final path = await CsvService.exportDeck(widget.deck);
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to: $path')),
      );
    }
  }

  Future<void> _importCards() async {
    final cards = await CsvService.importCards();
    if (!mounted) return;
    if (cards == null) return;
    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid cards found in file.')),
      );
      return;
    }
    setState(() {
      for (final c in cards) {
        widget.deck.cards.add(FlashCard(
          id: '${DateTime.now().microsecondsSinceEpoch}_${widget.deck.cards.length}',
          question: c['question']!,
          answer: c['answer']!,
        ));
      }
    });
    await widget.storage.saveDecks(widget.decks);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${cards.length} card(s).')),
    );
  }

  Future<void> _deleteCard(int index) async {
    final card = widget.deck.cards[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        itemName: card.question,
      ),
    );

    if (confirmed == true) {
      setState(() {
        widget.deck.cards.removeAt(index);
      });
      await widget.storage.saveDecks(widget.decks);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.library_books,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.deck.name,
                overflow: TextOverflow.ellipsis, // Truncate with ellipsis
                style: Theme.of(context).textTheme.titleLarge, // Use titleLarge for the text style
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search cards…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') _exportDeck();
              if (value == 'import') _importCards();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, size: 20),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Import CSV'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: widget.deck.cards.isEmpty && _searchQuery.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_add,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No cards yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first flashcard to get started',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color:
                                    Theme.of(context).textTheme.bodySmall?.color,
                              ),
                        ),
                      ],
                    ),
                  )
                : _filteredCards.isEmpty
                    ? Center(
                        child: Text(
                          'No results for "$_searchQuery"',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                        ),
                      )
                    : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: _filteredCards.length,
                    itemBuilder: (context, index) {
                      final card = _filteredCards[index];
                      final originalIndex = widget.deck.cards.indexWhere((c) => c.id == card.id);
                      final cs = Theme.of(context).colorScheme;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        elevation: 1,
                        child: ListTile(
                          title: Text(
                            card.question,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: card.answer.trim().isEmpty
                              ? null
                              : Text(
                                  card.answer,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 20),
                                color: cs.primary,
                                onPressed: () => _editCard(originalIndex),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded, size: 20),
                                color: cs.error,
                                onPressed: () => _deleteCard(originalIndex),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _buildInlineAddForm(),
        ],
      ),
    );
  }

  Widget _buildInlineAddForm() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom,
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
                '${widget.deck.cards.length} cards',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _side1Controller,
            focusNode: _side1Focus,
            decoration: InputDecoration(
              labelText: widget.deck.side1Label,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _side2Focus.requestFocus(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _side2Controller,
                  focusNode: _side2Focus,
                  decoration: InputDecoration(
                    labelText: widget.deck.side2Label,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitInlineCard(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submitInlineCard,
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