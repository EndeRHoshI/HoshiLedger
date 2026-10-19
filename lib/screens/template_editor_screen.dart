import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/category.dart';
import '../models/transaction_template.dart';
import 'category_picker_screen.dart';
import 'record_screen.dart';

class TemplateEditorScreen extends StatefulWidget {
  final TransactionTemplate? template;

  const TemplateEditorScreen({super.key, this.template});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late final TextEditingController _nameController;
  late final List<TemplateEntry> _entries;
  Map<String, String> _categoryIcons = {};
  bool _dirty = false;
  bool _saving = false;
  bool _editingEntry = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _entries = List.of(widget.template?.entries ?? []);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await DBHelper().getAllCategories();
      if (!mounted) return;
      setState(
        () => _categoryIcons = {
          for (final category in categories)
            '${category.type}:${category.name}': category.icon,
        },
      );
    } catch (_) {
      // 分类图标加载失败时仍可编辑，条目使用通用图标。
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _confirmDiscard() async {
    if (_saving) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃修改？'),
        content: const Text('当前模板还有未保存的修改。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _dirty = false);
      Navigator.pop(context);
    }
  }

  Future<void> _editEntry([int? index]) async {
    if (_editingEntry || _saving) return;
    setState(() => _editingEntry = true);
    try {
      Category? selected;
      final entry = index == null ? null : _entries[index];
      if (entry == null) {
        selected = await Navigator.push<Category>(
          context,
          MaterialPageRoute(
            builder: (_) => const CategoryPickerScreen(initialType: 0),
          ),
        );
        if (selected == null || !mounted) return;
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        enableDrag: false,
        builder: (_) => RecordScreen(
          initialCategory: selected?.name,
          initialType: selected?.type,
          initialEntry: entry,
          onEntrySaved: (newEntry) {
            setState(() {
              if (index == null) {
                _entries.add(newEntry);
              } else {
                _entries[index] = newEntry;
              }
              _dirty = true;
            });
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _editingEntry = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _editingEntry) return;
    if (_nameController.text.trim().isEmpty || _entries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写模板名称并添加至少一条记录')));
      return;
    }
    setState(() => _saving = true);
    try {
      await DBHelper().saveTransactionTemplate(
        id: widget.template?.id,
        name: _nameController.text,
        entries: _entries,
      );
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saving = false;
      });
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('模板保存失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = _entries
        .where((entry) => entry.type == 0)
        .fold(0, (sum, entry) => sum + entry.amount);
    final income = _entries
        .where((entry) => entry.type == 1)
        .fold(0, (sum, entry) => sum + entry.amount);
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.template == null ? '新增模板' : '编辑模板'),
          actions: [
            IconButton(
              tooltip: '保存模板',
              onPressed: _saving || _editingEntry ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _nameController,
                enabled: !_saving,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: '模板名称',
                  counterText: '',
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_entries.length} 笔  ·  支出 ￥${(expense / 100).toStringAsFixed(2)}  ·  收入 ￥${(income / 100).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _entries.isEmpty
                  ? const Center(child: Text('暂无条目'))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      buildDefaultDragHandles: false,
                      itemCount: _entries.length,
                      onReorder: (oldIndex, newIndex) {
                        if (_saving || _editingEntry) return;
                        if (newIndex > oldIndex) newIndex--;
                        setState(() {
                          final entry = _entries.removeAt(oldIndex);
                          _entries.insert(newIndex, entry);
                          _dirty = true;
                        });
                      },
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        final color = entry.type == 0
                            ? Colors.red
                            : Colors.green;
                        return ListTile(
                          key: ObjectKey(entry),
                          onTap: _saving || _editingEntry
                              ? null
                              : () => _editEntry(index),
                          leading: Icon(
                            Category.getIconData(
                              _categoryIcons['${entry.type}:${entry.category}'] ??
                                  'category',
                            ),
                            color: color,
                          ),
                          title: Text(
                            entry.note.isEmpty ? entry.category : entry.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${entry.type == 0 ? '支出' : '收入'} · ${entry.category}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: SizedBox(
                            width: 176,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${entry.type == 0 ? '-' : '+'}${(entry.amount / 100).toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(color: color),
                                    maxLines: 2,
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: IconButton(
                                    tooltip: '删除条目',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 22,
                                    ),
                                    onPressed: _saving || _editingEntry
                                        ? null
                                        : () => setState(() {
                                            _entries.removeAt(index);
                                            _dirty = true;
                                          }),
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  enabled: !_saving && !_editingEntry,
                                  child: Tooltip(
                                    message: '拖动排序',
                                    triggerMode: TooltipTriggerMode.manual,
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.transparent,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.drag_handle),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: '添加条目',
          onPressed: _saving || _editingEntry ? null : () => _editEntry(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
