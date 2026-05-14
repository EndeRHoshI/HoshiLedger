import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';

class SharkMigration {
  static const List<String> filesToMigrate = [
    'assets/鲨鱼记账明细1778744359422(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744400265(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744422588(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744436797(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744448764(1)_utf8.csv',
  ];

  static Future<int> runMigration() async {
    final db = DBHelper();
    int importedCount = 0;

    for (String path in filesToMigrate) {
      try {
        final csvString = await rootBundle.loadString(path);
        final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

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

          // Amount
          double amountDouble = double.tryParse(row[4].toString().trim()) ?? 0.0;
          int amount = (amountDouble * 100).toInt();

          // Note
          String note = row[5].toString().trim();

          final t = TransactionModel(
            amount: amount,
            type: type,
            category: category,
            date: parsedDate,
            note: note,
          );

          await db.insertTransaction(t);
          importedCount++;
        }
      } catch (e) {
        print('Error parsing $path: $e');
      }
    }

    return importedCount;
  }
}
