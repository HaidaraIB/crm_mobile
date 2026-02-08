import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/bloc/theme/theme_bloc.dart';
import '../../core/bloc/language/language_bloc.dart';
import '../../core/localization/app_localizations.dart';
import '../login/login_screen.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.track_changes,
      titleKey: 'onboardingTitle1',
      descriptionKey: 'onboardingDesc1',
      color: AppTheme.primaryColor,
    ),
    OnboardingPage(
      icon: Icons.analytics,
      titleKey: 'onboardingTitle2',
      descriptionKey: 'onboardingDesc2',
      color: AppTheme.primaryColor,
    ),
    OnboardingPage(
      icon: Icons.notifications_active,
      titleKey: 'onboardingTitle3',
      descriptionKey: 'onboardingDesc3',
      color: AppTheme.primaryColor,
    ),
    OnboardingPage(
      icon: Icons.security,
      titleKey: 'onboardingTitle4',
      descriptionKey: 'onboardingDesc4',
      color: AppTheme.primaryColor,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.hasSeenOnboardingKey, true);

    if (!mounted) return;

    final isLoggedIn = prefs.getBool(AppConstants.isLoggedInKey) ?? false;

    if (isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeBloc = context.read<ThemeBloc>();
    final languageBloc = context.read<LanguageBloc>();
    final currentTheme = themeBloc.state.themeMode;
    final currentLocale = languageBloc.state.locale;
    final l10n = AppLocalizations(currentLocale);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              currentLocale.languageCode == 'ar'
                  ? Icons.translate
                  : Icons.language,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            tooltip: currentLocale.languageCode == 'ar'
                ? l10n.translate('switchToEnglish')
                : l10n.translate('switchToArabic'),
            onPressed: () {
              final newLocale = currentLocale.languageCode == 'ar'
                  ? const Locale('en')
                  : const Locale('ar');
              languageBloc.add(ChangeLanguage(newLocale));
            },
          ),
          IconButton(
            icon: Icon(
              currentTheme == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            tooltip: currentTheme == ThemeMode.dark
                ? l10n.translate('switchToLightMode')
                : l10n.translate('switchToDarkMode'),
            onPressed: () {
              themeBloc.add(const ToggleTheme());
            },
          ),
          TextButton(
            onPressed: _skipOnboarding,
            child: Text(
              l10n.translate('skip'),
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF111827),
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                  ]
                : [
                    const Color(0xFFF9FAFB),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], isDark, l10n);
                  },
                ),
              ),

              // Page Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildIndicator(index == _currentPage, isDark),
                ),
              ),

              const SizedBox(height: 32),

              // Next/Get Started Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? l10n.translate('getStarted')
                          : l10n.translate('next'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, bool isDark, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Container
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: page.color,
            ),
          ),
          const SizedBox(height: 48),
          // Title
          Text(
            l10n.translate(page.titleKey),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Description
          Text(
            l10n.translate(page.descriptionKey),
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? Colors.white70
                  : Colors.black87.withValues(alpha: 0.7),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primaryColor
            : (isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final Color color;

  OnboardingPage({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.color,
  });
}
