import 'number_formatter.dart';

/// Parses "1000", "1000-5000", "1,000 – 5,000" into min (budget) and optional max.
({double? budget, double? budgetMax}) parseBudgetCell(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return (budget: null, budgetMax: null);
  final parts = s
      .split(RegExp(r'\s*[-–—]\s*'))
      .map((p) => p.replaceAll(',', '').trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return (budget: null, budgetMax: null);
  if (parts.length == 1) {
    final n = double.tryParse(parts[0]);
    return (budget: n, budgetMax: null);
  }
  final a = double.tryParse(parts.first);
  final b = double.tryParse(parts.last);
  if (a == null || b == null) return (budget: null, budgetMax: null);
  final lo = a < b ? a : b;
  final hi = a < b ? b : a;
  if (lo == hi) return (budget: lo, budgetMax: null);
  return (budget: lo, budgetMax: hi);
}

/// Formatted single amount or range for UI (uses en dash).
String formatLeadBudgetLine(double budget, double? budgetMax) {
  final hasLo = budget > 0;
  final hi = budgetMax;
  final hasHi = hi != null && hi > 0;
  if (!hasLo && !hasHi) return '';
  if (hasLo && !hasHi) return NumberFormatter.formatCurrency(budget);
  if (!hasLo && hasHi) return NumberFormatter.formatCurrency(hi);
  if (hi == budget) return NumberFormatter.formatCurrency(budget);
  final lo = budget < hi! ? budget : hi;
  final high = budget < hi ? hi : budget;
  return '${NumberFormatter.formatCurrency(lo)} – ${NumberFormatter.formatCurrency(high)}';
}

/// Parses optional min / max text fields from a form (two inputs).
({double? budget, double? budgetMax}) parseBudgetMinMaxFields(
  String minStr,
  String maxStr,
) {
  final lo = minStr.trim().isEmpty ? null : double.tryParse(minStr.trim());
  final hi = maxStr.trim().isEmpty ? null : double.tryParse(maxStr.trim());
  if (lo == null && hi == null) return (budget: null, budgetMax: null);
  if (lo != null && hi != null && hi != lo) {
    final a = lo < hi ? lo : hi;
    final b = lo < hi ? hi : lo;
    return (budget: a, budgetMax: b);
  }
  if (lo != null) return (budget: lo, budgetMax: null);
  return (budget: hi, budgetMax: null);
}
