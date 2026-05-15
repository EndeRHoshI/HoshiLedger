import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/note_template.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  // 用于通知分类更新的全局通知器
  static final ValueNotifier<int> categoryUpdateNotifier = ValueNotifier(0);

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'hoshi_ledger.db');
    return await openDatabase(
      path,
      version: 4, // 升级版本，扩充默认分类
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 分类表
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        icon TEXT NOT NULL
      )
    ''');

    // 记账流水表
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        type INTEGER NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT
      )
    ''');

    // 备注模板表（按分类存储历史备注，支持排序）
    await db.execute('''
      CREATE TABLE note_templates(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        note TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        UNIQUE(category, note)
      )
    ''');

    // 预置默认分类
    final List<Map<String, dynamic>> defaultCategories = [
      // 支出 (type: 0)
      {'name': '餐饮', 'type': 0, 'icon': 'restaurant'},
      {'name': '购物', 'type': 0, 'icon': 'shopping_cart'},
      {'name': '日用', 'type': 0, 'icon': 'inventory_2'},
      {'name': '交通', 'type': 0, 'icon': 'directions_bus'},
      {'name': '蔬菜', 'type': 0, 'icon': 'eco'},
      {'name': '水果', 'type': 0, 'icon': 'local_dining'},
      {'name': '零食', 'type': 0, 'icon': 'fastfood'},
      {'name': '服饰', 'type': 0, 'icon': 'checkroom'},
      {'name': '美容', 'type': 0, 'icon': 'face'},
      {'name': '居家', 'type': 0, 'icon': 'home'},
      {'name': '教育', 'type': 0, 'icon': 'school'},
      {'name': '医疗', 'type': 0, 'icon': 'medical_services'},
      {'name': '旅行', 'type': 0, 'icon': 'flight'},
      {'name': '娱乐', 'type': 0, 'icon': 'sports_esports'},
      {'name': '运动', 'type': 0, 'icon': 'fitness_center'},
      {'name': '社交', 'type': 0, 'icon': 'groups'},
      {'name': '数码', 'type': 0, 'icon': 'devices'},
      {'name': '汽车', 'type': 0, 'icon': 'directions_car'},
      {'name': '办公', 'type': 0, 'icon': 'business_center'},
      {'name': '维修', 'type': 0, 'icon': 'build'},
      {'name': '宠物', 'type': 0, 'icon': 'pets'},
      {'name': '水族', 'type': 0, 'icon': 'phishing'},
      {'name': '礼物', 'type': 0, 'icon': 'redeem'},
      {'name': '结婚', 'type': 0, 'icon': 'favorite'},
      {'name': '礼金', 'type': 0, 'icon': 'volunteer_activism'},
      {'name': '其它', 'type': 0, 'icon': 'more_horiz'},

      // 收入 (type: 1)
      {'name': '工资', 'type': 1, 'icon': 'payments'},
      {'name': '兼职', 'type': 1, 'icon': 'work'},
      {'name': '理财', 'type': 1, 'icon': 'trending_up'},
      {'name': '奖金', 'type': 1, 'icon': 'emoji_events'},
      {'name': '其它', 'type': 1, 'icon': 'more_horiz'},
    ];

    for (var cat in defaultCategories) {
      await db.insert('categories', cat);
    }
  }

  /// 数据库升级：从 v1 -> v2 新增 note_templates 表
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS note_templates(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL,
          note TEXT NOT NULL,
          UNIQUE(category, note)
        )
      ''');
    }
    if (oldVersion < 3) {
      // 为备注模板增加排序字段
      await db.execute('ALTER TABLE note_templates ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      // 扩充默认分类（针对已有用户，仅插入不存在的分类）
      final List<Map<String, dynamic>> newDefaults = [
        {'name': '日用', 'type': 0, 'icon': 'inventory_2'},
        {'name': '蔬菜', 'type': 0, 'icon': 'eco'},
        {'name': '水果', 'type': 0, 'icon': 'local_dining'},
        {'name': '零食', 'type': 0, 'icon': 'fastfood'},
        {'name': '服饰', 'type': 0, 'icon': 'checkroom'},
        {'name': '美容', 'type': 0, 'icon': 'face'},
        {'name': '教育', 'type': 0, 'icon': 'school'},
        {'name': '旅行', 'type': 0, 'icon': 'flight'},
        {'name': '运动', 'type': 0, 'icon': 'fitness_center'},
        {'name': '社交', 'type': 0, 'icon': 'groups'},
        {'name': '数码', 'type': 0, 'icon': 'devices'},
        {'name': '汽车', 'type': 0, 'icon': 'directions_car'},
        {'name': '办公', 'type': 0, 'icon': 'business_center'},
        {'name': '维修', 'type': 0, 'icon': 'build'},
        {'name': '宠物', 'type': 0, 'icon': 'pets'},
        {'name': '水族', 'type': 0, 'icon': 'phishing'},
        {'name': '礼物', 'type': 0, 'icon': 'redeem'},
        {'name': '结婚', 'type': 0, 'icon': 'favorite'},
        {'name': '奖金', 'type': 1, 'icon': 'emoji_events'},
        {'name': '其它', 'type': 1, 'icon': 'more_horiz'},
      ];

      for (var cat in newDefaults) {
        final List<Map<String, dynamic>> existing = await db.query(
          'categories',
          where: 'name = ? AND type = ?',
          whereArgs: [cat['name'], cat['type']],
        );
        if (existing.isEmpty) {
          await db.insert('categories', cat);
        }
      }
    }
  }

  // --- 分类 CRUD ---
  Future<int> insertCategory(Category category) async {
    final db = await database;
    final id = await db.insert('categories', category.toMap());
    categoryUpdateNotifier.value++; // 通知更新
    return id;
  }

  Future<List<Category>> getCategories(int type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
    );
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    final count = await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    categoryUpdateNotifier.value++; // 通知更新
    return count;
  }

  // --- 记账流水 CRUD ---
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<TransactionModel>> getTransactionsByMonth(String yearMonth) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date LIKE ?',
      whereArgs: ['$yearMonth%'],
      orderBy: 'date DESC, id DESC',
    );
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
  }

  // --- 备注模板 CRUD ---

  /// 保存一条备注模板，相同分类+备注组合自动去重
  Future<void> saveNoteTemplate(String category, String note) async {
    if (note.trim().isEmpty) return;
    final db = await database;
    
    // 检查是否已存在
    final existing = await db.query(
      'note_templates',
      where: 'category = ? AND note = ?',
      whereArgs: [category, note.trim()],
    );
    if (existing.isNotEmpty) return;

    // 获取当前分类下最大的排序号，新备注默认排到最后面
    final List<Map<String, dynamic>> res = await db.rawQuery(
      'SELECT MAX(sort_order) as maxOrder FROM note_templates WHERE category = ?',
      [category]
    );
    int nextOrder = (res.first['maxOrder'] as int? ?? -1) + 1;

    await db.insert(
      'note_templates',
      {
        'category': category, 
        'note': note.trim(),
        'sort_order': nextOrder,
      },
    );
  }

  /// 获取某分类下的所有备注模板（按排序号升序，相同序号按 ID 降序）
  Future<List<NoteTemplate>> getNoteTemplates(String category) async {
    final db = await database;
    final maps = await db.query(
      'note_templates',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'sort_order ASC, id DESC',
    );
    return maps.map((m) => NoteTemplate.fromMap(m)).toList();
  }

  /// 获取全部备注模板
  Future<List<NoteTemplate>> getAllNoteTemplates() async {
    final db = await database;
    final maps = await db.query(
      'note_templates',
      orderBy: 'category ASC, sort_order ASC, id DESC',
    );
    return maps.map((m) => NoteTemplate.fromMap(m)).toList();
  }

  /// 批量更新备注模板排序
  Future<void> updateNoteTemplatesOrder(List<NoteTemplate> templates) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < templates.length; i++) {
        await txn.update(
          'note_templates',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [templates[i].id],
        );
      }
    });
  }

  /// 删除单条备注模板
  Future<void> deleteNoteTemplate(int id) async {
    final db = await database;
    await db.delete('note_templates', where: 'id = ?', whereArgs: [id]);
  }
}
