import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/bloc/theme/theme_bloc.dart';
import '../../core/bloc/language/language_bloc.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/api_service.dart';
import '../home/home_screen.dart';
import '../login/login_screen.dart';
import '../two_factor_auth/two_factor_auth_screen.dart';
import 'subscription_plan_billing_picker_screen.dart';

/// شاشة إتمام الدفع بعد التسجيل أو عند اشتراك غير مفعّل.
/// اختيار طريقة الدفع ثم فتح صفحة الدفع، مع زر "أكملت الدفع" للتحقق من حالة الاشتراك.
/// عند تمرير [loginUsername] و [loginPassword] (من شاشة تسجيل الدخول) نستخدم نفس آلية تسجيل الدخول
/// (requestTwoFactorAuth) لمعرفة إن أصبح الاشتراك مفعّلاً ثم التوجيه لشاشة 2FA.
class SubscriptionPaymentScreen extends StatefulWidget {
  const SubscriptionPaymentScreen({
    super.key,
    required this.subscriptionId,
    this.planId,
    this.billingCycle,
    this.loginUsername,
    this.loginPassword,
  });

  final int subscriptionId;
  final int? planId;
  final String? billingCycle;
  /// عند القدوم من تسجيل الدخول — لاستخدام requestTwoFactorAuth كسجل الدخول للتحقق من الاشتراك.
  final String? loginUsername;
  final String? loginPassword;

  @override
  State<SubscriptionPaymentScreen> createState() =>
      _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState extends State<SubscriptionPaymentScreen> {
  List<Map<String, dynamic>> _gateways = [];
  bool _loadingGateways = true;
  int? _selectedGatewayId;
  bool _isLoadingPaymentLink = false;
  bool _isCheckingStatus = false;
  String? _errorMessage;

  int? _selectedPlanId;
  String _selectedBillingCycle = 'monthly';

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.planId;
    _selectedBillingCycle = widget.billingCycle ?? 'monthly';
    _loadGateways();
  }

  Future<void> _loadGateways() async {
    setState(() {
      _loadingGateways = true;
      _errorMessage = null;
    });
    try {
      final apiService = ApiService();
      final list = await apiService.getPublicPaymentGateways();
      if (!mounted) return;
      setState(() {
        _gateways = list;
        _loadingGateways = false;
        _selectedGatewayId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGateways = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _openPlanBillingPicker() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => SubscriptionPlanBillingPickerScreen(
          initialPlanId: _selectedPlanId ?? widget.planId,
          initialBillingCycle: _selectedBillingCycle,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedPlanId = result['planId'] as int?;
        _selectedBillingCycle = result['billingCycle'] as String? ?? 'monthly';
      });
    }
  }

  static String _gatewayDisplayName(String name, String locale) {
    final n = name.toLowerCase();
    if (n.contains('paytabs') || n.contains('stripe')) {
      return locale == 'ar' ? 'بطاقة الدفع' : 'Card Payment';
    }
    return name;
  }

  /// مسار شعار البوابة إن وُجد (من assets/images/payment/).
  /// PayTabs و Stripe كلاهما دفع بالبطاقة — نعرض شعار Visa/Mastercard.
  static String? _gatewayLogoAsset(String name) {
    final n = name.toLowerCase();
    if (n.contains('paytabs') || n.contains('stripe')) return 'assets/images/payment/visa_master_logo.png';
    if (n.contains('zaincash') || n.contains('zain cash')) return 'assets/images/payment/zain_cash_logo.png';
    if (n.contains('qicard') || n.contains('qi card') || n.contains('q_card')) return 'assets/images/payment/q_card_logo.svg';
    return null;
  }

  Widget _buildGatewayLogo(String? assetPath) {
    if (assetPath == null) return const SizedBox.shrink();
    const size = 40.0;
    if (assetPath.endsWith('.svg')) {
      return SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox(width: size, height: size),
    );
  }

  Future<void> _openPaymentPage() async {
    if (_selectedGatewayId == null) return;
    setState(() {
      _isLoadingPaymentLink = true;
      _errorMessage = null;
    });

    try {
      final apiService = ApiService();
      final result = await apiService.createPaymentSessionByGateway(
        subscriptionId: widget.subscriptionId,
        gatewayId: _selectedGatewayId!,
        planId: _selectedPlanId ?? widget.planId,
        billingCycle: _selectedBillingCycle,
      );

      final redirectUrl = result['redirect_url'] as String?;
      if (redirectUrl == null || redirectUrl.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingPaymentLink = false;
            _errorMessage = AppLocalizations.of(context)!.translate('paymentSessionError');
          });
        }
        return;
      }

