import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction_template.dart';
import 'template_manager_screen.dart';

class TemplatePickerSheet extends StatefulWidget {
  final DateTime initialDate;

  const TemplatePickerSheet({super.key, required this.initialDate});

  @override
  State<TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<TemplatePickerSheet> {
  List<TransactionTemplate> _templates = [];
  bool _loading = true;
  bool _choosingDate = false;
  bool _applying = false;
  bool _loadFailed = false;

  bool get _busy => _choosingDate || _applying;

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

  Future<void> _manage() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const TemplateManagerScreen()),
    );
    if (mounted) await _load();
  }

  Future<void> _apply(TransactionTemplate template) async {
    if (_busy) return;
    setState(() => _choosingDate = true);
    try {
      final date = await showDatePicker(
        context: context,
        initialDate: widget.initialDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: '选择记账日期',
        confirmText: '应用模板',
        cancelText: '取消',
      );
      if (date == null || !mounted) return;
      setState(() {
        _choosingDate = false;
        _applying = true;
      });
      final count = await DBHelper().applyTransactionTemplate(
        template.id,
        DateFormat('yyyy-MM-dd').format(date),
      );
      if (!mounted) return;
      setState(() => _applying = false);
      Navigator.pop(
        context,
        TemplateApplicationResult(count: count, date: date),
      );
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message.toString())));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('应用模板失败，未新增账单，请重试')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _choosingDate = false;
          _applying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: FractionallySizedBox(
        heightFactor: 0.65,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '应用模板',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '管理模板',
                      onPressed: _busy || _loading ? null : _manage,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_applying)
                const LinearProgressIndicator(minHeight: 2)
              else
                const Divider(height: 2),
              Expanded(
                child: _loading
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
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('暂无模板'),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _manage,
                              icon: const Icon(Icons.add),
                              label: const Text('新增模板'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _templates.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final template = _templates[index];
                          return ListTile(
                            leading: const Icon(Icons.library_books_outlined),
                            title: Text(
                              template.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${template.entries.length} 笔 · 支出 ￥${(template.totalExpense / 100).toStringAsFixed(2)} · 收入 ￥${(template.totalIncome / 100).toStringAsFixed(2)}',
                            ),
                            trailing: const Icon(Icons.playlist_add_check),
                            enabled: !_busy,
                            onTap: () => _apply(template),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
