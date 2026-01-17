import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import 'prayer_times_screen.dart';
import 'today_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.fastAnimation,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      HapticFeedback.lightImpact();
      _animationController.reset();
      setState(() {
        _currentIndex = index;
      });
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildCurrentScreen(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          selectedItemColor: isDark ? AppColors.luxuryGold : AppColors.deepBlue,
          unselectedItemColor: isDark
              ? AppColors.darkTextSecondary
              : AppColors.textTertiary,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.normal,
          ),
          items: [
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.home_outlined, 0),
              activeIcon: _buildNavIcon(Icons.home, 0, isActive: true),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.access_time, 1),
              activeIcon: _buildNavIcon(Icons.access_time, 1, isActive: true),
              label: 'Prières',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.menu_book_outlined, 2),
              activeIcon: _buildNavIcon(Icons.menu_book, 2, isActive: true),
              label: 'Quran',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.bookmark_border, 3),
              activeIcon: _buildNavIcon(Icons.bookmark, 3, isActive: true),
              label: 'Favoris',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.settings_outlined, 4),
              activeIcon: _buildNavIcon(Icons.settings, 4, isActive: true),
              label: 'Paramètres',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, {bool isActive = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: AppTheme.fastAnimation,
      curve: AppTheme.animationCurve,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: isActive
            ? (isDark
                  ? LinearGradient(
                      colors: [
                        AppColors.luxuryGold.withOpacity(0.2),
                        AppColors.luxuryGold.withOpacity(0.1),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        AppColors.deepBlue.withOpacity(0.1),
                        AppColors.deepBlue.withOpacity(0.05),
                      ],
                    ))
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 24),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const TodayScreen();
      case 1:
        return const PrayerTimesScreen();
      case 2:
        return const HomeScreen();
      case 3:
        return const FavoritesScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const TodayScreen();
    }
  }
}
