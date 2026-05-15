class NoteTemplate {
  final int? id;
  final String category;
  final String note;
  final int sortOrder;

  NoteTemplate({
    this.id,
    required this.category,
    required this.note,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'note': note,
        'sort_order': sortOrder,
      };

  factory NoteTemplate.fromMap(Map<String, dynamic> map) => NoteTemplate(
        id: map['id'],
        category: map['category'],
        note: map['note'],
        sortOrder: map['sort_order'] ?? 0,
      );
}
