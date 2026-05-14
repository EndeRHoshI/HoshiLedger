import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/category.dart';

/// 全屏分类选择页，支持支出/收入切换
class CategoryPickerScreen extends StatefulWidget {
  final String? selectedCategory;
  final int initialType; // 0=支出, 1=收入

  const CategoryPickerScreen({
    super.key,
    this.selectedCategory,
    required this.initialType,
  });

  @override
  State<CategoryPickerScreen> createState() => _CategoryPickerScreenState();
}

class _CategoryPickerScreenState extends State<CategoryPickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialType,
    );
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final expense = await DBHelper().getCategories(0);
    final income = await DBHelper().getCategories(1);
    setState(() {
      _expenseCategories = expense;
      _incomeCategories = income;
    });
  }

  void _select(Category cat) {
    Navigator.pop(context, cat);
  }

  Widget _buildGrid(List<Category> cats, String? selected) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: cats.length,
      itemBuilder: (context, i) {
        final cat = cats[i];
        final isSelected = cat.name == selected;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return GestureDetector(
          onTap: () => _select(cat),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? primaryColor
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Icon(
                  Category.getIconData(cat.icon),
                  size: 26,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cat.name,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? primaryColor : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Expanded(
              child: TabBar(
                controller: _tabController,
                tabs: const [Tab(text: '支出'), Tab(text: '收入')],
                isScrollable: false,
                indicatorSize: TabBarIndicatorSize.label,
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGrid(_expenseCategories, widget.selectedCategory),
          _buildGrid(_incomeCategories, widget.selectedCategory),
        ],
      ),
    );
  }
}
