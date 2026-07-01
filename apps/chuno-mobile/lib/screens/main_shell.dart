import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'ranking_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int idx = 0;

  static const _tabs = [
    ('🏠', '홈'),
    ('🏆', '랭킹'),
    ('📊', '기록'),
    ('👤', '프로필'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: idx,
          children: [
            const HomeScreen(),
            const RankingScreen(),
            const HistoryScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C0E12),
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.only(top: 10, bottom: 22),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var n = 0; n < _tabs.length; n++)
                GestureDetector(
                  onTap: () => setState(() => idx = n),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_tabs[n].$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(_tabs[n].$2,
                          style: TextStyle(fontSize: 10, color: n == idx ? AppColors.coral : AppColors.muted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
