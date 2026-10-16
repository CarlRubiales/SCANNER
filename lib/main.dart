import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/recent_scans_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const LumoraScannerApp());
}

class LumoraScannerApp extends StatelessWidget {
  const LumoraScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumora Parcel Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ScannerScreen(isActive: _currentIndex == 0),
          const RecentScansScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppTheme.borderLight, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.orangeLight,
          elevation: 0,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.qr_code_scanner_rounded, color: AppTheme.orange),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.history_rounded, color: AppTheme.orange),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.orange),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
