import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class AppCurrency {
  AppCurrency._();

  /// Hard cap prevents overflow in cards, charts, and AppBars (999,999,999.99).
  static const double maxAmount = 999999999.99;

  static const Map<String, String> supportedCurrencies = {
    'BDT': '৳',
    'USD': '\$',
    'EUR': '€',
    'INR': '₹',
    'NPR': '₨',
  };

  /// Active currency code & global balance visibility state.
  static final ValueNotifier<String> currencyCode = ValueNotifier<String>('BDT');
  static final ValueNotifier<bool> hideBalances = ValueNotifier<bool>(false);

  static String get symbol => supportedCurrencies[currencyCode.value] ?? '৳';

  /// Parses user input safely to 2 decimal places (returns null if invalid).
  static double? parseAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return double.parse(value.toStringAsFixed(2));
  }

  /// Formats money consistently: ৳850,000 | ৳6.71 | -৳3,000 | ••••••
  static String format(
      double amount, {
        bool respectPrivacy = true,
        bool showPlusSign = false,
      }) {
    if (respectPrivacy && hideBalances.value) {
      return '$symbol••••••';
    }

    final rounded = double.parse(amount.toStringAsFixed(2));
    final isNegative = rounded < 0;
    final absVal = rounded.abs();

    // Preserve exact decimals when non-zero (e.g., 6.71), keep whole numbers clean.
    final hasDecimals = (absVal - absVal.truncateToDouble()).abs() > 0.001;
    final formatter = NumberFormat(hasDecimals ? '#,##0.00' : '#,##0');
    final formattedNumber = formatter.format(absVal);

    if (isNegative) return '-$symbol$formattedNumber';
    if (showPlusSign && rounded > 0) return '+$symbol$formattedNumber';
    return '$symbol$formattedNumber';
  }
}