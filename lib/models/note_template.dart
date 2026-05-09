class NoteTemplate {
  final int? id;
  final String category;
  final String note;

  NoteTemplate({
    this.id,
    required this.category,
    required this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'note': note,
      };

  factory NoteTemplate.fromMap(Map<String, dynamic> map) => NoteTemplate(
        id: map['id'],
        category: map['category'],
        note: map['note'],
      );
}
