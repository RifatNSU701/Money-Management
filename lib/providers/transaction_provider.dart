import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// PERSONAL & WALLET MODELS
// =============================================================================
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
    required this.colorValue,
  });

  IconData get icon => isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'subtitle': subtitle, 'amount': amount,
    'isExpense': isExpense, 'date': date, 'iconCode': iconCode, 'colorValue': colorValue
  };

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
    id: json['id'], title: json['title'], subtitle: json['subtitle'],
    amount: (json['amount'] as num).toDouble(), isExpense: json['isExpense'],
    date: json['date'], iconCode: json['iconCode'], colorValue: json['colorValue'],
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
    id: json['id'], name: json['name'], amount: (json['amount'] as num).toDouble(), youOwe: json['youOwe'],
  );
}

class WalletModel {
  final String id;
  final String name;         // e.g., "Personal bKash" or "Salary Account"
  final String type;         // 'Cash', 'Mobile Banking', 'Bank Account'
  final String providerName; // e.g., 'bKash', 'Nagad', 'City Bank', 'DBBL'
  final String accountNumber;// e.g., '**** 4821'
  final double balance;

  WalletModel({
    required this.id,
    required this.name,
    required this.type,
    required this.providerName,
    this.accountNumber = '',
    required this.balance,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'providerName': providerName,
    'accountNumber': accountNumber,
    'balance': balance,
  };

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    // Migrate older saved data gracefully
    String rawType = json['type'] ?? 'Cash';
    if (rawType == 'Mobile') rawType = 'Mobile Banking';
    if (rawType == 'Bank') rawType = 'Bank Account';

    return WalletModel(
      id: json['id'],
      name: json['name'] ?? 'Account',
      type: rawType,
      providerName: json['providerName'] ?? ( json['name'] ?? 'Cash'),
      accountNumber: json['accountNumber'] ?? '',
      balance: (json['balance'] as num).toDouble(),
    );
  }
}

class ScheduledTxModel {
  final String id;
  final String title;
  final double amount;
  final String dueDate;
  final bool isExpense;

  ScheduledTxModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.isExpense,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'amount': amount, 'dueDate': dueDate, 'isExpense': isExpense
  };

  factory ScheduledTxModel.fromJson(Map<String, dynamic> json) => ScheduledTxModel(
    id: json['id'], title: json['title'], amount: (json['amount'] as num).toDouble(),
    dueDate: json['dueDate'], isExpense: json['isExpense'] ?? true,
  );
}

// =============================================================================
// BUSINESS MODELS
// =============================================================================
class ProductModel {
  final String id;
  final String name;
  final double price;
  final int stock;

  ProductModel({required this.id, required this.name, required this.price, required this.stock});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'stock': stock};

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id: json['id'], name: json['name'], price: (json['price'] as num).toDouble(), stock: json['stock'],
  );
}

class PartyModel {
  final String id;
  final String name;
  final String phone;
  final bool isCustomer;
  final double dueAmount;

  PartyModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.isCustomer,
    required this.dueAmount,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'phone': phone, 'isCustomer': isCustomer, 'dueAmount': dueAmount
  };

  factory PartyModel.fromJson(Map<String, dynamic> json) => PartyModel(
    id: json['id'], name: json['name'], phone: json['phone'] ?? '',
    isCustomer: json['isCustomer'], dueAmount: (json['dueAmount'] as num).toDouble(),
  );
}

class BusinessTxModel {
  final String id;
  final String title;
  final String type; // 'Sale', 'Purchase', 'Expense'
  final double amount;
  final String date;

  BusinessTxModel({required this.id, required this.title, required this.type, required this.amount, required this.date});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'type': type, 'amount': amount, 'date': date};

  factory BusinessTxModel.fromJson(Map<String, dynamic> json) => BusinessTxModel(
    id: json['id'], title: json['title'], type: json['type'],
    amount: (json['amount'] as num).toDouble(), date: json['date'],
  );
}

