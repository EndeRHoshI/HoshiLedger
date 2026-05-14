import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import 'category_transactions_screen.dart';

class StatisticsScreen extends StatefulWidget {
  final int refreshKey;
  const StatisticsScreen({super.key, this.refreshKey = 0});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  bool _isMonthly = true;
  DateTime _selectedDate = DateTime.now();
  List<TransactionModel> _data = [];
  Map<String, int> _expenseCatTotals = {};
  Map<String, int> _incomeCatTotals = {};
  int _totalExpense = 0;
  int _totalIncome = 0;
  Map<String, String> _categoryIconMap = {};

  late TabController _tabController;

  static const List<Color> _chartColors = [
    Color(0xFF6C63FF), Color(0xFFFF6584), Color(0xFF43C59E),
    Color(0xFFFFBE0B), Color(0xFF4ECDC4), Color(0xFFFF6B6B),
    Color(0xFF45B7D1), Color(0xFF96CEB4), Color(0xFFFECEA8), Color(0xFFDDA0DD),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
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

    Map<String, int> expTotals = {};
    Map<String, int> incTotals = {};
    int expense = 0;
    int income = 0;

    for (var t in allData) {
      if (t.type == 0) {
        expense += t.amount;
        expTotals[t.category] = (expTotals[t.category] ?? 0) + t.amount;
      } else {
        income += t.amount;
        incTotals[t.category] = (incTotals[t.category] ?? 0) + t.amount;
      }
    }

    setState(() {
      _data = allData;
      _expenseCatTotals = expTotals;
      _incomeCatTotals = incTotals;
      _totalExpense = expense;
      _totalIncome = income;
      _categoryIconMap = {for (var c in allCats) c.name: c.icon};
    });
  }

  String get _currentPeriodLabel => _isMonthly
      ? DateFormat('yyyy年MM月').format(_selectedDate)
      : DateFormat('yyyy年').format(_selectedDate);

  String get _currentPeriodFilter => _isMonthly
      ? DateFormat('yyyy-MM').format(_selectedDate)
      : DateFormat('yyyy').format(_selectedDate);

  void _navigateToCategoryDetail(String category, int type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryTransactionsScreen(
          categoryName: category,
          periodLabel: _currentPeriodLabel,
          periodFilter: _currentPeriodFilter,
          transactionType: type,
        ),
      ),
    );
  }

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
    final hasExpense = _totalExpense > 0;
    final hasIncome = _totalIncome > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: const [],
      ),
      body: Column(
        children: [
          // 月度/年度切换 + 日期选择
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
                    if (_isMonthly) { _pickMonthYear(); } else { _pickYear(); }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(_currentPeriodLabel),
                ),
              ],
            ),
          ),

          // 概览卡片
          _buildOverviewCard(),

          const SizedBox(height: 8),

          // 支出/收入 Tab
          if (_data.isNotEmpty && (hasExpense || hasIncome)) ...[
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('支出构成',
                          style: TextStyle(
                              color: hasExpense ? null : Colors.grey)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('收入构成',
                          style: TextStyle(
                              color: hasIncome ? null : Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 支出页
                  hasExpense
                      ? SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              _buildPieChart(_expenseCatTotals, _totalExpense),
                              _buildCategoryList(_expenseCatTotals, _totalExpense, 0),
                              const SizedBox(height: 32),
                            ],
                          ),
                        )
                      : const Center(child: Text('本期无支出数据')),
                  // 收入页
                  hasIncome
                      ? SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              _buildPieChart(_incomeCatTotals, _totalIncome),
                              _buildCategoryList(_incomeCatTotals, _totalIncome, 1),
                              const SizedBox(height: 32),
                            ],
                          ),
                        )
                      : const Center(child: Text('本期无收入数据')),
                ],
              ),
            ),
          ],

          if (_data.isEmpty)
            const Expanded(child: Center(child: Text('暂无数据'))),
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
            Container(width: 1, height: 40, color: Colors.grey.withAlpha(60)),
            _buildStatItem('总收入', _totalIncome, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '￥${(amount.abs() / 100.0).toStringAsFixed(2)}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildPieChart(Map<String, int> catTotals, int total) {
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<PieChartSectionData> sections = [];
    for (int i = 0; i < sortedCats.length; i++) {
      sections.add(PieChartSectionData(
        value: sortedCats[i].value.toDouble(),
        title: '',
        radius: 50,
        color: _chartColors[i % _chartColors.length],
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

  Widget _buildCategoryList(Map<String, int> catTotals, int total, int type) {
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final amountColor = type == 0 ? Colors.red : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: sortedCats.asMap().entries.map((entry) {
          final idx = entry.key;
          final cat = entry.value.key;
          final amount = entry.value.value;
          final percentage = (amount / total * 100).toStringAsFixed(1);
          final color = _chartColors[idx % _chartColors.length];

          return InkWell(
            onTap: () => _navigateToCategoryDetail(cat, type),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Category.getIconData(_categoryIconMap[cat] ?? 'category'),
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(cat, style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 6),
                            Text('$percentage%',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: amount / total,
                            color: color,
                            backgroundColor: color.withAlpha(40),
                            minHeight: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '￥${(amount / 100.0).toStringAsFixed(2)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: amountColor),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
