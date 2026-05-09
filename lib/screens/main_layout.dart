import 'package:flutter/material.dart';
import 'record_screen.dart';
import 'history_screen.dart';
import 'statistics_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // 每次切换到对应 tab 时递增，子页面监听后自动刷新
  int _recordRefreshKey = 0;
  int _historyRefreshKey = 0;
  int _statisticsRefreshKey = 0;

  void _onTabSelected(int index) {
    setState(() {
      if (index == 0) _recordRefreshKey++;
      if (index == 1) _historyRefreshKey++;
      if (index == 2) _statisticsRefreshKey++;
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          RecordScreen(refreshKey: _recordRefreshKey),
          HistoryScreen(refreshKey: _historyRefreshKey),
          StatisticsScreen(refreshKey: _statisticsRefreshKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: '记一笔',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: '账单',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: '统计',
          ),
        ],
      ),
    );
  }
}
