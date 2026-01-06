import 'package:intl/intl.dart';

class NumberFormatter {
  /// Formats a number with thousand separators (e.g., 500000 -> "500,000")
  /// Automatically removes trailing zeros
  /// 
  /// [value] - The number to format (int or double)
  /// [decimals] - Maximum number of decimal places (default: auto-detect)
  /// [showDecimals] - Whether to show decimal places even if they are zero
  /// 
  /// Examples:
  /// - formatNumber(500000) -> "500,000"
  /// - formatNumber(500000.5) -> "500,000.5"
  /// - formatNumber(500000.0) -> "500,000"
  /// - formatNumber(500000.50) -> "500,000.5"
  static String formatNumber(
    num value, {
    int? decimals,
    bool showDecimals = false,
  }) {
    // Determine decimal places
    int decimalPlaces;
    if (decimals != null) {
      decimalPlaces = decimals;
    } else if (value is int) {
      decimalPlaces = 0;
    } else {
      // For doubles, check if it has decimal places
      final doubleValue = value.toDouble();
      if (doubleValue == doubleValue.truncateToDouble()) {
        decimalPlaces = showDecimals ? 1 : 0;
      } else {
        // Count significant decimal places (up to 2)
        final stringValue = doubleValue.toString();
        if (stringValue.contains('.')) {
          final decimalPart = stringValue.split('.')[1];
          // Count only significant digits (remove trailing zeros)
          int significantDigits = 0;
          for (int i = decimalPart.length - 1; i >= 0; i--) {
            if (decimalPart[i] != '0') {
              significantDigits = i + 1;
              break;
            }
          }
          decimalPlaces = significantDigits > 2 ? 2 : significantDigits;
        } else {
          decimalPlaces = showDecimals ? 1 : 0;
        }
      }
    }

    // Create number format with thousand separators
    final formatter = NumberFormat.currency(
      decimalDigits: decimalPlaces,
      symbol: '', // Remove currency symbol
    );

    String formatted = formatter.format(value);
    
    // Remove trailing zeros and decimal point if not needed
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), ''); // Remove trailing zeros
      formatted = formatted.replaceAll(RegExp(r'\.$'), ''); // Remove trailing decimal point
    }
    
    return formatted;
  }

  /// Formats a budget/currency value with thousand separators
  /// Similar to formatNumber but specifically for currency values
  /// Automatically removes trailing zeros
  /// 
  /// Examples:
  /// - formatCurrency(500000.0) -> "500,000"
  /// - formatCurrency(500000.5) -> "500,000.5"
  /// - formatCurrency(500000.50) -> "500,000.5"
  static String formatCurrency(
    num value, {
    int decimals = 2,
    bool showDecimals = false,
  }) {
    return formatNumber(value, decimals: decimals, showDecimals: showDecimals);
  }

  /// Formats a large number with abbreviations (e.g., 1000000 -> "1M")
  /// 
  /// Examples:
  /// - formatCompact(1000) -> "1K"
  /// - formatCompact(1000000) -> "1M"
  /// - formatCompact(1500000) -> "1.5M"
  static String formatCompact(num value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}

