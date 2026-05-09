import 'package:flutter/material.dart';

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

  static IconData getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'movie':
        return Icons.movie;
      case 'medical_services':
        return Icons.medical_services;
      case 'home':
        return Icons.home;
      case 'payments':
        return Icons.payments;
      case 'trending_up':
        return Icons.trending_up;
      case 'work':
        return Icons.work;
      case 'redeem':
        return Icons.redeem;
      default:
        return Icons.category;
    }
  }
}
