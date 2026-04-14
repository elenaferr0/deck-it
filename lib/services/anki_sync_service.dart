import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/deck.dart';
import '../models/sync_models.dart';

class AnkiSyncService {
  static Map<String, dynamic> toAnkiInterchangePayload(List<Deck> decks) {
    return {
      'format': 'anki-json',
      'version': 1,
      'decks': decks
          .map(
            (deck) => {
              'name': deck.name,
              'cards': deck.cards
                  .map(
                    (card) => {
                      'id': card.id,
                      'front': card.question,
                      'back': card.answer,
                      'fields': {
                        'Front': card.question,
                        'Back': card.answer,
                      },
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }

  static List<Deck> fromAnkiInterchangePayload(Map<String, dynamic> payload) {
    final rawDecks = payload['decks'];
    if (rawDecks is! List) {
      throw const FormatException('Invalid sync payload: missing decks list.');
    }

    return rawDecks.map((rawDeck) {
      final map = rawDeck as Map<String, dynamic>;
      final name = (map['name'] ?? '').toString().trim();
      final cardsRaw = map['cards'];
      final cards = cardsRaw is List
          ? cardsRaw.map((rawCard) {
              final cardMap = rawCard as Map<String, dynamic>;
              final fields = cardMap['fields'] as Map<String, dynamic>?;
              final front = (cardMap['front'] ??
                      fields?['Front'] ??
                      fields?['Question'] ??
                      '')
                  .toString();
              final back = (cardMap['back'] ??
                      fields?['Back'] ??
                      fields?['Answer'] ??
                      '')
                  .toString();
              return FlashCard(
                id: (cardMap['id'] ?? DateTime.now().toIso8601String())
                    .toString(),
                question: front,
                answer: back,
              );
            }).toList()
          : <FlashCard>[];

      return Deck(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.isEmpty ? 'Imported' : name,
        cards: cards,
      );
    }).toList();
  }

  static Future<void> pushDecks({
    required SyncSettings settings,
    required List<Deck> decks,
    http.Client? client,
  }) async {
    final syncClient = client ?? http.Client();
    try {
      final uri = _resolveUri(settings.serverUrl, '/api/v1/decks/import');
      final response = await syncClient.post(
        uri,
        headers: _headers(settings),
        body: jsonEncode(toAnkiInterchangePayload(decks)),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Sync push failed (${response.statusCode}): ${response.body}',
        );
      }
    } finally {
      if (client == null) {
        syncClient.close();
      }
    }
  }

  static Future<AnkiSyncResult> pullAndMergeDecks({
    required SyncSettings settings,
    required List<Deck> localDecks,
    required Future<void> Function(List<Deck> decks) saveDecks,
    http.Client? client,
  }) async {
    final syncClient = client ?? http.Client();
    try {
      final uri = _resolveUri(settings.serverUrl, '/api/v1/decks/export');
      final response = await syncClient.get(uri, headers: _headers(settings));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Sync pull failed (${response.statusCode}): ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Sync response is not a valid JSON object.');
      }

      final remoteDecks = fromAnkiInterchangePayload(decoded);
      final merged = mergeDecks(localDecks, remoteDecks);
      await saveDecks(merged.decks);
      return AnkiSyncResult(
        decksImported: merged.decksImported,
        cardsImported: merged.cardsImported,
      );
    } finally {
      if (client == null) {
        syncClient.close();
      }
    }
  }

  static ({List<Deck> decks, int decksImported, int cardsImported}) mergeDecks(
    List<Deck> localDecks,
    List<Deck> remoteDecks,
  ) {
    final mergedDecks = localDecks
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
    final lookup = <String, Deck>{
      for (final deck in mergedDecks) deck.name.trim().toLowerCase(): deck,
    };

    int decksImported = 0;
    int cardsImported = 0;

    for (final remote in remoteDecks) {
      final key = remote.name.trim().toLowerCase();
      var target = lookup[key];
      if (target == null) {
        target = Deck(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: remote.name,
          cards: [],
        );
        mergedDecks.add(target);
        lookup[key] = target;
        decksImported++;
      }

      final knownCards = target.cards
          .map((c) => '${c.question.trim()}\u0000${c.answer.trim()}')
          .toSet();
      for (final remoteCard in remote.cards) {
        final signature =
            '${remoteCard.question.trim()}\u0000${remoteCard.answer.trim()}';
        if (knownCards.contains(signature)) continue;
        target.cards.add(
          FlashCard(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            question: remoteCard.question,
            answer: remoteCard.answer,
          ),
        );
        knownCards.add(signature);
        cardsImported++;
      }
    }

    return (
      decks: mergedDecks,
      decksImported: decksImported,
      cardsImported: cardsImported,
    );
  }

  static Uri _resolveUri(String base, String endpointPath) {
    final cleanBase = base.trim().isEmpty ? 'https://ankiweb.net' : base.trim();
    final baseUri = Uri.parse(cleanBase);
    final normalizedPath = endpointPath.startsWith('/')
        ? endpointPath
        : '/$endpointPath';
    return baseUri.replace(path: normalizedPath);
  }

  static Map<String, String> _headers(SyncSettings settings) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (settings.apiToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${settings.apiToken.trim()}';
    }
    return headers;
  }
}
