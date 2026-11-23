import 'package:flutter/services.dart';
import 'app_currency.dart';

class AppValidators {
  AppValidators._();

  /// Input formatters to block invalid characters while typing.
  static final List<TextInputFormatter> amountFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(\.\d{0,2})?$')),
  ];

  static final List<TextInputFormatter> digitsAndPlusOnly = [
    FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s]')),
  ];

  static final List<TextInputFormatter> accountNumberOnly = [
    FilteringTextInputFormatter.allow(RegExp(r'[\d\-\s]')),
  ];

  static String? requiredText(String? value, String fieldLabel) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel is required';
    }
    return null;
  }

  static String? positiveAmount(String? value, {String label = 'Amount'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    final parsed = AppCurrency.parseAmount(value);
    if (parsed == null) return 'Enter a valid number';
    if (parsed <= 0) return '$label must be greater than 0';
    if (parsed > AppCurrency.maxAmount) {
      return '$label cannot exceed ${AppCurrency.format(AppCurrency.maxAmount, respectPrivacy: false)}';
    }
    return null;
  }

  static String? nonNegativeAmount(String? value, {String label = 'Amount'}) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = AppCurrency.parseAmount(value);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return '$label cannot be negative';
    if (parsed > AppCurrency.maxAmount) {
      return '$label cannot exceed ${AppCurrency.format(AppCurrency.maxAmount, respectPrivacy: false)}';
    }
    return null;
  }

  static String? phoneNumber(String? value, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Phone number is required' : null;
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (RegExp(r'[a-zA-Z]').hasMatch(v) || digits.length < 7 || digits.length > 15) {
      return 'Enter a valid numeric phone number (7–15 digits)';
    }
    return null;
  }

  static String? accountNumber(String? value, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Account number is required' : null;
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (RegExp(r'[a-zA-Z]').hasMatch(v) || digits.length < 4) {
      return 'Account number must contain digits only';
    }
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 6}) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != originalPassword) return 'Passwords do not match';
    return null;
  }

  static String? stockQuantity(int qty, int availableStock) {
    if (qty <= 0) return 'Quantity must be at least 1';
    if (qty > availableStock) return 'Only $availableStock in stock';
    return null;
  }

  static String? uniqueMemberName(
      String? value,
      Iterable<String> existingNames, {
        String? editingOriginalName,
      }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Member name is required';
    final lower = v.toLowerCase();
    final originalLower = editingOriginalName?.trim().toLowerCase();
    final isDuplicate = existingNames.any(
          (name) => name.trim().toLowerCase() == lower && lower != originalLower,
    );
    if (isDuplicate) return '"$v" is already in this group';
    return null;
  }
}