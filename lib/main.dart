import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/main_layout.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  await ThemeService.init();
  runApp(const HoshiLedgerApp());
}

class HoshiLedgerApp extends StatelessWidget {
  const HoshiLedgerApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: colors.onSurface),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Hoshi记账',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeMode,
          home: const MainLayout(),
        );
      },
    );
  }
}
