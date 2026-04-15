import 'package:flutter/material.dart';

/// Squircle action chip for WhatsApp / call / SMS — same look as phone number row.
class LeadContactActionButton extends StatelessWidget {
  const LeadContactActionButton({
    super.key,
    required this.accentColor,
    required this.onPressed,
    this.icon,
    this.isWhatsApp = false,
    this.tooltip,
  }) : assert(isWhatsApp || icon != null);

  final Color accentColor;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isWhatsApp;
  final String? tooltip;

  static const Color whatsappGreen = Color(0xFF25D366);

  static const double _size = 40;
  static const double _radius = 12;

  /// Material stroke icons — fills the box similarly to other actions.
  static const double _iconGlyphSize = 22;

  /// WhatsApp PNG has lots of transparent padding in the file; oversize vs glyphs (~90% of button).
  static const double _whatsappAssetSize = 36;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fill = isDark
        ? accentColor.withValues(alpha: 0.25)
        : accentColor.withValues(alpha: 0.1);
    final borderColor = isDark
        ? accentColor.withValues(alpha: 0.85)
        : accentColor.withValues(alpha: 0.3);
    final iconFg = isDark ? Colors.white : accentColor;

    final inner = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(_radius),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: borderColor,
              width: isDark ? 2 : 1.5,
            ),
          ),
          child: Center(
            child: isWhatsApp
                ? Image.asset(
                    'assets/images/whatsapp_logo.png',
                    width: _whatsappAssetSize,
                    height: _whatsappAssetSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.chat_bubble_outline,
                        color: iconFg,
                        size: _iconGlyphSize,
                      );
                    },
                  )
                : Icon(
                    icon!,
                    color: iconFg,
                    size: _iconGlyphSize,
                  ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        child: inner,
      );
    }
    return inner;
  }
}
