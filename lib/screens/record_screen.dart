import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/note_template.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

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
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await DBHelper().getCategories(_type);
    setState(() {
      _categories = categories;
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories[0].name;
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
      amount: amountCents,
      type: _type,
      category: category,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      note: note,
    );

    await DBHelper().insertTransaction(record);

    // 自动将非空备注保存为该分类的历史备注模板
    if (note.isNotEmpty) {
      await DBHelper().saveNoteTemplate(category, note);
      await _loadNoteTemplates(); // 刷新备注列表
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已记录'), duration: Duration(seconds: 1)),
      );
    }

    // 连续记账：清空金额和备注，保留分类和日期
    setState(() {
      _amountController.clear();
      _noteController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('极简记账'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                prefixText: '￥ ',
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
                        avatar: Icon(_getIconData(cat.icon), size: 18),
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
                hintText: '备注（选填）',
                prefixIcon: Icon(Icons.notes),
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
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'movie':
        return Icons.movie;
      case 'medical_services':
        return Icons.medical_services;
      case 'home':
        return Icons.home;
      case 'payments':
        return Icons.payments;
      case 'trending_up':
        return Icons.trending_up;
      case 'work':
        return Icons.work;
      case 'redeem':
        return Icons.redeem;
      default:
        return Icons.category;
    }
  }
}
