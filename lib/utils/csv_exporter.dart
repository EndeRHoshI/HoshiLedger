import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';

class CSVExporter {
  static Future<void> exportAllTransactions() async {
    // For simplicity, we fetch all transactions. 
    // In a real app, you might want to filter by year.
    final db = DBHelper();
    // We don't have a direct 'getAll' in DBHelper yet, so let's use a LIKE '%' for all
    final transactions = await db.getTransactionsByMonth('');

    List<List<dynamic>> rows = [];

    // Header
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

    await Share.shareXFiles([XFile(path)], text: 'HoshiLedger 账单导出');
  }
}
