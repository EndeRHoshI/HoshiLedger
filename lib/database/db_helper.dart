import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/note_template.dart';
import '../models/transaction_template.dart';

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
      version: 8, // 自定义组合记账模板
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
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
        icon TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
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

    await _createTemplateTables(db);

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
      {'name': '居家', 'type': 0, 'icon': 'chair'},
      {'name': '住房', 'type': 0, 'icon': 'apartment'},
      {'name': '教育', 'type': 0, 'icon': 'school'},
      {'name': '学习', 'type': 0, 'icon': 'menu_book'},
      {'name': '医疗', 'type': 0, 'icon': 'medical_services'},
      {'name': '旅行', 'type': 0, 'icon': 'flight'},
      {'name': '娱乐', 'type': 0, 'icon': 'sports_esports'},
      {'name': '运动', 'type': 0, 'icon': 'fitness_center'},
      {'name': '社交', 'type': 0, 'icon': 'groups'},
      {'name': '通讯', 'type': 0, 'icon': 'smartphone'},
      {'name': '数码', 'type': 0, 'icon': 'devices'},
      {'name': '汽车', 'type': 0, 'icon': 'directions_car'},
      {'name': '办公', 'type': 0, 'icon': 'business_center'},
      {'name': '维修', 'type': 0, 'icon': 'build'},
      {'name': '宠物', 'type': 0, 'icon': 'pets'},
      {'name': '水族', 'type': 0, 'icon': 'phishing'},
      {'name': '礼物', 'type': 0, 'icon': 'redeem'},
      {'name': '亲友', 'type': 0, 'icon': 'people'},
      {'name': '长辈', 'type': 0, 'icon': 'elderly'},
      {'name': '结婚', 'type': 0, 'icon': 'favorite'},
      {'name': '礼金', 'type': 0, 'icon': 'volunteer_activism'},
      {'name': '罚款', 'type': 0, 'icon': 'gavel'},
      {'name': '书籍', 'type': 0, 'icon': 'menu_book'},
      {'name': '其它', 'type': 0, 'icon': 'more_horiz'},

      // 收入 (type: 1)
      {'name': '工资', 'type': 1, 'icon': 'payments'},
      {'name': '兼职', 'type': 1, 'icon': 'work'},
      {'name': '理财', 'type': 1, 'icon': 'trending_up'},
      {'name': '奖金', 'type': 1, 'icon': 'emoji_events'},
      {'name': '礼金', 'type': 1, 'icon': 'volunteer_activism'},
      {'name': '其它', 'type': 1, 'icon': 'more_horiz'},
    ];

    for (int i = 0; i < defaultCategories.length; i++) {
      await db.insert('categories', {
        ...defaultCategories[i],
        'sort_order': i,
      });
    }
  }

  /// 按版本逐步升级已有数据库。
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
    if (oldVersion < 5) {
      // 进一步补全 CSV 中发现的分类
      final List<Map<String, dynamic>> moreDefaults = [
        {'name': '住房', 'type': 0, 'icon': 'chair'},
        {'name': '学习', 'type': 0, 'icon': 'menu_book'},
        {'name': '通讯', 'type': 0, 'icon': 'smartphone'},
        {'name': '亲友', 'type': 0, 'icon': 'people'},
        {'name': '长辈', 'type': 0, 'icon': 'elderly'},
        {'name': '罚款', 'type': 0, 'icon': 'gavel'},
        {'name': '书籍', 'type': 0, 'icon': 'menu_book'},
        {'name': '礼金', 'type': 1, 'icon': 'volunteer_activism'},
      ];

      for (var cat in moreDefaults) {
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
    if (oldVersion < 6) {
      // 修正旧默认图标，保留用户选择的其他图标。
      await db.update(
        'categories',
        {'icon': 'chair'},
        where: 'name = ? AND type = ? AND icon = ?',
        whereArgs: ['居家', 0, 'home'],
      );
      await db.update(
        'categories',
        {'icon': 'apartment'},
        where: 'name = ? AND type = ? AND icon IN (?, ?)',
        whereArgs: ['住房', 0, 'home', 'chair'],
      );
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE categories ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
      // 以原 ID 顺序初始化，避免升级后打乱已有分类。
      await db.execute('UPDATE categories SET sort_order = id');
    }
    if (oldVersion < 8) {
      await _createTemplateTables(db);
    }
  }

  Future<void> _createTemplateTables(Database db) async {
    await db.execute('''
      CREATE TABLE transaction_templates(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE template_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        amount INTEGER NOT NULL CHECK(amount > 0),
        type INTEGER NOT NULL CHECK(type IN (0, 1)),
        category TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL,
        FOREIGN KEY(template_id) REFERENCES transaction_templates(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<List<TransactionTemplate>> getTransactionTemplates() async {
    final db = await database;
    return db.transaction((txn) async {
      final templates = await txn.query(
        'transaction_templates',
        orderBy: 'sort_order ASC, id ASC',
      );
      final rows = await txn.query(
        'template_entries',
        orderBy: 'sort_order ASC, id ASC',
      );
      final entries = <int, List<TemplateEntry>>{};
      for (final row in rows) {
        entries.putIfAbsent(row['template_id'] as int, () => [])
            .add(TemplateEntry.fromMap(row));
      }
      return templates.map((row) => TransactionTemplate(
        id: row['id'] as int,
        name: row['name'] as String,
        entries: entries[row['id']] ?? [],
      )).toList();
    });
  }

  Future<int> saveTransactionTemplate({
    int? id,
    required String name,
    required List<TemplateEntry> entries,
  }) async {
    if (name.trim().isEmpty || entries.isEmpty || entries.any((entry) =>
        entry.amount <= 0 || ![0, 1].contains(entry.type) || entry.category.isEmpty)) {
      throw ArgumentError('模板需要名称和有效条目');
    }
    final db = await database;
    return db.transaction((txn) async {
      final int templateId;
      if (id == null) {
        final result = await txn.rawQuery(
          'SELECT MAX(sort_order) AS max_order FROM transaction_templates',
        );
        templateId = await txn.insert('transaction_templates', {
          'name': name.trim(),
          'sort_order': (result.first['max_order'] as int? ?? -1) + 1,
        });
      } else {
        final count = await txn.update(
          'transaction_templates', {'name': name.trim()},
          where: 'id = ?', whereArgs: [id],
        );
        if (count != 1) throw StateError('模板已不存在');
        templateId = id;
        await txn.delete('template_entries',
          where: 'template_id = ?', whereArgs: [id]);
      }
      final batch = txn.batch();
      for (int i = 0; i < entries.length; i++) {
        batch.insert('template_entries', {
          ...entries[i].toMap(),
          'template_id': templateId,
          'sort_order': i,
        });
      }
      await batch.commit(noResult: true);
      return templateId;
    });
  }

  Future<void> deleteTransactionTemplate(int id) async {
    final db = await database;
    await db.delete('transaction_templates', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTransactionTemplatesOrder(List<TransactionTemplate> templates) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (int i = 0; i < templates.length; i++) {
        batch.update('transaction_templates', {'sort_order': i},
          where: 'id = ?', whereArgs: [templates[i].id]);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> applyTransactionTemplate(int id, String date) async {
    final db = await database;
    return db.transaction((txn) async {
      final templates = await txn.query('transaction_templates',
        where: 'id = ?', whereArgs: [id]);
      if (templates.isEmpty) throw StateError('模板已不存在');
      final rows = await txn.query('template_entries',
        where: 'template_id = ?', whereArgs: [id], orderBy: 'sort_order ASC, id ASC');
      if (rows.isEmpty) throw StateError('模板没有条目');
      // 整批校验和写入共用一个事务，避免只记入部分条目。
      for (final row in rows.reversed) {
        final entry = TemplateEntry.fromMap(row);
        final categories = await txn.query('categories',
          where: 'name = ? AND type = ?', whereArgs: [entry.category, entry.type]);
        if (categories.isEmpty) {
          throw StateError('分类「${entry.category}」已删除或改名，请先编辑模板');
        }
        await txn.insert('transactions', {...entry.toMap(), 'date': date});
        await _saveNoteTemplate(txn, entry.category, entry.note);
      }
      return rows.length;
    });
  }

  // --- 分类 CRUD ---
  Future<int> insertCategory(Category category) async {
    final db = await database;
    final id = await db.transaction((txn) async {
      final result = await txn.rawQuery(
        'SELECT MAX(sort_order) AS max_order FROM categories WHERE type = ?',
        [category.type],
      );
      final nextOrder = (result.first['max_order'] as int? ?? -1) + 1;
      return txn.insert('categories', {
        ...category.toMap(),
        'sort_order': nextOrder,
      });
    });
    categoryUpdateNotifier.value++; // 通知更新
    return id;
  }

  Future<List<Category>> getCategories(int type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'sort_order ASC, id ASC',
    );
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<void> updateCategoriesOrder(int type, List<Category> categories) async {
    if (categories.any(
      (category) => category.type != type || category.id == null,
    )) {
      throw ArgumentError('分类必须已保存且属于同一收支类型');
    }
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < categories.length; i++) {
        await txn.update(
          'categories',
          {'sort_order': i},
          where: 'id = ? AND type = ?',
          whereArgs: [categories[i].id, type],
        );
      }
    });
    categoryUpdateNotifier.value++;
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
    final db = await database;
    await _saveNoteTemplate(db, category, note);
  }

  Future<void> _saveNoteTemplate(DatabaseExecutor db, String category, String note) async {
    if (note.trim().isEmpty) return;
    
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
