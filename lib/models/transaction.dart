class TransactionModel {
  final int? id;
  final int amount; // Amount in cents (1.00 = 100)
  final int type; // 0 for expense, 1 for income
  final String category;
  final String date; // YYYY-MM-DD
  final String note;

  TransactionModel({
    this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note = '',
  });

  double get amountDouble => amount / 100.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date,
      'note': note,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      amount: map['amount'],
      type: map['type'],
      category: map['category'],
      date: map['date'],
      note: map['note'] ?? '',
    );
  }
}
