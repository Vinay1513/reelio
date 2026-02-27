import 'package:flutter/material.dart';
import '../../feed/screens/feed_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../upload/screens/upload_screen.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    FeedScreen(),
    UploadScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens
            .asMap()
            .map((i, screen) {
              if (screen is FeedScreen) {
                return MapEntry(
                    i, FeedScreen(isVisible: _currentIndex == 0));
              }
              return MapEntry(i, screen);
            })
            .values
            .toList(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              _addButton(),
              _navItem(2, Icons.person_rounded, Icons.person_outlined, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData active, IconData inactive, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? active : inactive,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton() {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 1),
      child: Container(
        width: 52,
        height: 36,
        decoration: BoxDecoration(
          gradient: _currentIndex == 1
              ? AppTheme.primaryGradient
              : const LinearGradient(
                  colors: [AppTheme.surfaceColor, AppTheme.surfaceColor]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _currentIndex == 1
                ? Colors.transparent
                : AppTheme.textSecondary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}
