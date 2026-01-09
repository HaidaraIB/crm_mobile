import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/localization/app_localizations.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  
  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Leads on the left
              _buildNavItem(
                context,
                icon: Icons.people,
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
                label: localizations?.translate('leads') ?? 'Leads',
              ),
              
              // Home in the center (highlighted)
              _buildNavItem(
                context,
                icon: Icons.home,
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
                isCenter: true,
                label: localizations?.translate('home') ?? 'Home',
              ),
              
              // Calendar on the right
              _buildNavItem(
                context,
                icon: Icons.calendar_today,
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
                label: localizations?.translate('calendar') ?? 'Calendar',
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    bool isCenter = false,
    String? label,
  }) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCenter ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? AppTheme.primaryColor
                  : (theme.brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600]),
              size: isCenter ? 28 : 24,
            ),
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? AppTheme.primaryColor
                      : (theme.brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600]),
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


