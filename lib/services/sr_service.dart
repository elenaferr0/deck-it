import 'package:shared_preferences/shared_preferences.dart';
import '../models/card_sr_data.dart';
import '../models/deck.dart';
import '../objectbox.g.dart';
import 'objectbox_service.dart';

enum Difficulty { again, hard, good, easy }

extension DifficultyLabel on Difficulty {
  String get label => switch (this) {
        Difficulty.again => 'Again',
        Difficulty.hard => 'Hard',
        Difficulty.good => 'Good',
        Difficulty.easy => 'Easy',
      };

  // SM-2 quality score (0-5)
  int get quality => switch (this) {
        Difficulty.again => 1,
        Difficulty.hard => 3,
        Difficulty.good => 4,
        Difficulty.easy => 5,
      };
}

class SRService {
  final ObjectBoxService _obx;
  final SharedPreferences _prefs;

  static const String _dailyLimitKey = 'sr_daily_limit';
  static const int defaultDailyLimit = 20;

  SRService(this._obx, this._prefs);

  int get dailyLimit => _prefs.getInt(_dailyLimitKey) ?? defaultDailyLimit;

  Future<void> setDailyLimit(int limit) async {
    await _prefs.setInt(_dailyLimitKey, limit);
  }

  CardSRData? getSRData(String cardId) {
    final query = _obx.srBox.query(CardSRData_.cardId.equals(cardId)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  bool isDueToday(String cardId) {
    final srData = getSRData(cardId);
    if (srData == null) return true; // new card = due
    if (srData.nextReviewDate == null) return true;
    final today = _dateOnly(DateTime.now());
    final next = _dateOnly(srData.nextReviewDate!);
    return !next.isAfter(today);
  }

  /// Returns cards due today up to [limit] (default: dailyLimit).
  /// Due cards first, then new cards.
  List<FlashCard> getDueCards(List<FlashCard> allCards, {int? limit}) {
    final max = limit ?? dailyLimit;
    final due = <FlashCard>[];
    final newCards = <FlashCard>[];

    for (final card in allCards) {
      final srData = getSRData(card.id);
      if (srData == null) {
        newCards.add(card);
      } else if (srData.nextReviewDate == null) {
        newCards.add(card);
      } else {
        final today = _dateOnly(DateTime.now());
        final next = _dateOnly(srData.nextReviewDate!);
        if (!next.isAfter(today)) due.add(card);
      }
    }

    final combined = [...due, ...newCards];
    return combined.take(max).toList();
  }

  /// All due cards regardless of daily limit.
  List<FlashCard> getAllDueCards(List<FlashCard> allCards) {
    return getDueCards(allCards, limit: allCards.length);
  }

  int getDueCount(List<FlashCard> allCards) {
    return getAllDueCards(allCards).length;
  }

  /// Returns the next review interval in days for display purposes.
  int previewInterval(String cardId, Difficulty difficulty) {
    final srData = getSRData(cardId) ?? CardSRData(cardId: cardId);
    return _calculateInterval(srData, difficulty);
  }

  int _calculateInterval(CardSRData srData, Difficulty difficulty) {
    final quality = difficulty.quality;
    final failed = quality < 3; // again only (quality=1)

    if (failed) return 1;

    int interval;
    if (srData.repetitions == 0) {
      interval = 1;
    } else if (srData.repetitions == 1) {
      interval = 6;
    } else {
      interval = (srData.intervalDays * srData.easeFactor).round();
    }

    // Hard: reduce 20%
    if (difficulty == Difficulty.hard) {
      interval = (interval * 0.8).round().clamp(1, 9999);
    }
    // Easy: boost 30%
    if (difficulty == Difficulty.easy) {
      interval = (interval * 1.3).round();
    }

    return interval.clamp(1, 36500);
  }

  void rateCard(String cardId, Difficulty difficulty) {
    var srData = getSRData(cardId) ?? CardSRData(cardId: cardId);
    final quality = difficulty.quality;
    final failed = quality < 3;

    if (failed) {
      srData.repetitions = 0;
      srData.intervalDays = 1;
    } else {
      srData.intervalDays = _calculateInterval(srData, difficulty);
      srData.repetitions++;
    }

    // SM-2 ease factor update: EF' = EF + 0.1 - (5-q)(0.08 + (5-q)*0.02)
    final q = quality.toDouble();
    final newEF = srData.easeFactor + 0.1 - (5 - q) * (0.08 + (5 - q) * 0.02);
    srData.easeFactor = newEF.clamp(1.3, 5.0);

    final now = DateTime.now();
    srData.lastReviewDate = now;
    srData.nextReviewDate = now.add(Duration(days: srData.intervalDays));

    _obx.srBox.put(srData);
  }

  /// Cards not yet due, sorted by soonest next review first.
  /// Useful for early/voluntary practice sessions.
  List<FlashCard> getUpcomingCards(List<FlashCard> allCards, {int? limit}) {
    final max = limit ?? dailyLimit;
    final today = _dateOnly(DateTime.now());
    final upcoming = <(DateTime, FlashCard)>[];

    for (final card in allCards) {
      final srData = getSRData(card.id);
      if (srData?.nextReviewDate == null) continue;
      final next = _dateOnly(srData!.nextReviewDate!);
      if (next.isAfter(today)) {
        upcoming.add((next, card));
      }
    }

    upcoming.sort((a, b) => a.$1.compareTo(b.$1));
    return upcoming.map((e) => e.$2).take(max).toList();
  }

  /// Resets all SR data for a card (e.g. when card is deleted).
  void deleteCardData(String cardId) {
    final query = _obx.srBox.query(CardSRData_.cardId.equals(cardId)).build();
    final ids = query.findIds();
    query.close();
    _obx.srBox.removeMany(ids);
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
