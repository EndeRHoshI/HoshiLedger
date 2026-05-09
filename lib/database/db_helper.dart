import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Categories table
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        icon TEXT NOT NULL
      )
    ''');

    // Transactions table
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

    // Insert default categories
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

  // --- Category CRUD ---
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
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
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // --- Transaction CRUD ---
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<TransactionModel>> getTransactionsByMonth(String yearMonth) async {
    final db = await database;
    // yearMonth should be "YYYY-MM"
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: "date LIKE ?",
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
}
