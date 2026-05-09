import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';

class HistoryScreen extends StatefulWidget {
  final int refreshKey;
  const HistoryScreen({super.key, this.refreshKey = 0});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _displayMonth = DateTime.now();
  List<TransactionModel> _transactions = [];
  int _totalExpense = 0;
  int _totalIncome = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 每次切换到本 tab 时 refreshKey 会递增，触发数据刷新
    if (oldWidget.refreshKey != widget.refreshKey) {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    final monthStr = DateFormat('yyyy-MM').format(_displayMonth);
    final data = await DBHelper().getTransactionsByMonth(monthStr);
    
    int expense = 0;
    int income = 0;
    for (var t in data) {
      if (t.type == 0) expense += t.amount;
      else income += t.amount;
    }

    setState(() {
      _transactions = data;
      _totalExpense = expense;
      _totalIncome = income;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + delta);
    });
    _refreshData();
  }


  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除这条记录吗？该操作无法撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单流水'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Month Selector and Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(76),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                    Text(
                      DateFormat('yyyy年MM月').format(_displayMonth),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('总支出', _totalExpense, Colors.red),
                    _buildSummaryItem('总收入', _totalIncome, Colors.green),
                    _buildSummaryItem('结余', _totalIncome - _totalExpense, Colors.blueGrey),
                  ],
                ),
              ],
            ),
          ),

          // Transaction List
          Expanded(
            child: _transactions.isEmpty
                ? const Center(child: Text('本月暂无记录', style: TextStyle(color: Colors.grey)))
                : _buildGroupedList(),
          ),
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
    // Group transactions by date
    Map<String, List<TransactionModel>> grouped = {};
    for (var t in _transactions) {
      if (!grouped.containsKey(t.date)) {
        grouped[t.date] = [];
      }
      grouped[t.date]!.add(t);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayTransactions = grouped[date]!;
        
        // Calculate daily total
        int dailyExpense = 0;
        int dailyIncome = 0;
        for (var t in dayTransactions) {
          if (t.type == 0) dailyExpense += t.amount;
          else dailyIncome += t.amount;
        }

        return Column(
          children: [
            // Daily Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(date, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  Text(
                    '收: ${(dailyIncome/100).toStringAsFixed(2)}  支: ${(dailyExpense/100).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            // Daily Transactions
            ...dayTransactions.map((t) => Dismissible(
              key: Key('trans_${t.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              // 只负责弹出确认对话，返回 true 则允许滑展动画执行
              confirmDismiss: (dir) => _confirmDelete(),
              // 动画完成后才真正执行删除
              onDismissed: (dir) async {
                await DBHelper().deleteTransaction(t.id!);
                if (mounted) _refreshData();
              },
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: t.type == 0 ? Colors.red.withAlpha(25) : Colors.green.withAlpha(25),
                  child: Icon(
                    _getIconForCategory(t.category),
                    color: t.type == 0 ? Colors.red : Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(t.category),
                subtitle: t.note.isNotEmpty ? Text(t.note) : null,
                trailing: Text(
                  '${t.type == 0 ? "-" : "+"}${(t.amount / 100.0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: t.type == 0 ? Colors.red : Colors.green,
                  ),
                ),
              ),
            )),
          ],
        );
      },
    );
  }

  IconData _getIconForCategory(String name) {
    // Simple mapping for now
    switch (name) {
      case '餐饮': return Icons.restaurant;
      case '交通': return Icons.directions_bus;
      case '购物': return Icons.shopping_cart;
      case '工资': return Icons.payments;
      default: return Icons.category;
    }
  }
}
