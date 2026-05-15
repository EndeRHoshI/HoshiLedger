import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/note_template.dart';
import 'package:flutter/scheduler.dart';
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
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();
  List<NoteTemplate> _noteSuggestions = [];
  String? _editCategory;
  int _editType = 0;
  DateTime _editDate = DateTime.now();
  String _editAmount = '';
  bool _isSaving = false;
  // 编辑模式：'note' | 'amount' | null
  String? _editMode;

  @override
  void initState() {
    super.initState();
    _refreshData();
    // 移除可能引起 assertion 错误的 FocusNode 监听器，改用 TextField 的 onTapOutside
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _refreshData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    _noteFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final monthStr = DateFormat('yyyy-MM').format(_displayMonth);
    final data = await DBHelper().getTransactionsByMonth(monthStr);
    final allCats = await DBHelper().getAllCategories();
    
    if (!mounted) return;
    
    // 使用 addPostFrameCallback 确保在当前帧结束后再更新 UI，彻底避开 unmount 冲突
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _transactions = data;
          _categoryIconMap = {for (var c in allCats) c.name: c.icon};
        });
      }
    });
  }

  Future<void> _performSave() async {
    final t = _editingTransaction;
    if (t == null || !mounted || _isSaving) return;
    // 金额模式下，点击空白只退出不保存，需要点保存按鈕才提交金额
    if (_editMode == 'amount') {
      setState(() {
        _editingTransaction = null;
        _editMode = null;
      });
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    _isSaving = true;
    
    final note = _noteController.text;
    final amountDouble = double.tryParse(_editAmount) ?? (t.amount / 100.0);
    final updated = TransactionModel(
      id: t.id,
      amount: (amountDouble * 100).round(),
      type: _editType,
      category: _editCategory ?? t.category,
      date: DateFormat('yyyy-MM-dd').format(_editDate),
      note: note,
    );
    
    setState(() {
      _editingTransaction = null;
      _editMode = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    
    await DBHelper().updateTransaction(updated);
    if (note.isNotEmpty) {
      await DBHelper().saveNoteTemplate(updated.category, note);
    }
    _isSaving = false;
    _refreshData();
  }

  // 金额模式专用——点击保存按鈕才执行
  Future<void> _saveAmount() async {
    final t = _editingTransaction;
    if (t == null || !mounted || _isSaving) return;
    _isSaving = true;
    
    final amountStr = _amountController.text;
    final amountDouble = double.tryParse(amountStr) ?? (t.amount / 100.0);
    final updated = TransactionModel(
      id: t.id,
      amount: (amountDouble * 100).round(),
      type: _editType,
      category: _editCategory ?? t.category,
      date: DateFormat('yyyy-MM-dd').format(_editDate),
      note: t.note,
    );
    
    setState(() {
      _editingTransaction = null;
      _editMode = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    
    await DBHelper().updateTransaction(updated);
    _isSaving = false;
    _refreshData();
  }

  void _startEditingNote(TransactionModel t) async {
    if (_editingTransaction != null && _editingTransaction!.id != t.id) {
      await _performSave();
    }
    if (!mounted) return;
    _noteController.text = t.note;
    _editCategory = t.category;
    _editType = t.type;
    _editDate = DateTime.parse(t.date);
    _editAmount = (t.amount / 100.0).toStringAsFixed(2);
    final suggestions = await DBHelper().getNoteTemplates(t.category);
    setState(() {
      _editingTransaction = t;
      _editMode = 'note';
      _noteSuggestions = suggestions;
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _noteFocusNode.requestFocus();
    });
  }

  void _startEditingAmount(TransactionModel t) async {
    if (_editingTransaction != null && _editingTransaction!.id != t.id) {
      await _performSave();
    }
    if (!mounted) return;
    _noteController.text = t.note;
    _editCategory = t.category;
    _editType = t.type;
    _editDate = DateTime.parse(t.date);
    _editAmount = (t.amount / 100.0).toStringAsFixed(2);
    _amountController.text = _editAmount;
    setState(() {
      _editingTransaction = t;
      _editMode = 'amount';
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _amountFocusNode.requestFocus();
    });
  }

  void _cancelEditing() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _editingTransaction = null;
      _editMode = null;
    });
  }

  Future<void> _openCategoryPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final result = await Navigator.push<Category>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryPickerScreen(
          selectedCategory: _editCategory,
          initialType: _editType,
        ),
      ),
    );

    if (result != null && _editingTransaction != null && mounted) {
      final t = _editingTransaction!;
      _editCategory = result.name;
      _editType = result.type;
      final amountDouble = double.tryParse(_editAmount) ?? (t.amount / 100.0);
      final updated = TransactionModel(
        id: t.id,
        amount: (amountDouble * 100).round(),
        type: result.type,
        category: result.name,
        date: DateFormat('yyyy-MM-dd').format(_editDate),
        note: _noteController.text,
      );
      await DBHelper().updateTransaction(updated);
      setState(() {
        _editingTransaction = null;
        _editMode = null;
        _categoryIconMap[result.name] = result.icon;
      });
      _refreshData();
    } else if (mounted) {
      setState(() {
        _editingTransaction = null;
        _editMode = null;
      });
    }
  }

  // 金额内联编辑面板（替代 showModalBottomSheet）
  Widget _buildAmountPanel() {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.calendar_today, size: 18),
              title: Text(
                DateFormat('yyyy年MM月dd日').format(_editDate),
                style: const TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _editDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null && mounted) {
                  setState(() => _editDate = picked);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                controller: _amountController,
                focusNode: _amountFocusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: '￥',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: '0.00',
                  isDense: true,
                ),
              ),
            ),
            // 保存按鈕
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 16, 12),
                child: FilledButton(
                  onPressed: _saveAmount,
                  child: const Text('保存'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _showRecordSheet() async {
    // 第一步：先选类别
    final selectedCategory = await Navigator.push<Category>(
      context,
      MaterialPageRoute(
        builder: (_) => const CategoryPickerScreen(
          selectedCategory: null,
          initialType: 0,
        ),
      ),
    );

    // 用户取消选择则直接返回
    if (selectedCategory == null || !mounted) return;

    // 第二步：打开记一笔弹窗，预填好类别
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => RecordScreen(
        onSaved: _refreshData,
        initialCategory: selectedCategory.name,
        initialType: selectedCategory.type,
      ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('账单'),
        actions: [
          if (isEditing)
            TextButton(onPressed: _cancelEditing, child: const Text('取消'))
          else
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _showRecordSheet),
        ],
      ),
      body: Stack(
        children: [
          // 底层背景：点击空白处保存并取消编辑
          if (isEditing)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  debugPrint('HoshiLog: Background tapped, saving...');
                  FocusManager.instance.primaryFocus?.unfocus();
                  _performSave();
                },
              ),
            ),
          // 列表内容
          Column(
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
              if (isEditing && _editMode == 'note') _buildSuggestionsBar(),
              if (isEditing && _editMode == 'amount') _buildAmountPanel(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsBar() {
    return GestureDetector(
      onTap: () {}, // 阻止点击穿透到底层背景触发保存
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_editingTransaction != null) _performSave();
              },
              child: Container(
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
              // 备注区域：金额模式下显示文字，备注模式下显示输入框
              Expanded(
                child: _editMode == 'note'
                    ? Container(
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
                      )
                    : GestureDetector(
                        onTap: () => setState(() => _editMode = 'note'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                          child: Text(
                            _noteController.text.isNotEmpty ? _noteController.text : t.note.isNotEmpty ? t.note : t.category,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
              ),
              // 金额 → 切换到金额编辑模式
              GestureDetector(
                onTap: () => setState(() => _editMode = 'amount'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  child: Text(
                    _editMode == 'amount'
                        ? (_amountController.text.isEmpty ? _editAmount : _amountController.text)
                        : _editAmount,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: iconColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 普通行：点击 item 空白处尝试保存当前编辑
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
        if (_editingTransaction != null) {
          _performSave();
        }
      },
      onLongPress: () => _showFullEditSheet(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            GestureDetector(
              onTap: () async {
                if (_editingTransaction != null) await _performSave();
                
                // 直接记录状态并打开，但不设置 _editingTransaction，避免 UI 切换到编辑行
                _editCategory = t.category;
                _editType = t.type;
                _editDate = DateTime.parse(t.date);
                _editAmount = (t.amount / 100.0).toStringAsFixed(2);
                _noteController.text = t.note;
                
                _openCategoryPickerExternal(t);
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => _startEditingNote(t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      t.note.isNotEmpty ? t.note : t.category,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _startEditingAmount(t),
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
  // 外部调用的分类选择，不进入 inline 编辑模式
  Future<void> _openCategoryPickerExternal(TransactionModel t) async {
    final result = await Navigator.push<Category>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryPickerScreen(
          selectedCategory: t.category,
          initialType: t.type,
        ),
      ),
    );

    if (result != null && mounted) {
      final updated = TransactionModel(
        id: t.id,
        amount: t.amount,
        type: result.type,
        category: result.name,
        date: t.date,
        note: t.note,
      );
      await DBHelper().updateTransaction(updated);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _refreshData();
      });
    }
  }
}
