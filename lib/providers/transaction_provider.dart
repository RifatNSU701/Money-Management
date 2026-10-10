import 'package:flutter/material.dart';

class TransactionItem {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final bool isExpense;
  final String date;
  final IconData icon;
  final Color color;

  TransactionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isExpense,
    required this.date,
    required this.icon,
    required this.color,
  });
}

class TransactionProvider with ChangeNotifier {
  final List<TransactionItem> _transactions = [
    TransactionItem(
      id: '1',
      title: 'Foodpanda - Beef Rezala',
      subtitle: 'Food & Drink • Cash',
      amount: 450.0,
      isExpense: true,
      date: 'Today, 6:15 AM',
      icon: Icons.restaurant,
      color: Colors.orange,
    ),
    TransactionItem(
      id: '2',
      title: 'Grocery Store',
      subtitle: 'Household • Card',
      amount: 1200.0,
      isExpense: true,
      date: 'Yesterday',
      icon: Icons.shopping_bag,
      color: Colors.pink,
    ),
    TransactionItem(
      id: '3',
      title: 'Salary Deposit',
      subtitle: 'Income • Bank',
      amount: 50000.0,
      isExpense: false,
      date: 'Oct 1',
      icon: Icons.account_balance,
      color: Colors.green,
    ),
  ];

  List<TransactionItem> get transactions => List.unmodifiable(_transactions);

  double get totalIncome => _transactions
      .where((tx) => !tx.isExpense)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  double get totalExpense => _transactions
      .where((tx) => tx.isExpense)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  double get totalBalance => totalIncome - totalExpense;

  void addTransaction({
    required String title,
    required String category,
    required double amount,
    required bool isExpense,
  }) {
    _transactions.insert(
      0,
      TransactionItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        subtitle: '$category • ${isExpense ? 'Expense' : 'Income'}',
        amount: amount,
        isExpense: isExpense,
        date: 'Just now',
        icon: isExpense ? Icons.shopping_cart : Icons.payments,
        color: isExpense ? Colors.redAccent : Colors.greenAccent,
      ),
    );
    notifyListeners();
  }

  void deleteTransaction(String id) {
    _transactions.removeWhere((tx) => tx.id == id);
    notifyListeners();
  }
}