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
        title: const Text('账单流水'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                    Text(DateFormat('yyyy年MM月').format(_displayMonth), 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
                  ],
                ),
                Row(
                  children: [
                    _buildSummaryItem('收入', totalIncome, Colors.green),
                    const SizedBox(width: 16),
                    _buildSummaryItem('支出', totalExpense, Colors.red),
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
                    '收: ${(dailyIncome / 100).toStringAsFixed(2)}  支: ${(dailyExpense / 100).toStringAsFixed(2)}',
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
                  title: Text(t.category),
                  subtitle: t.note.isNotEmpty ? Text(t.note, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
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
