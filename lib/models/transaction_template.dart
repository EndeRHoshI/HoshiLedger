class TemplateEntry {
  final int amount;
  final int type;
  final String category;
  final String note;

  const TemplateEntry({
    required this.amount,
    required this.type,
    required this.category,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'type': type,
    'category': category,
    'note': note,
  };

  factory TemplateEntry.fromMap(Map<String, dynamic> map) => TemplateEntry(
    amount: map['amount'] as int,
    type: map['type'] as int,
    category: map['category'] as String,
    note: map['note'] as String? ?? '',
  );
}

class TransactionTemplate {
  final int id;
  final String name;
  final List<TemplateEntry> entries;

  TransactionTemplate({
    required this.id,
    required this.name,
    required List<TemplateEntry> entries,
  }) : entries = List.unmodifiable(entries);

  int get totalExpense => entries
      .where((entry) => entry.type == 0)
      .fold(0, (sum, entry) => sum + entry.amount);

  int get totalIncome => entries
      .where((entry) => entry.type == 1)
      .fold(0, (sum, entry) => sum + entry.amount);
}

class TemplateApplicationResult {
  final int count;
  final DateTime date;

  const TemplateApplicationResult({required this.count, required this.date});
}