      final uri = Uri.tryParse(redirectUrl);
      if (uri == null) {
        if (mounted) {
          setState(() {
            _errorMessage = AppLocalizations.of(context)!.translate('paymentSessionError');
          });
        }
        return;
      }
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = AppLocalizations.of(context)!.translate('paymentSessionError');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _isLoadingPaymentLink = false;
          _errorMessage = msg.isNotEmpty ? msg : AppLocalizations.of(context)!.translate('paymentSessionError');
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingPaymentLink = false);
    }
  }

  /// نفس آلية تسجيل الدخول: إن وُجدت بيانات الدخول نستدعي requestTwoFactorAuth لمعرفة إن الاشتراك مفعّل الآن،
  /// وإلا نستدعي getCurrentUser() (عند القدوم من التسجيل أو السبلاش).
  Future<void> _checkPaymentAndContinue() async {
    setState(() {
      _isCheckingStatus = true;
      _errorMessage = null;
    });

    final apiService = ApiService();
    final username = widget.loginUsername?.trim();
    final password = widget.loginPassword;
    final hasLoginCredentials = username != null && username.isNotEmpty && password != null && password.isNotEmpty;

    if (hasLoginCredentials) {
      // نفس ما يفعله تسجيل الدخول: requestTwoFactorAuth يتحقق من الاشتراك في الباكند
      try {
        final language = context.read<LanguageBloc>().state.locale.languageCode;
        final twoFAResponse = await apiService.requestTwoFactorAuth(username, password, language);
        if (!mounted) return;
        setState(() => _isCheckingStatus = false);
        // الاشتراك مفعّل الآن — التوجيه لشاشة 2FA كسجل الدخول
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => TwoFactorAuthScreen(
              username: username,
              password: password,
              token: twoFAResponse['token'] as String?,
            ),
          ),
          (route) => false,
        );
      } on SubscriptionInactiveException catch (_) {
        if (!mounted) return;
        setState(() {
          _isCheckingStatus = false;
          _errorMessage = AppLocalizations.of(context)!.translate('paymentNotActiveYet');
        });
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString().replaceAll('Exception: ', '').trim();
        setState(() {
          _isCheckingStatus = false;
          _errorMessage = msg.isEmpty ? AppLocalizations.of(context)!.translate('paymentNotActiveYet') : msg;
        });
      }
      return;
    }

    // بدون بيانات دخول (من التسجيل أو السبلاش): نستخدم getCurrentUser()
    try {
      final user = await apiService.getCurrentUser();
      if (!mounted) return;
      setState(() => _isCheckingStatus = false);

      final subscriptionActive = user.company?.subscription?.isActive == true;
      if (!subscriptionActive) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.translate('paymentNotActiveYet');
        });
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingStatus = false);
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('401') || errStr.contains('unauthorized') || errStr.contains('authenticate')) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        if (mounted) {
          SnackbarHelper.showSuccess(
            context,
            AppLocalizations.of(context)!.translate('paymentCompletePleaseLogin'),
          );
        }
        return;
      }
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.translate('paymentNotActiveYet');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeBloc = context.watch<ThemeBloc>();
    final languageBloc = context.watch<LanguageBloc>();
    final isDark = themeBloc.state.themeMode == ThemeMode.dark;
    final locale = languageBloc.state.locale;
    final isRTL = locale.languageCode == 'ar';
    final l10n = AppLocalizations(locale);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(isRTL ? Icons.arrow_forward : Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          },
        ),
        title: Text(l10n.translate('paymentRequiredTitle')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _openPlanBillingPicker,
                icon: const Icon(Icons.swap_horiz),
                label: Text(l10n.translate('changePlanOrBilling')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.translate('paymentRequiredMessage'),
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.translate('selectPaymentMethod'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingGateways)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_gateways.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    l10n.translate('noPaymentGatewaysAvailable'),
                    style: TextStyle(
                      color: isDark ? Colors.orangeAccent : Colors.orange.shade800,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._gateways.map((g) {
                  final id = g['id'] is int ? g['id'] as int : int.tryParse(g['id'].toString());
                  if (id == null) return const SizedBox.shrink();
                  final name = g['name'] as String? ?? '';
                  final displayName = _gatewayDisplayName(name, locale.languageCode);
                  final selected = _selectedGatewayId == id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _selectedGatewayId = id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                              width: selected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _buildGatewayLogo(_gatewayLogoAsset(name)),
                              if (_gatewayLogoAsset(name) != null) const SizedBox(width: 12),
                              Icon(
                                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: selected ? Theme.of(context).colorScheme.primary : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: (_isLoadingPaymentLink || _selectedGatewayId == null) ? null : _openPaymentPage,
                icon: _isLoadingPaymentLink
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isRTL ? Icons.open_in_new : Icons.payment),
                label: Text(
                  _isLoadingPaymentLink
                      ? l10n.translate('loadingPaymentLink')
                      : l10n.translate('openPaymentPage'),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isCheckingStatus ? null : _checkPaymentAndContinue,
                icon: _isCheckingStatus
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(l10n.translate('iveCompletedPayment')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
