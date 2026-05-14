import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import 'record_screen.dart';

class HistoryScreen extends StatefulWidget {
  final int refreshKey;
  const HistoryScreen({super.key, this.refreshKey = 0});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TransactionModel> _transactions = [];
  DateTime _displayMonth = DateTime.now();
  Map<String, String> _categoryIconMap = {}; // 分类名称 -> 图标名称

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _refreshData();
    }
  }

  void _showRecordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RecordScreen(onSaved: _refreshData),
    );
  }

  void _showEditSheet(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RecordScreen(
        transaction: transaction,
        onSaved: _refreshData,
      ),
    );
  }

  Future<void> _refreshData() async {
    final monthStr = DateFormat('yyyy-MM').format(_displayMonth);
    final data = await DBHelper().getTransactionsByMonth(monthStr);
    final allCats = await DBHelper().getAllCategories();

    setState(() {
      _transactions = data;
      _categoryIconMap = {for (var c in allCats) c.name: c.icon};
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + delta);
    });
    _refreshData();
  }

  Future<void> _pickMonthYear() async {
    int tempYear = _displayMonth.year;
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
                final isSelected = _displayMonth.year == tempYear && _displayMonth.month == month;
                return GestureDetector(
                  onTap: () {
                    tempMonth = month;
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withAlpha(76),
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
      setState(() {
        _displayMonth = DateTime(tempYear, tempMonth!);
      });
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalExpense = 0;
    int totalIncome = 0;
    for (var t in _transactions) {
      if (t.type == 0) totalExpense += t.amount;
      else totalIncome += t.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('账单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showRecordSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // 月份切换和概览
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                    InkWell(
                      onTap: _pickMonthYear,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(DateFormat('yyyy年MM月').format(_displayMonth), 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('本月收入', totalIncome, Colors.green),
                    _buildSummaryItem('本月支出', totalExpense, Colors.red),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildGroupedList()),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int amountCents, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          '￥${(amountCents / 100.0).toStringAsFixed(2)}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildGroupedList() {
    Map<String, List<TransactionModel>> grouped = {};
    for (var t in _transactions) {
      grouped.putIfAbsent(t.date, () => []).add(t);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    if (_transactions.isEmpty) {
      return const Center(child: Text('本月暂无记录', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayTransactions = grouped[date]!;

        int dailyExpense = 0;
        int dailyIncome = 0;
        for (var t in dayTransactions) {
          if (t.type == 0) dailyExpense += t.amount;
          else dailyIncome += t.amount;
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(date, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  Text(
                    [
                      if (dailyIncome > 0) '收: ${(dailyIncome / 100).toStringAsFixed(2)}',
                      if (dailyExpense > 0) '支: ${(dailyExpense / 100).toStringAsFixed(2)}',
                    ].join('  '),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ...dayTransactions.map((t) => ListTile(
                  onTap: () => _showEditSheet(t),
                  leading: CircleAvatar(
                    backgroundColor: t.type == 0 ? Colors.red.withAlpha(25) : Colors.green.withAlpha(25),
                    child: Icon(
                      _getIconForCategory(t),
                      color: t.type == 0 ? Colors.red : Colors.green,
                      size: 20,
                    ),
                  ),
                  title: Text(t.note.isNotEmpty ? t.note : t.category),
                  subtitle: t.note.isNotEmpty
                      ? Text(t.category, style: const TextStyle(fontSize: 12))
                      : null,
                  trailing: Text(
                    '${t.type == 0 ? "-" : "+"}${(t.amount / 100.0).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: t.type == 0 ? Colors.red : Colors.green,
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }

  IconData _getIconForCategory(TransactionModel t) {
    final iconName = _categoryIconMap[t.category] ?? 'category';
    return Category.getIconData(iconName);
  }
}
