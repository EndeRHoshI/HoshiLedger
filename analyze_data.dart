import 'dart:io';
import 'package:csv/csv.dart';

void main() async {
  List<String> files = [
    'assets/鲨鱼记账明细1778744359422(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744400265(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744422588(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744436797(1)_utf8.csv',
    'assets/鲨鱼记账明细1778744448764(1)_utf8.csv',
  ];

  // 用于全局去重检测: key = "date|type|category|amount|note"
  Map<String, List<String>> globalKeyToFiles = {};

  for (String path in files) {
    final file = File(path);
    final csvString = await file.readAsString();
    final List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(csvString);

    bool hasHeader = rows[0].isNotEmpty && rows[0][0].toString().contains('日期');
    int startIndex = hasHeader ? 1 : 0;

    String? firstDate, lastDate;
    Map<String, int> dateCounts = {};

    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 6) continue;
      String rawDate = row[0].toString().trim();
      if (rawDate.isEmpty) continue;
      String parsedDate = rawDate.replaceAll('年', '-').replaceAll('月', '-').replaceAll('日', '');
      firstDate ??= parsedDate;
      lastDate = parsedDate;
      dateCounts[parsedDate] = (dateCounts[parsedDate] ?? 0) + 1;

      String rawType = row[1].toString().trim();
      String category = row[2].toString().trim();
      String amount = row[4].toString().trim();
      String note = row[5].toString().trim();
      String key = '$parsedDate|$rawType|$category|$amount|$note';
      globalKeyToFiles.putIfAbsent(key, () => []).add(path.split('/').last);
    }

    print('=== ${path.split('/').last} ===');
    print('  日期范围: $lastDate → $firstDate');  // rows are newest first
    print('  总行数: ${dateCounts.values.fold(0, (a, b) => a + b)}');
  }

  // 找出出现在多个文件里的重复记录
  print('\n=== 跨文件重复记录 ===');
  int dupCount = 0;
  globalKeyToFiles.forEach((key, fileList) {
    if (fileList.length > 1) {
      print('重复: $key');
      print('  出现在: $fileList');
      dupCount++;
    }
  });
  print('共发现 $dupCount 条跨文件重复记录');
}
