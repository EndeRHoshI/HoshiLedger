import 'dart:io';
import 'package:csv/csv.dart';

void main() async {
  List<String> filesToMigrate = [
    'assets/鲨鱼记账明细1778744359422(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744400265(1)_utf8.csv',
  ];

  int importedCount = 0;

  for (String path in filesToMigrate) {
    try {
      final file = File(path);
      final csvString = await file.readAsString();
      final List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(csvString);
      print('Parsed $path, rows: ${rows.length}');

      if (rows.isEmpty) {
        print('$path is empty');
        continue;
      }

      bool hasHeader = rows[0].isNotEmpty && rows[0][0].toString().contains('日期');
      int startIndex = hasHeader ? 1 : 0;

      for (int i = startIndex; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 6) continue;

        String rawDate = row[0].toString().trim();
        if (rawDate.isEmpty) continue;
        String parsedDate = rawDate
            .replaceAll('年', '-')
            .replaceAll('月', '-')
            .replaceAll('日', '');
        
        String rawType = row[1].toString().trim();
        int type = rawType == '收入' ? 1 : 0;
        String category = row[2].toString().trim();
        double amountDouble = double.tryParse(row[4].toString().trim()) ?? 0.0;
        int amount = (amountDouble * 100).toInt();
        String note = row[5].toString().trim();

        // Check if everything parsed correctly
        if (i == 1) { // Print first row for debugging
          print('Parsed row 1 of $path: $parsedDate, type $type, cat $category, amt $amount, note $note');
        }
        importedCount++;
      }
    } catch (e) {
      print('Error parsing $path: $e');
    }
  }
  print('Total imported: $importedCount');
}
