import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/note_template.dart';
import 'record_screen.dart';

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
    if (oldWidget.refreshKey != widget.refreshKey) {
      _refreshData();
    }
  }

  void _showRecordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允许弹窗随键盘高度调整
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RecordScreen(onSaved: _refreshData),
    );
  }

  Future<void> _refreshData() async {
    final monthStr = DateFormat('yyyy-MM').format(_displayMonth);
    final data = await DBHelper().getTransactionsByMonth(monthStr);

    int expense = 0;
    int income = 0;
    for (var t in data) {
      if (t.type == 0) {
        expense += t.amount;
      } else {
        income += t.amount;
      }
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

  /// 点击记录，弹出编辑底部弹窗
  void _showEditSheet(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允许底部弹窗跟随键盘
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditTransactionSheet(
        transaction: transaction,
        onSaved: () {
          Navigator.pop(ctx);
          _refreshData();
        },
        onDeleted: () {
          Navigator.pop(ctx);
          _refreshData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // 月份选择器和收支汇总
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
                  ],
                ),
              ],
            ),
          ),

          // 记录列表
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
    // 按日期分组
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

        int dailyExpense = 0;
        int dailyIncome = 0;
        for (var t in dayTransactions) {
          if (t.type == 0) {
            dailyExpense += t.amount;
          } else {
            dailyIncome += t.amount;
          }
        }

        return Column(
          children: [
            // 日期标题栏
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
            // 当日记录列表（点击进入编辑弹窗）
            ...dayTransactions.map((t) => ListTile(
                  onTap: () => _showEditSheet(t),
                  leading: CircleAvatar(
                    backgroundColor: t.type == 0 ? Colors.red.withAlpha(25) : Colors.green.withAlpha(25),
                    child: Icon(
                      _getIconForCategory(t.category),
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

  IconData _getIconForCategory(String name) {
    switch (name) {
      case '餐饮':
        return Icons.restaurant;
      case '交通':
        return Icons.directions_bus;
      case '购物':
        return Icons.shopping_cart;
      case '工资':
        return Icons.payments;
      default:
        return Icons.category;
    }
  }
}

// -------------------------------------------------------
// 编辑记录底部弹窗
// -------------------------------------------------------
class _EditTransactionSheet extends StatefulWidget {
  final TransactionModel transaction;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  const _EditTransactionSheet({
    required this.transaction,
    required this.onSaved,
    required this.onDeleted,
  });

  @override
  State<_EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<_EditTransactionSheet> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late int _type;
  late String _selectedCategory;
  late DateTime _selectedDate;
  List<Category> _categories = [];
  List<NoteTemplate> _noteTemplates = [];

  @override
  void initState() {
    super.initState();
    _type = widget.transaction.type;
    _selectedCategory = widget.transaction.category;
    _selectedDate = DateTime.parse(widget.transaction.date);
    _amountController = TextEditingController(
      text: (widget.transaction.amount / 100.0).toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: widget.transaction.note);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await DBHelper().getCategories(_type);
    setState(() {
      _categories = cats;
      // 如果当前分类不在列表中，保留原值
      if (!_categories.any((c) => c.name == _selectedCategory)) {
        _categories.insert(0, Category(name: _selectedCategory, type: _type, icon: 'category'));
      }
    });
    await _loadNoteTemplates();
  }

  Future<void> _loadNoteTemplates() async {
    final templates = await DBHelper().getNoteTemplates(_selectedCategory);
    setState(() => _noteTemplates = templates);
  }

  void _selectCategory(String name) {
    FocusScope.of(context).unfocus();
    setState(() => _selectedCategory = name);
    _loadNoteTemplates();
  }

  void _switchType(int type) {
    FocusScope.of(context).unfocus();
    if (_type == type) return;
    setState(() => _type = type);
    _loadCategories();
  }

  Future<void> _save() async {
    final amountText = _amountController.text;
    final double? amountDouble = double.tryParse(amountText);
    if (amountDouble == null || amountDouble <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的金额')),
      );
      return;
    }

    final updated = TransactionModel(
      id: widget.transaction.id,
      amount: (amountDouble * 100).round(),
      type: _type,
      category: _selectedCategory,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      note: _noteController.text,
    );

    await DBHelper().updateTransaction(updated);
    if (updated.note.isNotEmpty) {
      await DBHelper().saveNoteTemplate(updated.category, updated.note);
    }
    widget.onSaved();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？该操作无法撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DBHelper().deleteTransaction(widget.transaction.id!);
      widget.onDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('编辑记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _delete,
                    tooltip: '删除此记录',
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // 收支切换
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('支出')),
                    selected: _type == 0,
                    onSelected: (_) => _switchType(0),
                    selectedColor: Colors.red.withAlpha(51),
                    labelStyle: TextStyle(
                      color: _type == 0 ? Colors.red : null,
                      fontWeight: _type == 0 ? FontWeight.bold : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('收入')),
                    selected: _type == 1,
                    onSelected: (_) => _switchType(1),
                    selectedColor: Colors.green.withAlpha(51),
                    labelStyle: TextStyle(
                      color: _type == 1 ? Colors.green : null,
                      fontWeight: _type == 1 ? FontWeight.bold : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 金额输入
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('￥', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                labelText: '金额',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // 分类选择
            const Text('分类', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            _categories.isEmpty
                ? const Text('暂无分类')
                : Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat.name;
                      return ChoiceChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (_) => _selectCategory(cat.name),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 16),

            // 日期选择
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('yyyy年MM月dd日').format(_selectedDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                FocusScope.of(context).unfocus();
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
            ),
            const Divider(),

            // 备注输入
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: '备注（选填）',
                prefixIcon: Icon(Icons.notes),
                border: InputBorder.none,
              ),
            ),

            // 历史备注快捷 Chip
            if (_noteTemplates.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _noteTemplates.map((t) => ActionChip(
                      label: Text(t.note, style: const TextStyle(fontSize: 12)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() => _noteController.text = t.note);
                        _noteController.selection = TextSelection.fromPosition(
                          TextPosition(offset: t.note.length),
                        );
                      },
                    )).toList(),
              ),
            ],
            const SizedBox(height: 16),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('保存修改', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
