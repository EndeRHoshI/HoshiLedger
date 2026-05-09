import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/note_template.dart';

class RecordScreen extends StatefulWidget {
  final VoidCallback onSaved;
  final TransactionModel? transaction; // 新增：用于编辑现有记录

  const RecordScreen({super.key, required this.onSaved, this.transaction});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  int _type = 0;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  List<Category> _categories = [];
  List<NoteTemplate> _noteTemplates = []; // 当前分类的历史备注

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      // 编辑模式：初始化数据
      _type = widget.transaction!.type;
      _selectedCategory = widget.transaction!.category;
      _selectedDate = DateTime.parse(widget.transaction!.date);
      _amountController.text = (widget.transaction!.amount / 100.0).toStringAsFixed(2);
      _noteController.text = widget.transaction!.note;
    }
    _loadCategories();
    // 监听全局分类更新通知
    DBHelper.categoryUpdateNotifier.addListener(_loadCategories);
  }

  Future<void> _loadCategories() async {
    final categories = await DBHelper().getCategories(_type);
    setState(() {
      _categories = categories;
      // 如果是新增模式且未选分类，选第一个
      if (widget.transaction == null && _selectedCategory == null && _categories.isNotEmpty) {
        _selectedCategory = _categories[0].name;
      }
      // 如果是编辑模式且分类不在列表中（被删了），手动补上
      if (_selectedCategory != null && !_categories.any((c) => c.name == _selectedCategory)) {
        _categories.insert(0, Category(name: _selectedCategory!, type: _type, icon: 'category'));
      }
    });
    await _loadNoteTemplates();
  }

  /// 加载当前分类的历史备注模板
  Future<void> _loadNoteTemplates() async {
    if (_selectedCategory == null) return;
    final templates = await DBHelper().getNoteTemplates(_selectedCategory!);
    setState(() => _noteTemplates = templates);
  }

  /// 切换分类时，同步加载该分类的历史备注
  void _selectCategory(String name) {
    FocusScope.of(context).unfocus();
    setState(() => _selectedCategory = name);
    _loadNoteTemplates();
  }

  void _switchType(int type) {
    if (_type == type) return;
    setState(() => _type = type);
    _loadCategories();
  }

  Future<void> _saveRecord() async {
    final amountText = _amountController.text;
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入金额')),
      );
      return;
    }

    final double? amountDouble = double.tryParse(amountText);
    if (amountDouble == null || amountDouble <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的金额')),
      );
      return;
    }

    final int amountCents = (amountDouble * 100).round();
    final String category = _selectedCategory ?? '未分类';
    final String note = _noteController.text;

    final record = TransactionModel(
      id: widget.transaction?.id, // 保留原 ID
      amount: amountCents,
      type: _type,
      category: category,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      note: note,
    );

    if (widget.transaction == null) {
      await DBHelper().insertTransaction(record);
    } else {
      await DBHelper().updateTransaction(record);
    }

    // 自动将非空备注保存为该分类的历史备注模板
    if (note.isNotEmpty) {
      await DBHelper().saveNoteTemplate(category, note);
    }

    widget.onSaved(); // 通知外部刷新

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已记录'), duration: Duration(seconds: 1)),
      );
    }

    // 弹窗模式下，记录完通常直接关闭
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteRecord() async {
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

    if (confirmed == true && mounted) {
      await DBHelper().deleteTransaction(widget.transaction!.id!);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    DBHelper.categoryUpdateNotifier.removeListener(_loadCategories);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.transaction == null ? '记一笔' : '编辑记录',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      if (widget.transaction != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: _deleteRecord,
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
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
                const SizedBox(width: 16),
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
            const SizedBox(height: 24),

            // 金额输入
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('￥', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                hintText: '0.00',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(76),
              ),
            ),
            const SizedBox(height: 24),

            // 分类选择
            const Text('选择分类', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _categories.isEmpty
                ? const Center(child: Text('暂无分类'))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat.name;
                      return ActionChip(
                        avatar: Icon(Category.getIconData(cat.icon), size: 18),
                        label: Text(cat.name),
                        onPressed: () => _selectCategory(cat.name),
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        side: isSelected ? BorderSide.none : null,
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 24),

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

            // 备注输入区（含历史备注快捷选择）
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.notes),
                hintText: '备注（选填）',
                border: InputBorder.none,
              ),
            ),

            // 历史备注快捷 Chip
            if (_noteTemplates.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _noteTemplates.map((t) => ActionChip(
                      label: Text(t.note, style: const TextStyle(fontSize: 12)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() => _noteController.text = t.note);
                        // 光标移到末尾
                        _noteController.selection = TextSelection.fromPosition(
                          TextPosition(offset: t.note.length),
                        );
                      },
                    )).toList(),
              ),
            ],
            const SizedBox(height: 32),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saveRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('保 存', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

}
