class Category {
  final int? id;
  final String name;
  final int type; // 0 for expense, 1 for income
  final String icon; // Icon name or code point

  Category({
    this.id,
    required this.name,
    required this.type,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      icon: map['icon'],
    );
  }
}
