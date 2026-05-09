import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class StatisticsScreen extends StatefulWidget {
  final int refreshKey;
  const StatisticsScreen({super.key, this.refreshKey = 0});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isMonthly = true; // true for Month, false for Year
  DateTime _selectedDate = DateTime.now();
  List<TransactionModel> _data = [];
  Map<String, int> _categoryTotals = {};
  int _totalExpense = 0;
  int _totalIncome = 0;
  Map<String, String> _categoryIconMap = {};

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void didUpdateWidget(StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 每次切换到本 tab 时 refreshKey 会递增，触发数据刷新
    if (oldWidget.refreshKey != widget.refreshKey) {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    final filter = _isMonthly
        ? DateFormat('yyyy-MM').format(_selectedDate)
        : DateFormat('yyyy').format(_selectedDate);

    final allData = await DBHelper().getTransactionsByMonth(filter);
    final allCats = await DBHelper().getAllCategories();

    Map<String, int> catTotals = {};
    int expense = 0;
    int income = 0;

    for (var t in allData) {
      if (t.type == 0) {
        expense += t.amount;
        catTotals[t.category] = (catTotals[t.category] ?? 0) + t.amount;
      } else {
        income += t.amount;
      }
    }

    setState(() {
      _data = allData;
      _categoryTotals = catTotals;
      _totalExpense = expense;
      _totalIncome = income;
      _categoryIconMap = {for (var c in allCats) c.name: c.icon};
    });
  }

  /// 月度模式：弹出年+月选择器
  Future<void> _pickMonthYear() async {
    int tempYear = _selectedDate.year;
    int? tempMonth;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setLocal(() => tempYear--),
              ),
              Text('$tempYear年'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setLocal(() => tempYear++),
              ),
            ],
          ),
          content: SizedBox(
            width: 280,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.6,
              ),
              itemCount: 12,
              itemBuilder: (_, i) {
                final month = i + 1;
                final isSelected = tempMonth == month;
                return GestureDetector(
                  onTap: () {
                    tempMonth = month;
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.withAlpha(76),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$month月',
                      style: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (tempMonth != null) {
      setState(() => _selectedDate = DateTime(tempYear, tempMonth!));
      _refreshData();
    }
  }

  /// 年度模式：弹出年份选择器
  Future<void> _pickYear() async {
    DateTime? picked;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择年份'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: YearPicker(
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            selectedDate: _selectedDate,
            onChanged: (date) {
              picked = date;
              Navigator.pop(ctx);
            },
          ),
        ),
      ),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked!);
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: const [],
      ),
      body: Column(
        children: [
          // Toggle and Date Selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('月度')),
                    ButtonSegment(value: false, label: Text('年度')),
                  ],
                  selected: {_isMonthly},
                  onSelectionChanged: (val) {
                    setState(() => _isMonthly = val.first);
                    _refreshData();
                  },
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    if (_isMonthly) {
                      _pickMonthYear();
                    } else {
                      _pickYear();
                    }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(_isMonthly
                      ? DateFormat('yyyy年MM月').format(_selectedDate)
                      : DateFormat('yyyy年').format(_selectedDate)),
                ),
              ],
            ),
          ),

          Expanded(
            child: _data.isEmpty
                ? const Center(child: Text('暂无数据'))
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildOverviewCard(),
                        if (_totalExpense > 0) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('支出构成', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          _buildPieChart(),
                          _buildCategoryList(),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('总支出', _totalExpense, Colors.red),
            _buildStatItem('总收入', _totalIncome, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '￥${(amount / 100.0).toStringAsFixed(2)}',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    final sortedCats = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<PieChartSectionData> sections = [];
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];

    for (int i = 0; i < sortedCats.length; i++) {
      sections.add(PieChartSectionData(
        value: sortedCats[i].value.toDouble(),
        title: '',
        radius: 50,
        color: colors[i % colors.length],
      ));
    }

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    final sortedCats = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: sortedCats.asMap().entries.map((entry) {
          final idx = entry.key;
          final cat = entry.value.key;
          final amount = entry.value.value;
          final percentage = (amount / _totalExpense * 100).toStringAsFixed(1);
          final color = colors[idx % colors.length];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Category.getIconData(_categoryIconMap[cat] ?? 'category'),
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 12),
                Text(cat, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text('$percentage%', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Spacer(),
                Text('￥${(amount / 100.0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
