import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class CategoryTransactionsScreen extends StatefulWidget {
  final String categoryName;
  final String periodLabel; // e.g. "2026年05月" or "2026年"
  final String periodFilter; // e.g. "2026-05" or "2026"
  final int transactionType; // 0 = expense, 1 = income

  const CategoryTransactionsScreen({
    super.key,
    required this.categoryName,
    required this.periodLabel,
    required this.periodFilter,
    required this.transactionType,
  });

  @override
  State<CategoryTransactionsScreen> createState() => _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState extends State<CategoryTransactionsScreen> {
  List<TransactionModel> _transactions = [];
  String _iconName = 'category';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DBHelper();
    final all = await db.getTransactionsByMonth(widget.periodFilter);
    final cats = await db.getAllCategories();

    final filtered = all
        .where((t) => t.category == widget.categoryName && t.type == widget.transactionType)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final catMatch = cats.firstWhere(
      (c) => c.name == widget.categoryName,
      orElse: () => Category(name: widget.categoryName, type: widget.transactionType, icon: 'category'),
    );

    setState(() {
      _transactions = filtered;
      _iconName = catMatch.icon;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpense = widget.transactionType == 0;
    final amountColor = isExpense ? Colors.red : Colors.green;

    final total = _transactions.fold(0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.categoryName),
            Text(
              widget.periodLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(child: Text('暂无数据'))
              : Column(
                  children: [
                    // Summary card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: amountColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Category.getIconData(_iconName),
                              color: amountColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '共 ${_transactions.length} 笔',
                                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '￥${(total / 100.0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: amountColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: ListView.separated(
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                        itemBuilder: (context, idx) {
                          final t = _transactions[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: amountColor.withAlpha(30),
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(color: amountColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              t.note.isNotEmpty ? t.note : widget.categoryName,
                              style: const TextStyle(fontSize: 15),
                            ),
                            subtitle: Text(
                              DateFormat('yyyy年MM月dd日').format(DateTime.parse(t.date)),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              '￥${t.amountDouble.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: amountColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
