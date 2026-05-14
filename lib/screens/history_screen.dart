import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/note_template.dart';
import 'record_screen.dart';
import 'category_picker_screen.dart';

class HistoryScreen extends StatefulWidget {
  final int refreshKey;
  const HistoryScreen({super.key, this.refreshKey = 0});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TransactionModel> _transactions = [];
  DateTime _displayMonth = DateTime.now();
  Map<String, String> _categoryIconMap = {};

  // 内联编辑状态
  int? _editingId; // 当前正在编辑的 transaction id
  String _editMode = ''; // 'note' | 'amount'
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();
  List<NoteTemplate> _noteSuggestions = [];

  // 内联编辑的临时状态
  String? _editCategory;
  int _editType = 0;
  DateTime _editDate = DateTime.now();

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

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
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
      _editingId = null;
      _editMode = '';
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
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setLocal(() => tempYear--)),
              Text('$tempYear年'),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setLocal(() => tempYear++)),
            ],
          ),
          content: SizedBox(
            width: 280,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.6),
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
                      border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withAlpha(76)),
                    ),
                    alignment: Alignment.center,
                    child: Text('$month月', style: TextStyle(color: isSelected ? Colors.white : null, fontWeight: isSelected ? FontWeight.bold : null)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (tempMonth != null) {
      setState(() => _displayMonth = DateTime(tempYear, tempMonth!));
      _refreshData();
    }
  }

  /// 进入内联编辑模式
  void _startEditing(TransactionModel t, String mode) async {
    _noteController.text = t.note;
    _amountController.text = (t.amount / 100.0).toStringAsFixed(2);
    _editCategory = t.category;
    _editType = t.type;
    _editDate = DateTime.parse(t.date);

    List<NoteTemplate> suggestions = [];
    if (mode == 'note') {
      suggestions = await DBHelper().getNoteTemplates(t.category);
    }

    setState(() {
      _editingId = t.id;
      _editMode = mode;
      _noteSuggestions = suggestions;
    });

    if (mode == 'note') {
      Future.delayed(const Duration(milliseconds: 100), () {
        _noteFocusNode.requestFocus();
      });
    }
  }

  void _cancelEditing() {
    FocusScope.of(context).unfocus();
    setState(() {
      _editingId = null;
      _editMode = '';
    });
  }

  Future<void> _saveEditing(TransactionModel original) async {
    FocusScope.of(context).unfocus();

    final amountDouble = double.tryParse(_amountController.text) ?? (original.amount / 100.0);
    final updated = TransactionModel(
      id: original.id,
      amount: (amountDouble * 100).round(),
      type: _editType,
      category: _editCategory ?? original.category,
      date: DateFormat('yyyy-MM-dd').format(_editDate),
      note: _noteController.text,
    );

    await DBHelper().updateTransaction(updated);
    if (_noteController.text.isNotEmpty) {
      await DBHelper().saveNoteTemplate(updated.category, _noteController.text);
    }

    setState(() {
      _editingId = null;
      _editMode = '';
    });
    _refreshData();
  }

  /// 打开类别选择页
  Future<void> _openCategoryPicker(TransactionModel t) async {
    final result = await Navigator.push<Category>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryPickerScreen(
          selectedCategory: _editCategory ?? t.category,
          initialType: _editType,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _editCategory = result.name;
        _editType = result.type;
        _categoryIconMap[result.name] = result.icon;
      });
      // 重新加载该分类的备注建议
      final suggestions = await DBHelper().getNoteTemplates(result.name);
      setState(() => _noteSuggestions = suggestions);
    }
  }

  /// 打开旧版全量编辑弹窗
  void _showFullEditSheet(TransactionModel t) {
    _cancelEditing();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => RecordScreen(transaction: t, onSaved: _refreshData),
    );
  }

  /// 自定义数字键盘底部弹出
  void _showAmountPad(TransactionModel t) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _AmountPadSheet(
        initialAmount: _amountController.text,
        initialDate: _editDate,
        onConfirm: (amount, date) {
          setState(() {
            _amountController.text = amount;
            _editDate = date;
          });
        },
      ),
    );
  }

  void _showRecordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => RecordScreen(onSaved: _refreshData),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalExpense = 0;
    int totalIncome = 0;
    for (var t in _transactions) {
      if (t.type == 0) totalExpense += t.amount;
      else totalIncome += t.amount;
    }

    final isEditing = _editingId != null;

    return GestureDetector(
      onTap: isEditing ? _cancelEditing : null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('账单'),
          actions: [
            if (isEditing)
              TextButton(onPressed: _cancelEditing, child: const Text('取消'))
            else
              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _showRecordSheet),
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

            // 正在编辑时，底部显示建议栏 + 保存按钮
            Expanded(child: _buildGroupedList()),

            // 备注建议栏（仅在编辑备注模式下显示）
            if (_editingId != null && _editMode == 'note') _buildSuggestionsBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsBar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: [
                if (_noteSuggestions.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('暂无推荐备注', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ))
                else
                  ..._noteSuggestions.map((s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(s.note, style: const TextStyle(fontSize: 13)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _noteController.text = s.note;
                        _noteController.selection = TextSelection.fromPosition(
                          TextPosition(offset: s.note.length),
                        );
                      },
                    ),
                  )),
              ],
            ),
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
            // 日期头
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(date, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  Text(
                    [
                      if (dailyIncome > 0) '收入: ${(dailyIncome / 100).toStringAsFixed(2)}',
                      if (dailyExpense > 0) '支出: ${(dailyExpense / 100).toStringAsFixed(2)}',
                    ].join('  '),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ...dayTransactions.map((t) => _buildTransactionRow(t)),
          ],
        );
      },
    );
  }

  Widget _buildTransactionRow(TransactionModel t) {
    final isEditingThis = _editingId == t.id;
    final iconName = _editingThis(t) ? (_categoryIconMap[_editCategory ?? t.category] ?? 'category') : (_categoryIconMap[t.category] ?? 'category');
    final displayType = isEditingThis ? _editType : t.type;
    final iconColor = displayType == 0 ? Colors.red : Colors.green;

    if (isEditingThis) {
      return _buildEditingRow(t, iconName, iconColor);
    }

    return InkWell(
      onLongPress: () => _showFullEditSheet(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            // 左：图标（点击打开分类选择）
            GestureDetector(
              onTap: () {
                _startEditing(t, 'category');
                _openCategoryPicker(t);
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: iconColor.withAlpha(25),
                  child: Icon(Category.getIconData(_categoryIconMap[t.category] ?? 'category'), color: t.type == 0 ? Colors.red : Colors.green, size: 20),
                ),
              ),
            ),
            // 中：备注（点击编辑备注）
            Expanded(
              child: GestureDetector(
                onTap: () => _startEditing(t, 'note'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(t.note.isNotEmpty ? t.note : t.category, style: const TextStyle(fontSize: 15)),
                ),
              ),
            ),
            // 右：金额（点击弹出数字键盘）
            GestureDetector(
              onTap: () {
                _startEditing(t, 'amount');
                Future.delayed(const Duration(milliseconds: 50), () => _showAmountPad(t));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                child: Text(
                  '${t.type == 0 ? "-" : "+"}${(t.amount / 100.0).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.type == 0 ? Colors.red : Colors.green),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _editingThis(TransactionModel t) => _editingId == t.id;

  Widget _buildEditingRow(TransactionModel t, String iconName, Color iconColor) {
    return GestureDetector(
      onTap: () {}, // 阻止冒泡到 GestureDetector 取消编辑
      child: Container(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(60),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  // 左：图标（可点击换分类）
                  GestureDetector(
                    onTap: () => _openCategoryPicker(t),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircleAvatar(
                        backgroundColor: iconColor.withAlpha(40),
                        child: Icon(Category.getIconData(iconName), color: iconColor, size: 20),
                      ),
                    ),
                  ),
                  // 中：备注输入框（高亮）
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _editMode == 'note'
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent, width: 1.5),
                      ),
                      child: TextField(
                        controller: _noteController,
                        focusNode: _noteFocusNode,
                        decoration: const InputDecoration(
                          hintText: '备注',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                        onTap: () {
                          setState(() => _editMode = 'note');
                        },
                      ),
                    ),
                  ),
                  // 右：金额（可点击弹数字键盘）
                  GestureDetector(
                    onTap: () {
                      setState(() => _editMode = 'amount');
                      _showAmountPad(t);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _editMode == 'amount'
                            ? Theme.of(context).colorScheme.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _editMode == 'amount'
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        _amountController.text.isEmpty ? '0.00' : _amountController.text,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: iconColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 保存行
            Padding(
              padding: const EdgeInsets.only(left: 60, right: 12, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_editType == 0 ? "支出" : "收入"} · $_editCategory · ${DateFormat('yyyy-MM-dd').format(_editDate)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () => _saveEditing(t),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自定义金额数字键盘底部 Sheet
class _AmountPadSheet extends StatefulWidget {
  final String initialAmount;
  final DateTime initialDate;
  final void Function(String amount, DateTime date) onConfirm;

  const _AmountPadSheet({
    required this.initialAmount,
    required this.initialDate,
    required this.onConfirm,
  });

  @override
  State<_AmountPadSheet> createState() => _AmountPadSheetState();
}

class _AmountPadSheetState extends State<_AmountPadSheet> {
  late String _value;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _value = widget.initialAmount.replaceAll(RegExp(r'\.?0+$'), '');
    if (_value.isEmpty) _value = '';
    _date = widget.initialDate;
  }

  void _press(String key) {
    setState(() {
      if (key == '<') {
        if (_value.isNotEmpty) _value = _value.substring(0, _value.length - 1);
      } else if (key == '.') {
        if (!_value.contains('.')) _value += '.';
      } else {
        // 最多两位小数
        if (_value.contains('.')) {
          final parts = _value.split('.');
          if (parts[1].length < 2) _value += key;
        } else {
          if (_value == '0') {
            _value = key;
          } else {
            _value += key;
          }
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Widget _key(String label, {Color? bg, Color? fg, VoidCallback? onTap, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap ?? () => _press(label),
        child: Container(
          height: 56,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bg ?? Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: fg ?? Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy/MM/dd').format(_date);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // 日期 key（替代右上角的特殊按键）
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      height: 56,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(dateStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
                _key('7'), _key('8'), _key('9'),
              ],
            ),
            Row(children: [_key('4'), _key('5'), _key('6'), _key('', bg: Colors.transparent, onTap: () {})]),
            Row(children: [_key('1'), _key('2'), _key('3'), _key('', bg: Colors.transparent, onTap: () {})]),
            Row(
              children: [
                _key('.'),
                _key('0'),
                _key('⌫', onTap: () => _press('<')),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final amount = _value.isEmpty ? '0.00' : _value;
                      widget.onConfirm(amount, _date);
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 56,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text('完成', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
