import 'dart:io';
import 'package:csv/csv.dart';

void main() async {
  List<String> filesToMigrate = [
    'assets/鲨鱼记账明细1778744359422(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744400265(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744422588(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744436797(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744448764(1)_utf8.csv',
  ];

  Set<String> uniqueCategories = {};
  Map<String, int> typeCounts = {};

  int dataRowCount = 0;

  for (String path in filesToMigrate) {
    try {
      final file = File(path);
      final csvString = await file.readAsString();
      final List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(csvString);

      bool hasHeader = rows[0].isNotEmpty && rows[0][0].toString().contains('日期');
      int startIndex = hasHeader ? 1 : 0;

      for (int i = startIndex; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 6) continue;

        String rawDate = row[0].toString().trim();
        if (rawDate.isEmpty) continue;
        
        String rawType = row[1].toString().trim();
        typeCounts[rawType] = (typeCounts[rawType] ?? 0) + 1;
        
        String category = row[2].toString().trim();
        uniqueCategories.add(category);
        
        double amountDouble = double.tryParse(row[4].toString().trim()) ?? 0.0;
        String note = row[5].toString().trim();

        if (amountDouble == 0) {
          print('Found 0 amount row: $row');
        }
        if (category.contains('平账') || category.contains('退款') || note.contains('平账') || note.contains('退款')) {
          print('Found potential excluded row: $row');
        }

        dataRowCount++;
      }
    } catch (e) {
      print('Error parsing $path: $e');
    }
  }

  print('Total data rows: $dataRowCount');
  print('Transaction Types: $typeCounts');
  print('Unique Categories: ${uniqueCategories.toList()}');
}
