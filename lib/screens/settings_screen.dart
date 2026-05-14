import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../database/db_helper.dart';
import '../utils/data_manager.dart';
import '../utils/shark_migration.dart';
import '../services/theme_service.dart';
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
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _buildSectionHeader('数据管理'),
          ListTile(
            leading: const Icon(Icons.file_upload, color: Colors.blue),
            title: const Text('导出数据备份'),
            subtitle: const Text('支持导出为 CSV 或 JSON'),
            onTap: _showExportDialog,
          ),
          ListTile(
            leading: const Icon(Icons.file_download, color: Colors.teal),
            title: const Text('导入/恢复数据'),
            subtitle: const Text('从 JSON 或 CSV 恢复账单'),
            onTap: _importData,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('清空全部数据'),
            subtitle: const Text('此操作不可恢复，请谨慎操作'),
            onTap: _confirmClearData,
          ),
          const Divider(),
          _buildSectionHeader('界面显示'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.themeModeNotifier,
            builder: (context, themeMode, _) {
              String themeText;
              IconData themeIcon;
              switch (themeMode) {
                case ThemeMode.light:
                  themeText = '浅色模式';
                  themeIcon = Icons.light_mode;
                  break;
                case ThemeMode.dark:
                  themeText = '深色模式';
                  themeIcon = Icons.dark_mode;
                  break;
                case ThemeMode.system:
                  themeText = '跟随系统';
                  themeIcon = Icons.brightness_auto;
                  break;
              }

              return ListTile(
                leading: Icon(themeIcon, color: Colors.purple),
                title: const Text('外观设置'),
                subtitle: Text(themeText),
                onTap: _showThemeSelector,
              );
            },
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.amber),
            title: const Text('【临时】迁移鲨鱼记账数据'),
            subtitle: const Text('一键导入 assets 中的 CSV 数据（用完即可删掉）'),
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const AlertDialog(content: Text('正在迁移中，请稍候...')),
              );
              int count = await SharkMigration.runMigration();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('成功导入了 $count 条记录！')));
            },
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

  void _showExportDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('导出为 CSV'),
              subtitle: const Text('适合在 Excel 中查看和统计'),
              onTap: () async {
                Navigator.pop(ctx);
                await DataManager.exportToCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.code, color: Colors.orange),
              title: const Text('导出为 JSON'),
              subtitle: const Text('包含完整结构，最适合用于日后恢复'),
              onTap: () async {
                Navigator.pop(ctx);
                await DataManager.exportToJSON();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复数据警告'),
        content: const Text('导入备份文件将彻底覆盖并清空当前所有的账单记录，是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定覆盖'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        bool success = await DataManager.importData(file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(success ? '数据恢复成功' : '数据恢复失败，文件格式可能有误')),
          );
        }
      }
    }
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

  void _showThemeSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('外观设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(ThemeMode.system, '跟随系统', Icons.brightness_auto),
            _buildThemeOption(ThemeMode.light, '浅色模式', Icons.light_mode),
            _buildThemeOption(ThemeMode.dark, '深色模式', Icons.dark_mode),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(ThemeMode mode, String title, IconData icon) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentMode, _) {
        final isSelected = currentMode == mode;
        return ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: isSelected ? const Icon(Icons.check, color: Colors.deepPurple) : null,
          onTap: () {
            ThemeService.setThemeMode(mode);
            Navigator.pop(context);
          },
        );
      },
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
        title: Text(widget.type == 0 ? '支出分类' : '收入分类'),
      ),
      body: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(51),
              child: Icon(Category.getIconData(cat.icon), color: Theme.of(context).colorScheme.primary),
            ),
            title: Text(cat.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editCategory(cat),
                ),
                IconButton(
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
              ],
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

  final List<String> _availableIcons = [
    // 餐饮
    'restaurant', 'fastfood', 'local_cafe',
    // 交通
    'directions_bus', 'directions_car', 'local_taxi', 'train', 'two_wheeler', 'local_gas_station', 'flight',
    // 购物生活
    'shopping_cart', 'phone_iphone', 'computer', 'checkroom', 'pets',
    // 娱乐运动
    'movie', 'sports_esports', 'fitness_center', 'icecream', 'liquor',
    // 家居医疗
    'home', 'electrical_services', 'handyman', 'medical_services',
    // 教育个人
    'school', 'self_improvement', 'volunteer_activism',
    // 财务
    'payments', 'account_balance', 'savings', 'trending_up',
    // 工作与礼赠
    'work', 'redeem', 'card_giftcard', 'celebration',
    // 其他
    'category'
  ];

  Future<void> _addNewCategory() async {
    _showCategoryDialog();
  }

  Future<void> _editCategory(Category category) async {
    _showCategoryDialog(category: category);
  }

  Future<void> _showCategoryDialog({Category? category}) async {
    final controller = TextEditingController(text: category?.name);
    String selectedIcon = category?.icon ?? 'category';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(category == null ? '新增分类' : '编辑分类'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: '输入分类名称'),
                  autofocus: false,
                ),
                const SizedBox(height: 20),
                const Text('选择图标', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.maxFinite,
                  height: 240, // 限制高度，防止溢出
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _availableIcons.length,
                    itemBuilder: (ctx, i) {
                      final iconName = _availableIcons[i];
                      final isSelected = selectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setLocalState(() => selectedIcon = iconName),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withAlpha(51),
                            ),
                          ),
                          child: Icon(Category.getIconData(iconName), size: 24),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      if (category == null) {
        await DBHelper().insertCategory(Category(
          name: controller.text,
          type: widget.type,
          icon: selectedIcon,
        ));
      } else {
        await DBHelper().updateCategory(Category(
          id: category.id,
          name: controller.text,
          type: widget.type,
          icon: selectedIcon,
        ));
      }
      _loadCategories();
    }
  }
}