// =============================================================================
// UNIFIED PROVIDER
// =============================================================================
class TransactionProvider with ChangeNotifier {
  // Personal State
  List<TransactionModel> _transactions = [];
  Map<String, double> _budgets = {};
  List<String> _expenseCategories = ['Food & Dining', 'Transportation', 'Shopping', 'Entertainment'];
  List<String> _incomeCategories = ['Salary', 'Freelance / Projects', 'Investments', 'Gifts'];
  List<GroupModel> _groups = [];
  List<WalletModel> _wallets = [
    WalletModel(id: 'w1', name: 'Physical Cash', type: 'Cash', providerName: 'Cash', balance: 5000),
    WalletModel(id: 'w2', name: 'bKash Personal', type: 'Mobile Banking', providerName: 'bKash', accountNumber: '017****', balance: 12500),
    WalletModel(id: 'w3', name: 'Savings Account', type: 'Bank Account', providerName: 'DBBL (Dutch-Bangla)', accountNumber: '**** 4021', balance: 45000),
  ];
  List<ScheduledTxModel> _scheduledTxs = [];

  // Business State
  List<ProductModel> _products = [];
  List<PartyModel> _parties = [];
  List<BusinessTxModel> _businessTxs = [];

  TransactionProvider() {
    _loadData();
  }

  // Personal Getters
  List<TransactionModel> get transactions => _transactions.reversed.toList();
  Map<String, double> get budgets => _budgets;
  List<String> get expenseCategories => _expenseCategories;
  List<String> get incomeCategories => _incomeCategories;
  List<GroupModel> get groups => _groups;
  List<WalletModel> get wallets => _wallets;
  List<ScheduledTxModel> get scheduledTxs => _scheduledTxs;

  double get totalIncome => _transactions.where((tx) => !tx.isExpense).fold(0, (sum, tx) => sum + tx.amount);
  double get totalExpense => _transactions.where((tx) => tx.isExpense).fold(0, (sum, tx) => sum + tx.amount);
  double get totalBalance => totalIncome - totalExpense;
  double get totalWalletsBalance => _wallets.fold(0, (sum, w) => sum + w.balance);

  // Business Getters
  List<ProductModel> get products => _products;
  List<PartyModel> get parties => _parties;
  List<BusinessTxModel> get businessTxs => _businessTxs.reversed.toList();

  double get totalSales => _businessTxs.where((t) => t.type == 'Sale').fold(0, (s, t) => s + t.amount);
  double get totalPurchases => _businessTxs.where((t) => t.type == 'Purchase').fold(0, (s, t) => s + t.amount);
  double get totalBizExpenses => _businessTxs.where((t) => t.type == 'Expense').fold(0, (s, t) => s + t.amount);
  double get netProfit => totalSales - totalPurchases - totalBizExpenses;
  double get totalCustomerDue => _parties.where((p) => p.isCustomer).fold(0, (s, p) => s + p.dueAmount);
  int get totalCustomersCount => _parties.where((p) => p.isCustomer).length;
  int get lowStockCount => _products.where((p) => p.stock <= 5).length;

  String _generateTimestamp() {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');
    return '${months[now.month - 1]} ${now.day}, ${now.year} • $hour:$minute $amPm';
  }

