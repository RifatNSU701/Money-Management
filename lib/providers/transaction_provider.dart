import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- MODELS ---
class TransactionModel {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final bool isExpense;
  final String date;
  final int iconCode;
  final int colorValue;

  TransactionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isExpense,
    required this.date,
    required this.iconCode,
    required this.colorValue
  });

  // FIX: Using constant Icons instead of a dynamic codePoint to satisfy the linter
  IconData get icon => isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'subtitle': subtitle, 'amount': amount,
    'isExpense': isExpense, 'date': date, 'iconCode': iconCode, 'colorValue': colorValue
  };

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
      id: json['id'], title: json['title'], subtitle: json['subtitle'],
      amount: json['amount'], isExpense: json['isExpense'], date: json['date'],
      iconCode: json['iconCode'], colorValue: json['colorValue']
  );
}

class GroupModel {
  final String id;
  final String name;
  final double amount;
  final bool youOwe;

  GroupModel({required this.id, required this.name, required this.amount, required this.youOwe});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'amount': amount, 'youOwe': youOwe};

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
      id: json['id'], name: json['name'], amount: json['amount'], youOwe: json['youOwe']
  );
}

// --- PROVIDER ---
class TransactionProvider with ChangeNotifier {
  List<TransactionModel> _transactions = [];
  Map<String, double> _budgets = {};
  List<String> _expenseCategories = ['Food & Dining', 'Transportation', 'Shopping', 'Entertainment'];
  List<String> _incomeCategories = ['Salary', 'Freelance / Projects', 'Investments', 'Gifts'];
  List<GroupModel> _groups = [];

  TransactionProvider() {
    _loadData();
  }

  // Getters
  List<TransactionModel> get transactions => _transactions.reversed.toList();
  Map<String, double> get budgets => _budgets;
  List<String> get expenseCategories => _expenseCategories;
  List<String> get incomeCategories => _incomeCategories;
  List<GroupModel> get groups => _groups;

  double get totalIncome => _transactions.where((tx) => !tx.isExpense).fold(0, (sum, tx) => sum + tx.amount);
  double get totalExpense => _transactions.where((tx) => tx.isExpense).fold(0, (sum, tx) => sum + tx.amount);

  // FIX: Restored the missing minus sign
  double get totalBalance => totalIncome - totalExpense;

  // --- BULLETPROOF PERSISTENCE ---
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('tx_data')) _transactions = (jsonDecode(prefs.getString('tx_data')!) as List).map((i) => TransactionModel.fromJson(i)).toList();
      if (prefs.containsKey('bdg_data')) _budgets = Map<String, double>.from(jsonDecode(prefs.getString('bdg_data')!));
      if (prefs.containsKey('exp_cat_data')) _expenseCategories = List<String>.from(jsonDecode(prefs.getString('exp_cat_data')!));
      if (prefs.containsKey('inc_cat_data')) _incomeCategories = List<String>.from(jsonDecode(prefs.getString('inc_cat_data')!));
      if (prefs.containsKey('grp_data')) _groups = (jsonDecode(prefs.getString('grp_data')!) as List).map((i) => GroupModel.fromJson(i)).toList();
    } catch (e) {
      debugPrint("Data load error (Ignored): $e");
    }
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tx_data', jsonEncode(_transactions.map((t) => t.toJson()).toList()));
    await prefs.setString('bdg_data', jsonEncode(_budgets));
    await prefs.setString('exp_cat_data', jsonEncode(_expenseCategories));
    await prefs.setString('inc_cat_data', jsonEncode(_incomeCategories));
    await prefs.setString('grp_data', jsonEncode(_groups.map((g) => g.toJson()).toList()));
  }

  // --- TRANSACTIONS CRUD (WITH AUTOMATIC DATE & TIME) ---
  void saveTransaction({String? id, required String title, required String category, required double amount, required bool isExpense}) {
    final now = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    // FIX: Restored the missing minus sign
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');

    // FIX: Restored the missing bullet point dot
    final dateStr = '${months[now.month-1]} ${now.day}, ${now.year} • $hour:$minute $amPm';

    final newTx = TransactionModel(
      id: id ?? now.millisecondsSinceEpoch.toString(),
      title: title,
      subtitle: category,
      amount: amount,
      isExpense: isExpense,
      date: dateStr,
      iconCode: isExpense ? Icons.arrow_upward_rounded.codePoint : Icons.arrow_downward_rounded.codePoint,
      colorValue: isExpense ? 0xFFFF5252 : 0xFF69F0AE,
    );

    if (id == null) {
      _transactions.add(newTx);
    } else {
      final index = _transactions.indexWhere((t) => t.id == id);
      if (index != -1) _transactions[index] = newTx;
    }
    _saveData();
    notifyListeners();
  }

  void deleteTransaction(String id) {
    _transactions.removeWhere((tx) => tx.id == id);
    _saveData();
    notifyListeners();
  }

  // --- BUDGETS CRUD ---
  void addBudget(String category, double limit) {
    _budgets[category] = limit;
    _saveData();
    notifyListeners();
  }

  void deleteBudget(String category) {
    _budgets.remove(category);
    _saveData();
    notifyListeners();
  }

  // --- CATEGORIES CRUD ---
  void addCategory(String name, bool isExpense) {
    if (isExpense && !_expenseCategories.contains(name)) _expenseCategories.add(name);
    if (!isExpense && !_incomeCategories.contains(name)) _incomeCategories.add(name);
    _saveData();
    notifyListeners();
  }

  void updateCategory(String oldName, String newName, bool isExpense) {
    if (isExpense) {
      final idx = _expenseCategories.indexOf(oldName);
      if (idx != -1) _expenseCategories[idx] = newName;
    } else {
      final idx = _incomeCategories.indexOf(oldName);
      if (idx != -1) _incomeCategories[idx] = newName;
    }
    _saveData();
    notifyListeners();
  }

  void deleteCategory(String name, bool isExpense) {
    if (isExpense) _expenseCategories.remove(name);
    if (!isExpense) _incomeCategories.remove(name);
    _saveData();
    notifyListeners();
  }

  // --- GROUPS CRUD ---
  void saveGroup({String? id, required String name, required double amount, required bool youOwe}) {
    final newGroup = GroupModel(id: id ?? DateTime.now().millisecondsSinceEpoch.toString(), name: name, amount: amount, youOwe: youOwe);
    if (id == null) {
      _groups.add(newGroup);
    } else {
      final index = _groups.indexWhere((g) => g.id == id);
      if (index != -1) _groups[index] = newGroup;
    }
    _saveData();
    notifyListeners();
  }

  void deleteGroup(String id) {
    _groups.removeWhere((g) => g.id == id);
    _saveData();
    notifyListeners();
  }
}