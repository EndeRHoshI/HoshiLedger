import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  runApp(const HoshiLedgerApp());
}

class HoshiLedgerApp extends StatelessWidget {
  const HoshiLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HoshiLedger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4), // Warm Purple/Blue
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto', // Modern font
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainLayout(),
    );
  }
}
