import 'package:csv/csv.dart';

import '../models/deck.dart';
import '../models/sync_models.dart';

class CsvImportService {
  static const String _defaultDeckName = 'Imported';

  static ({List<Deck> decks, CsvImportResult result}) importFromCsv({
    required String csvContent,
    required List<Deck> existingDecks,
  }) {
    final rows = _parseRows(csvContent);
    if (rows.isEmpty) {
      throw const FormatException('CSV is empty.');
    }

    final updatedDecks = existingDecks
        .map(
          (deck) => Deck(
            id: deck.id,
            name: deck.name,
            cards: deck.cards
                .map(
                  (card) => FlashCard(
                    id: card.id,
                    question: card.question,
                    answer: card.answer,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    final deckLookup = <String, Deck>{
      for (final deck in updatedDecks) deck.name.trim().toLowerCase(): deck,
    };

    int decksCreated = 0;
    int cardsImported = 0;

    final header = rows.first.map(_normalizeCell).toList();
    final hasHeader = _looksLikeHeader(header);
    final dataRows = hasHeader ? rows.skip(1) : rows;

    for (final row in dataRows) {
      if (_isEmptyRow(row)) continue;
      if (hasHeader) {
        final mapped = _mapRow(header, row);
        final deckName = _firstNonEmpty([
              mapped['deck'],
              mapped['deck_name'],
              mapped['name'],
            ]) ??
            _defaultDeckName;
        final question = _firstNonEmpty([
          mapped['question'],
          mapped['front'],
          mapped['word'],
          mapped['term'],
        ]);
        final answer = _firstNonEmpty([
          mapped['answer'],
          mapped['back'],
          mapped['meaning'],
          mapped['definition'],
        ]);

        final target = _ensureDeck(
          deckLookup: deckLookup,
          decks: updatedDecks,
          deckName: deckName,
          onCreate: () => decksCreated++,
        );

        if ((question?.isNotEmpty ?? false) || (answer?.isNotEmpty ?? false)) {
          _appendCard(target, question ?? '', answer ?? '');
          cardsImported++;
        }
      } else {
        final question = row.isNotEmpty ? row[0].toString().trim() : '';
        final answer = row.length > 1 ? row[1].toString().trim() : '';
        final deckName =
            row.length > 2 ? row[2].toString().trim() : _defaultDeckName;

        final target = _ensureDeck(
          deckLookup: deckLookup,
          decks: updatedDecks,
          deckName: deckName.isEmpty ? _defaultDeckName : deckName,
          onCreate: () => decksCreated++,
        );

        if (question.isNotEmpty || answer.isNotEmpty) {
          _appendCard(target, question, answer);
          cardsImported++;
        }
      }
    }

    return (
      decks: updatedDecks,
      result: CsvImportResult(
        decksCreated: decksCreated,
        cardsImported: cardsImported,
      ),
    );
  }

  static List<List<dynamic>> _parseRows(String input) {
    final commaRows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
      fieldDelimiter: ',',
    ).convert(input);

    final appearsTabSeparated = commaRows.isNotEmpty &&
        commaRows.first.length == 1 &&
        commaRows.first.first.toString().contains('\t');
    if (!appearsTabSeparated) {
      return commaRows;
    }

    try {
      return const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
        fieldDelimiter: '\t',
      ).convert(input);
    } catch (_) {
      return commaRows;
    }
  }

  static Deck _ensureDeck({
    required Map<String, Deck> deckLookup,
    required List<Deck> decks,
    required String deckName,
    required void Function() onCreate,
  }) {
    final key = deckName.trim().toLowerCase();
    final existing = deckLookup[key];
    if (existing != null) return existing;

    final newDeck = Deck(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: deckName.trim(),
      cards: [],
    );
    decks.add(newDeck);
    deckLookup[key] = newDeck;
    onCreate();
    return newDeck;
  }

  static void _appendCard(Deck deck, String question, String answer) {
    deck.cards.add(
      FlashCard(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        question: question,
        answer: answer,
      ),
    );
  }

  static Map<String, String> _mapRow(List<String> header, List<dynamic> row) {
    final map = <String, String>{};
    for (int i = 0; i < header.length; i++) {
      if (i >= row.length) continue;
      map[header[i]] = row[i].toString().trim();
    }
    return map;
  }

  static bool _looksLikeHeader(List<String> header) {
    const known = {
      'deck',
      'deck_name',
      'name',
      'question',
      'answer',
      'front',
      'back',
      'word',
      'meaning',
      'term',
      'definition',
    };
    return header.any(known.contains);
  }

  static bool _isEmptyRow(List<dynamic> row) {
    return row.every((cell) => cell.toString().trim().isEmpty);
  }

  static String _normalizeCell(dynamic value) {
    return value.toString().trim().toLowerCase();
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
