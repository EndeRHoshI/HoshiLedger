import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/transaction_template.dart';
import '../widgets/transaction_template_tile.dart';
import 'template_editor_screen.dart';

class TemplateManagerScreen extends StatefulWidget {
  const TemplateManagerScreen({super.key});

  @override
  State<TemplateManagerScreen> createState() => _TemplateManagerScreenState();
}

class _TemplateManagerScreenState extends State<TemplateManagerScreen> {
  List<TransactionTemplate> _templates = [];
  bool _loading = true;
  bool _busy = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final templates = await DBHelper().getTransactionTemplates();
      if (mounted) setState(() => _templates = templates);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([TransactionTemplate? template]) async {
    if (_busy) return;
    setState(() => _busy = true);
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(template: template),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  Future<void> _delete(TransactionTemplate template) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除模板'),
          content: Text('删除「${template.name}」？已生成的账单会保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await DBHelper().deleteTransactionTemplate(template.id);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('模板删除失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_busy) return;
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final previous = List<TransactionTemplate>.of(_templates);
    setState(() {
      final template = _templates.removeAt(oldIndex);
      _templates.insert(newIndex, template);
      _busy = true;
    });
    try {
      await DBHelper().updateTransactionTemplatesOrder(_templates);
    } catch (_) {
      if (!mounted) return;
      setState(() => _templates = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('模板排序保存失败，请重试')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记账模板')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? Center(
              child: IconButton(
                onPressed: _load,
                tooltip: '重新加载模板',
                icon: const Icon(Icons.refresh),
              ),
            )
          : _templates.isEmpty
          ? const Center(child: Text('暂无模板'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              buildDefaultDragHandles: false,
              itemCount: _templates.length,
              onReorder: _reorder,
              itemBuilder: (context, index) {
                final template = _templates[index];
                return TransactionTemplateTile(
                  key: ValueKey(template.id),
                  template: template,
                  onTap: _busy ? null : () => _edit(template),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '删除模板',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _busy ? null : () => _delete(template),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        enabled: !_busy,
                        child: Tooltip(
                          message: '拖动排序',
                          triggerMode: TooltipTriggerMode.manual,
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            color: Colors.transparent,
                            child: const Icon(Icons.drag_handle),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新增模板',
        onPressed: _loading || _busy || _loadFailed ? null : () => _edit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
