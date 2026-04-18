class FlashCard {
  String id;
  String question;
  String answer;

  FlashCard({required this.id, required this.question, required this.answer});

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'answer': answer,
  };

  factory FlashCard.fromJson(Map<String, dynamic> json) => FlashCard(
    id: json['id'],
    question: json['question'],
    answer: json['answer'],
  );
}

class Deck {
  String id;
  String name;
  String side1Label;
  String side2Label;
  List<FlashCard> cards;

  Deck({
    required this.id,
    required this.name,
    this.side1Label = 'Front',
    this.side2Label = 'Back',
    required this.cards,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'side1Label': side1Label,
    'side2Label': side2Label,
    'cards': cards.map((card) => card.toJson()).toList(),
  };

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
    id: json['id'],
    name: json['name'],
    side1Label: json['side1Label'] ?? 'Front',
    side2Label: json['side2Label'] ?? 'Back',
    cards: (json['cards'] as List).map((card) => FlashCard.fromJson(card)).toList(),
  );
}