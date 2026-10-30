import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_constants.dart';
import '../core/localization/app_localizations.dart';
import '../models/promotion_model.dart';
import '../services/promotion_service.dart';

/// Visual tokens per theme — kept in step with the web `PromoBarView`.
class _PromoTheme {
  final List<Color> gradient;
  final Color foreground;
  final Color ctaBackground;
  final Color ctaForeground;
  final Color chip;

  const _PromoTheme(
    this.gradient,
    this.foreground,
    this.ctaBackground,
    this.ctaForeground,
    this.chip,
  );

  static _PromoTheme of(String key) {
    switch (key) {
      case 'brand':
        return const _PromoTheme(
          [Color(0xFF3B0F9A), Color(0xFF5B2BD1)],
          Colors.white,
          Colors.white,
          Color(0xFF3B0F9A),
          Color(0x33000000),
        );
      case 'dark':
        return const _PromoTheme(
          [Color(0xFF030712), Color(0xFF111827)],
          Colors.white,
          Color(0xFF6D3FE0),
          Colors.white,
          Color(0x1AFFFFFF),
        );
      case 'amber':
        return const _PromoTheme(
          [Color(0xFFFCD34D), Color(0xFFFBBF24)],
          Color(0xFF030712),
          Color(0xFF030712),
          Colors.white,
          Color(0x1A000000),
        );
      case 'sale':
      default:
        return const _PromoTheme(
          [Color(0xFFE11D48), Color(0xFFEF4444)],
          Colors.white,
          Colors.white,
          Color(0xFFBE123C),
          Color(0x33000000),
        );
    }
  }
}

/// Promotion bar for the home shell. Display only — it never affects pricing.
/// Shown to company owners (the only users who can buy); the CTA opens the web
/// billing page because the app has no checkout.
class PromoBar extends StatefulWidget {
  const PromoBar({super.key});

  @override
  State<PromoBar> createState() => _PromoBarState();
}

class _PromoBarState extends State<PromoBar> with WidgetsBindingObserver {
  static const _refreshEvery = Duration(minutes: 5);

  PromotionModel? _promo;
  Duration _offset = Duration.zero;
  bool _dismissed = false;
  int _messageIndex = 0;
  Timer? _ticker;
  Timer? _rotator;
  Timer? _refresher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refresher = Timer.periodic(_refreshEvery, (_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _rotator?.cancel();
    _refresher?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final active = await PromotionService.instance.fetchActive();
      final promo = active.promotion;
      var dismissed = false;
      if (promo != null && promo.dismissible) {
        final prefs = await SharedPreferences.getInstance();
        dismissed = prefs.getBool(promo.dismissKey) ?? false;
      }
      if (!mounted) return;
      setState(() {
        _promo = promo;
        _offset = active.serverOffset;
        _dismissed = dismissed;
        _messageIndex = 0;
      });
      _restartTimers();
    } catch (_) {
      // Offline or server error: keep whatever is showing; next refresh retries.
    }
  }

  void _restartTimers() {
    _ticker?.cancel();
    _rotator?.cancel();
    final promo = _promo;
    if (promo == null) return;
    if (promo.endsAt != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_remaining() <= Duration.zero) {
          _ticker?.cancel();
          _load(); // The server decides what (if anything) shows next.
        }
        setState(() {});
      });
    }
    if (promo.messages.length > 1) {
      _rotator = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        setState(
          () => _messageIndex = (_messageIndex + 1) % promo.messages.length,
        );
      });
    }
  }

  Duration _remaining() {
    final end = _promo?.endsAt;
    if (end == null) return const Duration(days: 9999);
    return end.difference(DateTime.now().add(_offset));
  }

  Future<void> _dismiss() async {
    final promo = _promo;
    if (promo == null) return;
    setState(() => _dismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(promo.dismissKey, true);
    } catch (_) {}
  }

  /// Absolute CTA target, or null when it needs the web origin and
  /// `WEB_APP_URL` is not configured.
  String? _ctaTarget(PromotionModel promo) {
    final raw = promo.ctaUrl.trim();
    if (raw.isNotEmpty && !raw.startsWith('/')) return raw;
    final web = AppConstants.webCrmUrl;
    if (web.isEmpty) return null;
    return raw.isEmpty ? '$web/change-plan' : '$web$raw';
  }

  Future<void> _openCta() async {
    final promo = _promo;
    if (promo == null) return;
    final target = _ctaTarget(promo);
    final uri = target != null ? Uri.tryParse(target) : null;
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final promo = _promo;
    if (promo == null || _dismissed || promo.messages.isEmpty) {
      return const SizedBox.shrink();
    }
    final remaining = _remaining();
    if (promo.endsAt != null && remaining <= Duration.zero) {
      return const SizedBox.shrink();
    }

    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final theme = _PromoTheme.of(promo.theme);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final message = promo.messages[_messageIndex % promo.messages.length]
        .textFor(lang);
    final cta = _ctaTarget(promo) != null ? promo.ctaLabelFor(lang) : '';

    Widget countdownChip(String value, String unit) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: theme.chip,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            TextSpan(
              text: unit,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 9),
            ),
          ],
        ),
        style: TextStyle(
          color: theme.foreground,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    final showCountdown = promo.showCountdown && promo.endsAt != null;
    final countdown = showCountdown
        ? Directionality(
            // Digits read left-to-right in both languages.
            textDirection: TextDirection.ltr,
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  countdownChip(
                    _two(remaining.inDays),
                    l?.translate('promoUnitD') ?? 'd',
                  ),
                  const SizedBox(width: 3),
                  countdownChip(
                    _two(remaining.inHours % 24),
                    l?.translate('promoUnitH') ?? 'h',
                  ),
                  const SizedBox(width: 3),
                  countdownChip(
                    _two(remaining.inMinutes % 60),
                    l?.translate('promoUnitM') ?? 'm',
                  ),
                  const SizedBox(width: 3),
                  countdownChip(
                    _two(remaining.inSeconds % 60),
                    l?.translate('promoUnitS') ?? 's',
                  ),
                ],
              ),
            ),
          )
        : null;

    final text = Text(
      message,
      key: ValueKey(_messageIndex),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: theme.foreground,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        height: 1.25,
      ),
    );

    return Semantics(
      container: true,
      label: l?.translate('promoRegion') ?? 'Promotion',
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: theme.gradient),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 4, 8),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    reduceMotion
                        ? text
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: text,
                          ),
                    if (countdown != null) ...[
                      const SizedBox(height: 5),
                      countdown,
                    ],
                  ],
                ),
              ),
              if (cta.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _openCta,
                  style: TextButton.styleFrom(
                    backgroundColor: theme.ctaBackground,
                    foregroundColor: theme.ctaForeground,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 34),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  child: Text(cta),
                ),
              ],
              if (promo.dismissible)
                IconButton(
                  onPressed: _dismiss,
                  tooltip: l?.translate('promoDismiss') ?? 'Dismiss promotion',
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.foreground,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
