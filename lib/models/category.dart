import 'package:flutter/material.dart';

class Category {
  final int? id;
  final String name;
  final int type; // 0 for expense, 1 for income
  final String icon; // Icon name or code point

  static const List<String> availableIcons = [
    'restaurant', 'fastfood', 'local_cafe', 'local_dining',
    'shopping_cart', 'local_mall', 'store',
    'directions_bus', 'directions_car', 'local_taxi', 'train', 'two_wheeler', 'flight', 'luggage',
    'smartphone', 'computer', 'devices',
    'icecream', 'liquor', 'wine_bar',
    'work', 'business_center', 'attach_money', 'payments', 'account_balance', 'savings', 'trending_up',
    'people', 'family_restroom', 'groups', 'elderly',
    'favorite', 'celebration', 'volunteer_activism', 'redeem', 'card_giftcard', 'emoji_events',
    'face', 'spa', 'brush',
    'home', 'chair', 'bed', 'build', 'handyman',
    'medical_services', 'local_hospital',
    'checkroom', 'dry_cleaning',
    'water_drop', 'phishing',
    'eco', 'grass',
    'gavel', 'receipt_long',
    'menu_book', 'school',
    'sports_esports', 'movie', 'fitness_center', 'sports_soccer',
    'pets',
    'category', 'more_horiz'
  ];

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
      case 'restaurant': return Icons.restaurant;
      case 'fastfood': return Icons.fastfood;
      case 'local_cafe': return Icons.local_cafe;
      case 'local_dining': return Icons.local_dining;
      case 'shopping_cart': return Icons.shopping_cart;
      case 'local_mall': return Icons.local_mall;
      case 'store': return Icons.store;
      case 'directions_bus': return Icons.directions_bus;
      case 'directions_car': return Icons.directions_car;
      case 'local_taxi': return Icons.local_taxi;
      case 'train': return Icons.train;
      case 'two_wheeler': return Icons.two_wheeler;
      case 'flight': return Icons.flight;
      case 'luggage': return Icons.luggage;
      case 'smartphone': return Icons.smartphone;
      case 'computer': return Icons.computer;
      case 'devices': return Icons.devices;
      case 'icecream': return Icons.icecream;
      case 'liquor': return Icons.liquor;
      case 'wine_bar': return Icons.wine_bar;
      case 'work': return Icons.work;
      case 'business_center': return Icons.business_center;
      case 'attach_money': return Icons.attach_money;
      case 'payments': return Icons.payments;
      case 'account_balance': return Icons.account_balance;
      case 'savings': return Icons.savings;
      case 'trending_up': return Icons.trending_up;
      case 'people': return Icons.people;
      case 'family_restroom': return Icons.family_restroom;
      case 'groups': return Icons.groups;
      case 'elderly': return Icons.elderly;
      case 'favorite': return Icons.favorite;
      case 'celebration': return Icons.celebration;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'redeem': return Icons.redeem;
      case 'card_giftcard': return Icons.card_giftcard;
      case 'emoji_events': return Icons.emoji_events;
      case 'face': return Icons.face;
      case 'spa': return Icons.spa;
      case 'brush': return Icons.brush;
      case 'home': return Icons.home;
      case 'chair': return Icons.chair;
      case 'bed': return Icons.bed;
      case 'build': return Icons.build;
      case 'handyman': return Icons.handyman;
      case 'medical_services': return Icons.medical_services;
      case 'local_hospital': return Icons.local_hospital;
      case 'checkroom': return Icons.checkroom;
      case 'dry_cleaning': return Icons.dry_cleaning;
      case 'water_drop': return Icons.water_drop;
      case 'phishing': return Icons.phishing;
      case 'eco': return Icons.eco;
      case 'grass': return Icons.grass;
      case 'gavel': return Icons.gavel;
      case 'receipt_long': return Icons.receipt_long;
      case 'menu_book': return Icons.menu_book;
      case 'school': return Icons.school;
      case 'sports_esports': return Icons.sports_esports;
      case 'movie': return Icons.movie;
      case 'fitness_center': return Icons.fitness_center;
      case 'sports_soccer': return Icons.sports_soccer;
      case 'pets': return Icons.pets;
      case 'category': return Icons.category;
      case 'more_horiz': return Icons.more_horiz;
      default: return Icons.category;
    }
  }
}
