import 'package:flutter/material.dart';
import 'package:fuzzy/fuzzy.dart';
import '../widgets/add_deck_dialog.dart';
import '../widgets/edit_deck_dialog.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../models/deck.dart';
import '../services/storage_service.dart';
import '../services/csv_service.dart';
import 'deck_detail_screen.dart';

class DecksTab extends StatefulWidget {
  final StorageService storage;
  const DecksTab({required this.storage, super.key});

  @override
  State<DecksTab> createState() => _DecksTabState();
}

class _DecksTabState extends State<DecksTab> {
  List<Deck> decks = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDecks();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Deck> get _filteredDecks {
    if (_searchQuery.isEmpty) return decks;
    final fuse = Fuzzy<Deck>(
      decks,
      options: FuzzyOptions(keys: [WeightedKey(name: 'name', getter: (d) => d.name, weight: 1)]),
    );
    return fuse.search(_searchQuery).map((r) => r.item).toList();
  }

  Future<void> _loadDecks() async {
    final loadedDecks = await widget.storage.getDecks();
    setState(() => decks = loadedDecks);
  }

  Future<void> _addDeck() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddDeckDialog(),
    );
    if (result != null && result['name']!.isNotEmpty) {
      final newDeck = Deck(
        id: DateTime.now().toString(),
        name: result['name']!,
        side1Label: result['side1Label']!,
        side2Label: result['side2Label']!,
        cards: [],
      );
      setState(() => decks.add(newDeck));
      await widget.storage.saveDecks(decks);
    }
  }

  Future<void> _editDeck(int index) async {
    final deck = decks[index];
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => EditDeckDialog(
        initialName: deck.name,
        initialSide1Label: deck.side1Label,
        initialSide2Label: deck.side2Label,
      ),
    );
    if (result != null && result['name']!.isNotEmpty) {
      setState(() {
        decks[index] = Deck(
          id: deck.id,
          name: result['name']!,
          side1Label: result['side1Label']!,
          side2Label: result['side2Label']!,
          cards: deck.cards,
        );
      });
      await widget.storage.saveDecks(decks);
    }
  }

  Future<void> _importDeck() async {
    final cards = await CsvService.importCards();
    if (!mounted) return;
    if (cards == null) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddDeckDialog(),
    );
    if (result == null || result['name']!.isEmpty) return;

    final newDeck = Deck(
      id: DateTime.now().toString(),
      name: result['name']!,
      side1Label: result['side1Label']!,
      side2Label: result['side2Label']!,
      cards: cards
          .asMap()
          .entries
          .map((e) => FlashCard(
                id: '${DateTime.now().microsecondsSinceEpoch}_${e.key}',
                question: e.value['question']!,
                answer: e.value['answer']!,
              ))
          .toList(),
    );
    setState(() => decks.add(newDeck));
    await widget.storage.saveDecks(decks);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${cards.length} card(s) into "${result['name']}".')),
    );
  }

  Future<void> _deleteDeck(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        itemName: decks[index].name,
      ),
    );

    if (confirmed == true) {
      setState(() => decks.removeAt(index));
      await widget.storage.saveDecks(decks);
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Decks', style: TextStyle(fontWeight: FontWeight.bold),),
                Text(
                  '${decks.length} ${decks.length == 1 ? 'deck' : 'decks'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Import Deck from CSV',
            onPressed: _importDeck,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search decks…',
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
      ),
      body: _filteredDecks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_books,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty ? 'No Decks Yet' : 'No results',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isEmpty ? 'Create your first deck to get started!' : 'Try a different search term.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: _filteredDecks.length,
              itemBuilder: (context, index) {
                final deck = _filteredDecks[index];
                final cardCount = deck.cards.length;

                return Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              DeckDetailScreen(
                            deck: deck,
                            storage: widget.storage,
                            decks: decks,
                          ),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                      await _loadDecks();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Header with Card Count and Menu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Card Count Badge (Top Left)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$cardCount cards',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ),
                            // Menu Button (Top Right)
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (value) {
                                final originalIndex = decks.indexWhere((d) => d.id == deck.id);
                                if (value == 'edit') {
                                  _editDeck(originalIndex);
                                } else if (value == 'delete') {
                                  _deleteDeck(originalIndex);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 20),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Deck Title (Centered in the Card)
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                deck.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDeck,
        icon: const Icon(Icons.add),
        label: const Text('New Deck'),
      ),
    );
  }
}
