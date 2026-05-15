import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/note_template.dart';

/// 备注模板管理页，支持按分类分组展示、删除和拖拽排序
class NoteManagerScreen extends StatefulWidget {
  const NoteManagerScreen({super.key});

  @override
  State<NoteManagerScreen> createState() => _NoteManagerScreenState();
}

class _NoteManagerScreenState extends State<NoteManagerScreen> {
  Map<String, List<NoteTemplate>> _grouped = {};
  bool _isEmpty = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final all = await DBHelper().getAllNoteTemplates();
    final Map<String, List<NoteTemplate>> grouped = {};
    for (var t in all) {
      grouped.putIfAbsent(t.category, () => []).add(t);
    }
    setState(() {
      _grouped = grouped;
      _isEmpty = all.isEmpty;
    });
  }

  Future<void> _delete(NoteTemplate template) async {
    await DBHelper().deleteNoteTemplate(template.id!);
    _loadTemplates();
  }

  /// 处理拖拽排序后的更新
  Future<void> _onReorder(String category, int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final List<NoteTemplate> items = _grouped[category]!;
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
    });
    // 同步到数据库
    await DBHelper().updateNoteTemplatesOrder(_grouped[category]!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('备注管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '长按可拖动排序',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
      body: _isEmpty
          ? const Center(
              child: Text('暂无保存的备注\n记账时填写备注后会自动保存到这里',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            )
          : ListView(
              children: _grouped.entries.map((entry) {
                final category = entry.key;
                final templates = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 分类名称标题
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(76),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    // 该分类下的备注列表（支持拖拽排序）
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: templates.length,
                      onReorder: (oldIdx, newIdx) => _onReorder(category, oldIdx, newIdx),
                      itemBuilder: (context, index) {
                        final t = templates[index];
                        return ListTile(
                          key: ValueKey(t.id),
                          leading: const Icon(Icons.drag_handle, size: 20, color: Colors.grey),
                          title: Text(t.note),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('删除备注'),
                                  content: Text('确定要删除备注「${t.note}」吗？'),
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
                              );
                              if (confirmed == true) {
                                await _delete(t);
                              }
                            },
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
    );
  }
}
