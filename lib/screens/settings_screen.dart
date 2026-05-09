import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../utils/csv_exporter.dart';
import '../models/category.dart';
import 'note_manager_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置与管理')),
      body: ListView(
        children: [
          _buildSectionHeader('数据管理'),
          ListTile(
            leading: const Icon(Icons.file_download, color: Colors.blue),
            title: const Text('导出数据为 CSV'),
            subtitle: const Text('保存账单到手机本地或分享'),
            onTap: () async {
              await CSVExporter.exportAllTransactions();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('清空全部数据'),
            subtitle: const Text('此操作不可恢复，请谨慎操作'),
            onTap: _confirmClearData,
          ),
          const Divider(),
          _buildSectionHeader('分类管理'),
          ListTile(
            leading: const Icon(Icons.category, color: Colors.orange),
            title: const Text('支出分类'),
            onTap: () => _manageCategories(0),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
            title: const Text('收入分类'),
            onTap: () => _manageCategories(1),
          ),
          const Divider(),
          _buildSectionHeader('备注管理'),
          ListTile(
            leading: const Icon(Icons.notes, color: Colors.teal),
            title: const Text('备注模板管理'),
            subtitle: const Text('查看和删除保存的历史备注'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NoteManagerScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('HoshiLedger'),
            subtitle: const Text('版本 1.0.0 · 极简离线记账'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('危险操作'),
        content: const Text('确定要清空所有账单记录吗？所有数据将被永久删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DBHelper().clearAllData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('数据已清空')));
    }
  }

  void _manageCategories(int type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CategoryManager(type: type)),
    );
  }
}

class CategoryManager extends StatefulWidget {
  final int type;
  const CategoryManager({super.key, required this.type});

  @override
  State<CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<CategoryManager> {
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final data = await DBHelper().getCategories(widget.type);
    setState(() => _categories = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == 0 ? '管理支出分类' : '管理收入分类'),
      ),
      body: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.category)),
            title: Text(cat.name),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                if (_categories.length <= 1) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('至少保留一个分类')));
                  return;
                }
                await DBHelper().deleteCategory(cat.id!);
                _loadCategories();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewCategory,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addNewCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增分类'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入分类名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('确定')),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await DBHelper().insertCategory(Category(name: name, type: widget.type, icon: 'category'));
      _loadCategories();
    }
  }
}
