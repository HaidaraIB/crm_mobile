import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Brand avatar colors that stay readable in light and dark mode.
///
/// Avoids the common dark-mode trap of `primary.withOpacity(0.12)` + dark
/// primary glyph (nearly invisible on navy scaffolds).
class AppAvatarColors {
  const AppAvatarColors._();

  /// Solid circle fill for initials / icon fallbacks.
  static Color background(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF6D28D9) // violet-700 — clear lift off gray-900
      : AppTheme.primaryColor;

  static Color foreground(Brightness brightness) => Colors.white;

  /// Thin ring so photo avatars and dark circles don't dissolve into headers.
  static Color border(Brightness brightness, {bool onPrimaryBackground = false}) {
    if (onPrimaryBackground) {
      return Colors.white.withValues(alpha: 0.55);
    }
    return brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.28)
        : Color.lerp(AppTheme.primaryColor, Colors.black, 0.18)!;
  }

  /// Initials / icon on a purple AppBar (already brand-colored).
  static Color backgroundOnPrimary() => Colors.white.withValues(alpha: 0.22);

  static Color foregroundOnPrimary() => Colors.white;
}

/// Initials from a display name (up to [maxLetters] grapheme starts).
///
/// Skips leading `+` / digits so phone-only labels don't become a lone `+`.
String appAvatarInitials(String name, {int maxLetters = 2}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';

  // Phone-like: prefer a digit after the country code over punctuation.
  final phoneDigits = trimmed.replaceAll(RegExp(r'\D'), '');
  final looksLikePhone = trimmed.startsWith('+') ||
      (phoneDigits.length >= 7 && RegExp(r'^[\d\s+\-().]+$').hasMatch(trimmed));
  if (looksLikePhone && phoneDigits.isNotEmpty) {
    return phoneDigits[0];
  }

  final parts = trimmed
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';

  String firstLetter(String part) {
    for (final rune in part.runes) {
      final ch = String.fromCharCode(rune);
      if (RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(ch)) {
        return ch.toUpperCase();
      }
    }
    return part[0].toUpperCase();
  }

  return parts.take(maxLetters).map(firstLetter).join();
}

/// High-contrast circular avatar used across lists, chats, and headers.
///
/// Initials/icons stay visible underneath; a network photo only covers them
/// after a successful decode. Broken Meta/CDN URLs therefore never leave a
/// blank purple disc.
class AppAvatar extends StatefulWidget {
  const AppAvatar({
    super.key,
    this.radius = 24,
    this.initials,
    this.imageUrl,
    this.imageProvider,
    this.icon,
    this.onPrimaryBackground = false,
    this.showBorder = true,
  });

  final double radius;

  /// Shown when there is no usable image.
  final String? initials;

  final String? imageUrl;
  final ImageProvider? imageProvider;
  final IconData? icon;

  /// True when the avatar sits on [AppTheme.primaryColor] (AppBar, drawer hero).
  final bool onPrimaryBackground;

  /// Outline ring — keep on for photos/initials on dark surfaces.
  final bool showBorder;

  @override
  State<AppAvatar> createState() => _AppAvatarState();
}

class _AppAvatarState extends State<AppAvatar> {
  bool _imageFailed = false;
  bool _imageReady = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant AppAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imageProvider != widget.imageProvider) {
      _imageFailed = false;
      _imageReady = false;
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _unbindStream();
    super.dispose();
  }

  void _unbindStream() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  ImageProvider? get _provider {
    if (_imageFailed) return null;
    if (widget.imageProvider != null) return widget.imageProvider;
    final url = widget.imageUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    // Relative / non-http paths cannot load via NetworkImage.
    if (!(url.startsWith('http://') || url.startsWith('https://'))) {
      return null;
    }
    return NetworkImage(url);
  }

  void _resolveImage() {
    _unbindStream();
    final provider = _provider;
    if (provider == null) {
      if (_imageReady) {
        setState(() => _imageReady = false);
      }
      return;
    }

    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!mounted) return;
        setState(() {
          _imageReady = true;
          _imageFailed = false;
        });
      },
      onError: (Object exception, StackTrace? stackTrace) {
        if (!mounted) return;
        setState(() {
          _imageFailed = true;
          _imageReady = false;
        });
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final provider = _provider;
    final showPhoto = provider != null && _imageReady && !_imageFailed;

    final Color bg;
    final Color fg;
    if (widget.onPrimaryBackground) {
      bg = AppAvatarColors.backgroundOnPrimary();
      fg = AppAvatarColors.foregroundOnPrimary();
    } else {
      bg = AppAvatarColors.background(brightness);
      fg = AppAvatarColors.foreground(brightness);
    }

    final glyph = widget.icon != null
        ? Icon(widget.icon, color: fg, size: widget.radius)
        : Text(
            (widget.initials == null || widget.initials!.trim().isEmpty)
                ? '?'
                : widget.initials!.trim(),
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: widget.radius * 0.72,
              height: 1,
            ),
          );

    final size = widget.radius * 2;
    final avatar = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: bg,
              child: Center(child: glyph),
            ),
            if (showPhoto)
              Image(
                image: provider,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );

    if (!widget.showBorder) return avatar;

    final borderWidth = widget.radius >= 22 ? 1.5 : 1.25;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppAvatarColors.border(
            brightness,
            onPrimaryBackground: widget.onPrimaryBackground,
          ),
          width: borderWidth,
        ),
      ),
      child: avatar,
    );
  }
}
