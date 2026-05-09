import 'package:flutter/foundation.dart';
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
      version: 2, // 升级版本，新增备注模板表
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

    // 备注模板表（按分类存储历史备注，自动去重）
    await db.execute('''
      CREATE TABLE note_templates(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        note TEXT NOT NULL,
        UNIQUE(category, note)
      )
    ''');

    // 预置默认分类
    final List<Map<String, dynamic>> defaultCategories = [
      {'name': '餐饮', 'type': 0, 'icon': 'restaurant'},
      {'name': '交通', 'type': 0, 'icon': 'directions_bus'},
      {'name': '购物', 'type': 0, 'icon': 'shopping_cart'},
      {'name': '娱乐', 'type': 0, 'icon': 'movie'},
      {'name': '医疗', 'type': 0, 'icon': 'medical_services'},
      {'name': '居家', 'type': 0, 'icon': 'home'},
      {'name': '工资', 'type': 1, 'icon': 'payments'},
      {'name': '理财', 'type': 1, 'icon': 'trending_up'},
      {'name': '兼职', 'type': 1, 'icon': 'work'},
      {'name': '礼金', 'type': 1, 'icon': 'redeem'},
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
    await db.insert(
      'note_templates',
      {'category': category, 'note': note.trim()},
      conflictAlgorithm: ConflictAlgorithm.ignore, // 重复则忽略
    );
  }

  /// 获取某分类下的所有备注模板（最新在前）
  Future<List<NoteTemplate>> getNoteTemplates(String category) async {
    final db = await database;
    final maps = await db.query(
      'note_templates',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'id DESC',
    );
    return maps.map((m) => NoteTemplate.fromMap(m)).toList();
  }

  /// 获取全部备注模板（按分类排序，用于管理页）
  Future<List<NoteTemplate>> getAllNoteTemplates() async {
    final db = await database;
    final maps = await db.query(
      'note_templates',
      orderBy: 'category ASC, id DESC',
    );
    return maps.map((m) => NoteTemplate.fromMap(m)).toList();
  }

  /// 删除单条备注模板
  Future<void> deleteNoteTemplate(int id) async {
    final db = await database;
    await db.delete('note_templates', where: 'id = ?', whereArgs: [id]);
  }
}
