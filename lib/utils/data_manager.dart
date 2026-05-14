import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';

class DataManager {
  static Future<void> exportToCSV() async {
    final db = DBHelper();
    final transactions = await db.getTransactionsByMonth('');

    List<List<dynamic>> rows = [];
    rows.add(['ID', '金额', '类型', '分类', '日期', '备注']);

    for (var t in transactions) {
      rows.add([
        t.id,
        (t.amount / 100.0).toStringAsFixed(2),
        t.type == 0 ? '支出' : '收入',
        t.category,
        t.date,
        t.note,
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/HoshiLedger_Export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'HoshiLedger 账单导出 (CSV)');
  }

  static Future<void> exportToJSON() async {
    final db = DBHelper();
    final transactions = await db.getTransactionsByMonth('');

    List<Map<String, dynamic>> jsonData = transactions.map((t) => t.toMap()).toList();
    String jsonString = jsonEncode(jsonData);

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/HoshiLedger_Export_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(path);
    await file.writeAsString(jsonString);

    await Share.shareXFiles([XFile(path)], text: 'HoshiLedger 账单导出 (JSON)');
  }

  static Future<bool> importData(File file) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final content = await file.readAsString();
      final db = DBHelper();
      List<TransactionModel> newTransactions = [];

      if (ext == 'json') {
        final List<dynamic> decoded = jsonDecode(content);
        for (var item in decoded) {
          // 移除 ID 让 SQLite 重新分配，避免主键冲突
          item.remove('id');
          newTransactions.add(TransactionModel.fromMap(item as Map<String, dynamic>));
        }
      } else if (ext == 'csv') {
        final List<List<dynamic>> rows = const CsvToListConverter().convert(content);
        if (rows.isEmpty) return false;
        
        // 判断首行是否为表头
        bool hasHeader = rows[0].isNotEmpty && rows[0][0].toString().toLowerCase() == 'id';
        int startIndex = hasHeader ? 1 : 0;

        for (int i = startIndex; i < rows.length; i++) {
          final row = rows[i];
          if (row.length < 6) continue; // 跳过残缺的行
          
          double amountDouble = double.tryParse(row[1].toString()) ?? 0.0;
          int amount = (amountDouble * 100).toInt();
          int type = row[2].toString() == '支出' ? 0 : 1;
          String category = row[3].toString();
          String date = row[4].toString();
          String note = row[5].toString();

          newTransactions.add(TransactionModel(
            amount: amount,
            type: type,
            category: category,
            date: date,
            note: note,
          ));
        }
      } else {
        return false; // 不支持的格式
      }

      if (newTransactions.isNotEmpty) {
        await db.clearAllData(); // 覆盖恢复前清空旧数据
        for (var t in newTransactions) {
          await db.insertTransaction(t);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Import failed: $e');
      return false;
    }
  }
}
