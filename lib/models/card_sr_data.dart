import 'package:objectbox/objectbox.dart';

@Entity()
class CardSRData {
  @Id()
  int id;

  @Index()
  String cardId;

  int repetitions;
  double easeFactor;
  int intervalDays;

  @Property(type: PropertyType.date)
  DateTime? nextReviewDate;

  @Property(type: PropertyType.date)
  DateTime? lastReviewDate;

  CardSRData({
    this.id = 0,
    required this.cardId,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.intervalDays = 1,
    this.nextReviewDate,
    this.lastReviewDate,
  });
}
