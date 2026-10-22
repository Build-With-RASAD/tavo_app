// lib/feature/panel_dashboard/ui/widgets/dashboard_format.dart
import 'package:intl/intl.dart';

/// Number formatting for the dashboard.
///
/// The figures use LATIN digits with a thousands separator — the notation
/// Saudi Arabia actually uses — so the same numbers read identically in
/// both locales. Money always carries two decimals; counts are whole.
final NumberFormat _money = NumberFormat('#,##0.00', 'en');
final NumberFormat _count = NumberFormat.decimalPattern('en');

/// `4820.5` → `4,820.50`.
String formatMoney(double value) => _money.format(value);

/// `96250` → `96,250`.
String formatCount(num value) => _count.format(value);

/// A short axis label: `96250` → `96.3k`.
String formatCompactMoney(double value) {
  final absolute = value.abs();
  if (absolute >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (absolute >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(0);
}

/// `50` → `50%`, `7.29` → `7.3%`.
String formatPercent(double value, {int fractionDigits = 0}) =>
    '${value.toStringAsFixed(fractionDigits)}%';

/// The period-over-period delta. `null` (no previous data) renders as an
/// em dash — never a fake 0% and never an invented 100%.
String formatDelta(double? deltaPct) {
  if (deltaPct == null) return '—';
  final sign = deltaPct > 0 ? '+' : '';
  return '$sign${deltaPct.toStringAsFixed(1)}%';
}

/// A short axis label for a `yyyy-MM-dd` day: `2026-10-22` → `22 Oct`.
String formatDayLabel(String isoDate) {
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return isoDate;
  return DateFormat('d MMM', 'en').format(parsed);
}
