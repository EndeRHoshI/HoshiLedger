import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class SharkMigration {
  static const List<String> filesToMigrate = [
    'assets/鲨鱼记账明细1778744359422(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744400265(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744422588(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744436797(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744448764(1)_utf8.csv',
  ];

  static String _getIconForCategory(String categoryName) {
    switch (categoryName) {
      case '办公': return 'business_center';
      case '住房': return 'home';
      case '日用': return 'shopping_cart';
      case '娱乐': return 'sports_esports';
      case '汽车': return 'directions_car';
      case '工资': return 'attach_money';
      case '亲友': return 'people';
      case '餐饮': return 'restaurant';
      case '结婚': return 'favorite';
      case '其它': return 'more_horiz';
      case '通讯': return 'smartphone';
      case '交通': return 'directions_bus';
      case '美容': return 'face';
      case '奖金': return 'emoji_events';
      case '礼物': return 'redeem';
      case '长辈': return 'elderly';
      case '居家': return 'chair';
      case '医疗': return 'medical_services';
      case '服饰': return 'checkroom';
      case '水族': return 'phishing';
      case '数码': return 'devices';
      case '旅行': return 'flight';
      case '蔬菜': return 'eco';
      case '水果': return 'local_dining';
      case '罚款': return 'gavel';
      case '书籍': return 'menu_book';
      case '礼金': return 'volunteer_activism';
      case '学习': return 'school';
      case '零食': return 'fastfood';
      case '购物': return 'local_mall';
      case '理财': return 'trending_up';
      case '社交': return 'groups';
      case '维修': return 'build';
      case '宠物': return 'pets';
      case '兼职': return 'work';
      case '运动': return 'fitness_center';
      default: return 'category';
    }
  }

  static Future<int> runMigration() async {
    final db = DBHelper();
    int importedCount = 0;

    final existingCategories = await db.getAllCategories();
    final Set<String> existingCategoryKeys = existingCategories.map((c) => '${c.name}_${c.type}').toSet();

    // 跨文件去重 key: 日期|收支类型|类别|原始金额|备注
    // 仅在不同文件之间去重，同一文件内的重复视为真实数据保留
    final Set<String> crossFileSeenKeys = {};

    for (String path in filesToMigrate) {
      // 每个文件内的 key 集合，用于判断当前记录是否来自本文件
      final Set<String> thisFileKeys = {};
      try {
        final csvString = await rootBundle.loadString(path);
        final List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(csvString);

        if (rows.isEmpty) continue;

        // Skip header
        bool hasHeader = rows[0].isNotEmpty && rows[0][0].toString().contains('日期');
        int startIndex = hasHeader ? 1 : 0;

        for (int i = startIndex; i < rows.length; i++) {
          final row = rows[i];
          if (row.length < 6) continue;

          // Date format: "2026年05月13日" -> "2026-05-13"
          String rawDate = row[0].toString().trim();
          if (rawDate.isEmpty) continue;
          String parsedDate = rawDate
              .replaceAll('年', '-')
              .replaceAll('月', '-')
              .replaceAll('日', '');
          
          // Ensure double digit months/days if necessary, but Shark Ledger usually provides "05"
          // "2026-05-13" is ready for DB

          // Type: "支出" or "收入"
          String rawType = row[1].toString().trim();
          int type = rawType == '收入' ? 1 : 0;

          // Category
          String category = row[2].toString().trim();
          
          if (!existingCategoryKeys.contains('${category}_${type}')) {
            String smartIcon = _getIconForCategory(category);
            await db.insertCategory(Category(name: category, type: type, icon: smartIcon));
            existingCategoryKeys.add('${category}_${type}');
          }

          // Amount
          double amountDouble = double.tryParse(row[4].toString().trim()) ?? 0.0;
          int amount = (amountDouble * 100).round();

          // Note
          String note = row[5].toString().trim();

          // 去重检查：日期|收支类型|类别|原始金额|备注 五元素联合唯一键
          String dedupKey = '$parsedDate|$rawType|$category|${row[4].toString().trim()}|$note';
          // 只跳过来自其他文件的重复（跨文件边界日期），同文件内的重复保留
          if (crossFileSeenKeys.contains(dedupKey) && !thisFileKeys.contains(dedupKey)) continue;
          thisFileKeys.add(dedupKey);
          crossFileSeenKeys.add(dedupKey);

          final t = TransactionModel(
            amount: amount,
            type: type,
            category: category,
            date: parsedDate,
            note: note,
          );

          await db.insertTransaction(t);
          // 同步写入备注模板，方便后续新建同类账单时智能提示
          if (note.isNotEmpty) {
            await db.saveNoteTemplate(category, note);
          }
          importedCount++;
        }
      } catch (e) {
        print('Error parsing $path: $e');
      }
    }

    return importedCount;
  }
}
