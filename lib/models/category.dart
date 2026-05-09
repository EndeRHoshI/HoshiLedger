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
      // 餐饮类
      case 'restaurant': return Icons.restaurant;
      case 'fastfood': return Icons.fastfood;
      case 'local_cafe': return Icons.local_cafe;
      // 交通类
      case 'directions_bus': return Icons.directions_bus;
      case 'local_gas_station': return Icons.local_gas_station;
      case 'flight': return Icons.flight;
      // 购物与生活
      case 'shopping_cart': return Icons.shopping_cart;
      case 'checkroom': return Icons.checkroom;
      case 'pets': return Icons.pets;
      // 娱乐与运动
      case 'movie': return Icons.movie;
      case 'sports_esports': return Icons.sports_esports;
      case 'fitness_center': return Icons.fitness_center;
      // 医疗与家居
      case 'medical_services': return Icons.medical_services;
      case 'home': return Icons.home;
      case 'electrical_services': return Icons.electrical_services;
      case 'handyman': return Icons.handyman;
      // 教育与个人
      case 'school': return Icons.school;
      case 'self_improvement': return Icons.self_improvement;
      case 'volunteer_activism': return Icons.volunteer_activism;
      // 财务类
      case 'payments': return Icons.payments;
      case 'account_balance': return Icons.account_balance;
      case 'savings': return Icons.savings;
      case 'trending_up': return Icons.trending_up;
      // 礼赠与奖励
      case 'work': return Icons.work;
      case 'redeem': return Icons.redeem;
      case 'card_giftcard': return Icons.card_giftcard;
      case 'celebration': return Icons.celebration;
      // 默认
      default: return Icons.category;
    }
  }
}