  // --- PERSISTENCE ---
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('tx_data')) _transactions = (jsonDecode(prefs.getString('tx_data')!) as List).map((i) => TransactionModel.fromJson(i)).toList();
      if (prefs.containsKey('bdg_data')) _budgets = Map<String, double>.from(jsonDecode(prefs.getString('bdg_data')!));
      if (prefs.containsKey('exp_cat_data')) _expenseCategories = List<String>.from(jsonDecode(prefs.getString('exp_cat_data')!));
      if (prefs.containsKey('inc_cat_data')) _incomeCategories = List<String>.from(jsonDecode(prefs.getString('inc_cat_data')!));
      if (prefs.containsKey('grp_data')) _groups = (jsonDecode(prefs.getString('grp_data')!) as List).map((i) => GroupModel.fromJson(i)).toList();
      if (prefs.containsKey('wal_data')) _wallets = (jsonDecode(prefs.getString('wal_data')!) as List).map((i) => WalletModel.fromJson(i)).toList();
      if (prefs.containsKey('sch_data')) _scheduledTxs = (jsonDecode(prefs.getString('sch_data')!) as List).map((i) => ScheduledTxModel.fromJson(i)).toList();

      if (prefs.containsKey('biz_prod_data')) _products = (jsonDecode(prefs.getString('biz_prod_data')!) as List).map((i) => ProductModel.fromJson(i)).toList();
      if (prefs.containsKey('biz_party_data')) _parties = (jsonDecode(prefs.getString('biz_party_data')!) as List).map((i) => PartyModel.fromJson(i)).toList();
      if (prefs.containsKey('biz_tx_data')) _businessTxs = (jsonDecode(prefs.getString('biz_tx_data')!) as List).map((i) => BusinessTxModel.fromJson(i)).toList();
    } catch (e) {
      debugPrint("Data load error: $e");
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
    await prefs.setString('wal_data', jsonEncode(_wallets.map((w) => w.toJson()).toList()));
    await prefs.setString('sch_data', jsonEncode(_scheduledTxs.map((s) => s.toJson()).toList()));

    await prefs.setString('biz_prod_data', jsonEncode(_products.map((p) => p.toJson()).toList()));
    await prefs.setString('biz_party_data', jsonEncode(_parties.map((p) => p.toJson()).toList()));
    await prefs.setString('biz_tx_data', jsonEncode(_businessTxs.map((t) => t.toJson()).toList()));
  }

  // --- PERSONAL CRUD ---
  void saveTransaction({String? id, required String title, required String category, required double amount, required bool isExpense}) {
    final newTx = TransactionModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title, subtitle: category, amount: amount, isExpense: isExpense,
      date: _generateTimestamp(),
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

  // --- WALLETS & SCHEDULED CRUD ---
  void saveWallet({
    String? id,
    required String name,
    required String type,
    required String providerName,
    String accountNumber = '',
    required double balance,
  }) {
    final newWallet = WalletModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: type,
      providerName: providerName,
      accountNumber: accountNumber,
      balance: balance,
    );
    if (id == null) {
      _wallets.add(newWallet);
    } else {
      final idx = _wallets.indexWhere((w) => w.id == id);
      if (idx != -1) _wallets[idx] = newWallet;
    }
    _saveData();
    notifyListeners();
  }

  void deleteWallet(String id) {
    _wallets.removeWhere((w) => w.id == id);
    _saveData();
    notifyListeners();
  }

  void saveScheduledTx({String? id, required String title, required double amount, required String dueDate, required bool isExpense}) {
    final newSch = ScheduledTxModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title, amount: amount, dueDate: dueDate, isExpense: isExpense,
    );
    if (id == null) {
      _scheduledTxs.add(newSch);
    } else {
      final idx = _scheduledTxs.indexWhere((s) => s.id == id);
      if (idx != -1) _scheduledTxs[idx] = newSch;
    }
    _saveData();
    notifyListeners();
  }

  void deleteScheduledTx(String id) {
    _scheduledTxs.removeWhere((s) => s.id == id);
    _saveData();
    notifyListeners();
  }

  // --- BUSINESS CRUD ---
  void saveBusinessTx({String? id, required String title, required String type, required double amount}) {
    final newTx = BusinessTxModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title, type: type, amount: amount, date: _generateTimestamp(),
    );
    if (id == null) {
      _businessTxs.add(newTx);
    } else {
      final idx = _businessTxs.indexWhere((t) => t.id == id);
      if (idx != -1) _businessTxs[idx] = newTx;
    }
    _saveData();
    notifyListeners();
  }

  void deleteBusinessTx(String id) {
    _businessTxs.removeWhere((t) => t.id == id);
    _saveData();
    notifyListeners();
  }

  void saveProduct({String? id, required String name, required double price, required int stock}) {
    final newProd = ProductModel(id: id ?? DateTime.now().millisecondsSinceEpoch.toString(), name: name, price: price, stock: stock);
    if (id == null) {
      _products.add(newProd);
    } else {
      final idx = _products.indexWhere((p) => p.id == id);
      if (idx != -1) _products[idx] = newProd;
    }
    _saveData();
    notifyListeners();
  }

  void deleteProduct(String id) {
    _products.removeWhere((p) => p.id == id);
    _saveData();
    notifyListeners();
  }

  void saveParty({String? id, required String name, required String phone, required bool isCustomer, required double dueAmount}) {
    final newParty = PartyModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name, phone: phone, isCustomer: isCustomer, dueAmount: dueAmount,
    );
    if (id == null) {
      _parties.add(newParty);
    } else {
      final idx = _parties.indexWhere((p) => p.id == id);
      if (idx != -1) _parties[idx] = newParty;
    }
    _saveData();
    notifyListeners();
  }

  void deleteParty(String id) {
    _parties.removeWhere((p) => p.id == id);
    _saveData();
    notifyListeners();
  }
}