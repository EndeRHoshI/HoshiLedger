import 'package:flutter/material.dart';
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
  TransactionModel? _editingTransaction;
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();
  List<NoteTemplate> _noteSuggestions = [];
  String? _editCategory;
  int _editType = 0;
  DateTime _editDate = DateTime.now();
  String _editAmount = '';
  bool _autoSave = true; // 防止切换 amount/category 时触发误保存

  @override
  void initState() {
    super.initState();
    _refreshData();
    _noteFocusNode.addListener(() {
      if (!_noteFocusNode.hasFocus && _editingTransaction != null && _autoSave) {
        _performSave();
      }
    });
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _refreshData();
  }

  @override
  void dispose() {
    _noteController.dispose();
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

  Future<void> _performSave() async {
    final t = _editingTransaction;
    if (t == null) return;
    setState(() => _editingTransaction = null);

    final amountDouble = double.tryParse(_editAmount) ?? (t.amount / 100.0);
    final updated = TransactionModel(
      id: t.id,
      amount: (amountDouble * 100).round(),
      type: _editType,
      category: _editCategory ?? t.category,
      date: DateFormat('yyyy-MM-dd').format(_editDate),
      note: _noteController.text,
    );
    await DBHelper().updateTransaction(updated);
    if (_noteController.text.isNotEmpty) {
      await DBHelper().saveNoteTemplate(updated.category, _noteController.text);
    }
    _refreshData();
  }

  void _startEditing(TransactionModel t) async {
    _noteController.text = t.note;
    _editCategory = t.category;
    _editType = t.type;
    _editDate = DateTime.parse(t.date);
    _editAmount = (t.amount / 100.0).toStringAsFixed(2);

    final suggestions = await DBHelper().getNoteTemplates(t.category);
    setState(() {
      _editingTransaction = t;
      _noteSuggestions = suggestions;
    });
    Future.delayed(const Duration(milliseconds: 80), () => _noteFocusNode.requestFocus());
  }

  void _cancelEditing() {
    _autoSave = false;
    FocusScope.of(context).unfocus();
    setState(() => _editingTransaction = null);
    _autoSave = true;
  }

  Future<void> _openCategoryPicker() async {
    _autoSave = false;
    FocusScope.of(context).unfocus();

    final result = await Navigator.push<Category>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryPickerScreen(
          selectedCategory: _editCategory,
          initialType: _editType,
        ),
      ),
    );

    if (result != null) {
      _editCategory = result.name;
      _editType = result.type;
      final suggestions = await DBHelper().getNoteTemplates(result.name);
      setState(() {
        _noteSuggestions = suggestions;
        _categoryIconMap[result.name] = result.icon;
      });
    }

    _autoSave = true;
    if (result != null) _performSave();
  }

  Future<void> _openAmountSheet() async {
    _autoSave = false;
    FocusScope.of(context).unfocus();

    final amountCtrl = TextEditingController(text: _editAmount == '0.00' ? '' : _editAmount);
    DateTime sheetDate = _editDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withAlpha(80), borderRadius: BorderRadius.circular(2))),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('yyyy年MM月dd日').format(sheetDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: sheetDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setSheet(() => sheetDate = picked);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '￥',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    hintText: '0.00',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    _editAmount = amountCtrl.text.isEmpty ? _editAmount : amountCtrl.text;
    _editDate = sheetDate;
    amountCtrl.dispose();
    _autoSave = true;
    _performSave();
  }

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

  void _changeMonth(int delta) {
    _cancelEditing();
    setState(() => _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + delta));
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
                  onTap: () { tempMonth = month; Navigator.pop(ctx); },
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

  @override
  Widget build(BuildContext context) {
    int totalExpense = 0;
    int totalIncome = 0;
    for (var t in _transactions) {
      if (t.type == 0) totalExpense += t.amount; else totalIncome += t.amount;
    }
    final isEditing = _editingTransaction != null;

    return GestureDetector(
      onTap: () { if (isEditing) FocusScope.of(context).unfocus(); },
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
            if (isEditing) _buildSuggestionsBar(),
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
              children: _noteSuggestions.isEmpty
                  ? [const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('暂无推荐备注', style: TextStyle(color: Colors.grey, fontSize: 13))))]
                  : _noteSuggestions.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(s.note, style: const TextStyle(fontSize: 13)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _noteController.text = s.note;
                          _noteController.selection = TextSelection.fromPosition(TextPosition(offset: s.note.length));
                        },
                      ),
                    )).toList(),
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
        Text('￥${(amountCents / 100.0).toStringAsFixed(2)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildGroupedList() {
    final Map<String, List<TransactionModel>> grouped = {};
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
        final dayTxns = grouped[date]!;
        int dailyExpense = 0, dailyIncome = 0;
        for (var t in dayTxns) {
          if (t.type == 0) { dailyExpense += t.amount; } else { dailyIncome += t.amount; }
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
                      if (dailyIncome > 0) '收入: ${(dailyIncome / 100).toStringAsFixed(2)}',
                      if (dailyExpense > 0) '支出: ${(dailyExpense / 100).toStringAsFixed(2)}',
                    ].join('  '),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ...dayTxns.map((t) => _buildRow(t)),
          ],
        );
      },
    );
  }

  Widget _buildRow(TransactionModel t) {
    final isEditingThis = _editingTransaction?.id == t.id;
    final cat = isEditingThis ? (_editCategory ?? t.category) : t.category;
    final type = isEditingThis ? _editType : t.type;
    final iconName = _categoryIconMap[cat] ?? 'category';
    final iconColor = type == 0 ? Colors.red : Colors.green;

    if (isEditingThis) {
      return GestureDetector(
        onTap: () {}, // 阻止冒泡
        child: Container(
          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(60),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              // 图标 → 打开分类选择
              GestureDetector(
                onTap: _openCategoryPicker,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: iconColor.withAlpha(40),
                    child: Icon(Category.getIconData(iconName), color: iconColor, size: 20),
                  ),
                ),
              ),
              // 备注输入框（高亮）
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
                  ),
                  child: TextField(
                    controller: _noteController,
                    focusNode: _noteFocusNode,
                    decoration: const InputDecoration(
                      hintText: '备注',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              // 金额 → 打开金额弹窗
              GestureDetector(
                onTap: _openAmountSheet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  child: Text(
                    _editAmount,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: iconColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 普通行：长按打开全量编辑，各区域点击进入对应编辑
    return InkWell(
      onLongPress: () => _showFullEditSheet(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            GestureDetector(
              onTap: () async {
                _startEditing(t);
                await Future.delayed(const Duration(milliseconds: 120));
                _openCategoryPicker();
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: (t.type == 0 ? Colors.red : Colors.green).withAlpha(25),
                  child: Icon(Category.getIconData(_categoryIconMap[t.category] ?? 'category'),
                      color: t.type == 0 ? Colors.red : Colors.green, size: 20),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _startEditing(t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(t.note.isNotEmpty ? t.note : t.category, style: const TextStyle(fontSize: 15)),
                ),
              ),
            ),
            GestureDetector(
              onTap: () async {
                _startEditing(t);
                await Future.delayed(const Duration(milliseconds: 80));
                _openAmountSheet();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                child: Text(
                  '${t.type == 0 ? "-" : "+"}${(t.amount / 100.0).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                      color: t.type == 0 ? Colors.red : Colors.green),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
