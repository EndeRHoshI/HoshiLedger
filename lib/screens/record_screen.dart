import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/note_template.dart';

class RecordScreen extends StatefulWidget {
  final VoidCallback onSaved;
  final String? initialCategory;       // 新建时预填类别
  final int? initialType;              // 新建时预填类型（0=支出 1=收入）

  const RecordScreen({
    super.key,
    required this.onSaved,
    this.initialCategory,
    this.initialType,
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  int _type = 0;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  List<NoteTemplate> _noteTemplates = []; // 当前分类的历史备注

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _type = widget.initialType ?? 0;
      _selectedCategory = widget.initialCategory;
    }
    _loadNoteTemplates();
    DBHelper.categoryUpdateNotifier.addListener(_loadNoteTemplates);
  }

  @override
  void dispose() {
    DBHelper.categoryUpdateNotifier.removeListener(_loadNoteTemplates);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 加载当前分类的历史备注模板
  Future<void> _loadNoteTemplates() async {
    if (_selectedCategory == null) return;
    final templates = await DBHelper().getNoteTemplates(_selectedCategory!);
    setState(() => _noteTemplates = templates);
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
                  const Text('记一笔',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
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

            // 历史备注快捷横向列表
            if (_noteTemplates.isNotEmpty) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _noteTemplates.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(t.note, style: const TextStyle(fontSize: 12)),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() => _noteController.text = t.note);
                            _noteController.selection = TextSelection.fromPosition(
                              TextPosition(offset: t.note.length),
                            );
                          },
                        ),
                      )).toList(),
                ),
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
