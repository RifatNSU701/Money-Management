import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'amount': amount,
    'isExpense': isExpense,
    'date': date,
    'iconCode': iconCode,
    'colorValue': colorValue,
  };

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
    id: json['id'],
    title: json['title'],
    subtitle: json['subtitle'],
    amount: (json['amount'] as num).toDouble(),
    isExpense: json['isExpense'],
    date: json['date'],
    iconCode: json['iconCode'],
    colorValue: json['colorValue'],
  );
}

// =============================================================================
// ADVANCED GROUP / TRIP SPLITTING MODELS
// =============================================================================
class GroupMemberModel {
  final String id;
  final String name;
  final double paidAmount;

  GroupMemberModel({
    required this.id,
    required this.name,
    required this.paidAmount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'paidAmount': paidAmount,
  };

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) => GroupMemberModel(
    id: json['id'],
    name: json['name'],
    paidAmount: (json['paidAmount'] as num).toDouble(),
  );
}

class GroupExpenseModel {
  final String id;
  final String title;
  final double amount;
  final String paidByMemberId;
  final String paidByMemberName;
  final String date;

  GroupExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidByMemberId,
    required this.paidByMemberName,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'paidByMemberId': paidByMemberId,
    'paidByMemberName': paidByMemberName,
    'date': date,
  };

  factory GroupExpenseModel.fromJson(Map<String, dynamic> json) => GroupExpenseModel(
    id: json['id'],
    title: json['title'],
    amount: (json['amount'] as num).toDouble(),
    paidByMemberId: json['paidByMemberId'] ?? 'pool',
    paidByMemberName: json['paidByMemberName'] ?? 'Group Pool',
    date: json['date'] ?? '',
  );
}

class GroupModel {
  final String id;
  final String name;
  final double totalBudget;
  final String createdAt;
  final List<GroupMemberModel> members;
  final List<GroupExpenseModel> expenses;

  GroupModel({
    required this.id,
    required this.name,
    required this.totalBudget,
    required this.createdAt,
    required this.members,
    required this.expenses,
  });

  int get memberCount => members.length;
  double get targetPerMember => memberCount > 0 ? (totalBudget / memberCount) : 0.0;
  double get totalCollected => members.fold(0.0, (sum, m) => sum + m.paidAmount);
  double get totalOwedToBudget => (totalBudget - totalCollected) > 0 ? (totalBudget - totalCollected) : 0.0;
  double get totalSpent => expenses.fold(0.0, (sum, e) => sum + e.amount);
  double get spentPerMember => memberCount > 0 ? (totalSpent / memberCount) : 0.0;
  double get poolBalanceLeft => totalCollected - totalSpent;
  double get budgetRemaining => totalBudget - totalSpent;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'totalBudget': totalBudget,
    'createdAt': createdAt,
    'members': members.map((m) => m.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
  };

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      name: json['name'] ?? 'Group Plan',
      totalBudget: ((json['totalBudget'] ?? json['amount'] ?? 0) as num).toDouble(),
      createdAt: json['createdAt'] ?? 'Active Plan',
      members: json['members'] != null
          ? (json['members'] as List).map((m) => GroupMemberModel.fromJson(m)).toList()
          : [],
      expenses: json['expenses'] != null
          ? (json['expenses'] as List).map((e) => GroupExpenseModel.fromJson(e)).toList()
          : [],
    );
  }
}

class WalletModel {
  final String id;
  final String name;
  final String type;
  final String providerName;
  final String accountNumber;
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
    String rawType = json['type'] ?? 'Cash';
    if (rawType == 'Mobile') rawType = 'Mobile Banking';
    if (rawType == 'Bank') rawType = 'Bank Account';

    return WalletModel(
      id: json['id'],
      name: json['name'] ?? 'Account',
      type: rawType,
      providerName: json['providerName'] ?? (json['name'] ?? 'Cash'),
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
    'id': id,
    'title': title,
    'amount': amount,
    'dueDate': dueDate,
    'isExpense': isExpense,
  };

  factory ScheduledTxModel.fromJson(Map<String, dynamic> json) => ScheduledTxModel(
    id: json['id'],
    title: json['title'],
    amount: (json['amount'] as num).toDouble(),
    dueDate: json['dueDate'],
    isExpense: json['isExpense'] ?? true,
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
    id: json['id'],
    name: json['name'],
    price: (json['price'] as num).toDouble(),
    stock: json['stock'],
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
    'id': id,
    'name': name,
    'phone': phone,
    'isCustomer': isCustomer,
    'dueAmount': dueAmount,
  };

  factory PartyModel.fromJson(Map<String, dynamic> json) => PartyModel(
    id: json['id'],
    name: json['name'],
    phone: json['phone'] ?? '',
    isCustomer: json['isCustomer'],
    dueAmount: (json['dueAmount'] as num).toDouble(),
  );
}

class BusinessTxModel {
  final String id;
  final String title;
  final String type;
  final double amount;
  final String date;

  BusinessTxModel({required this.id, required this.title, required this.type, required this.amount, required this.date});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'type': type, 'amount': amount, 'date': date};

  factory BusinessTxModel.fromJson(Map<String, dynamic> json) => BusinessTxModel(
    id: json['id'],
    title: json['title'],
    type: json['type'],
    amount: (json['amount'] as num).toDouble(),
    date: json['date'],
  );
}

// =============================================================================
// UNIFIED PROVIDER (CLOUD DATABASE + MULTI-USER + RICH USER PROFILE)
// =============================================================================
class TransactionProvider with ChangeNotifier {
  // Personal State (100% Empty by default for new accounts)
  List<TransactionModel> _transactions = [];
  Map<String, double> _budgets = {};
  List<String> _expenseCategories = ['Food & Dining', 'Transportation', 'Shopping', 'Entertainment'];
  List<String> _incomeCategories = ['Salary', 'Freelance / Projects', 'Investments', 'Gifts'];
  List<GroupModel> _groups = [];
  List<String> _savedMembers = [];
  List<WalletModel> _wallets = [];
  List<ScheduledTxModel> _scheduledTxs = [];

  // Business State (100% Empty by default for new accounts)
  List<ProductModel> _products = [];
  List<PartyModel> _parties = [];
  List<BusinessTxModel> _businessTxs = [];

  // Rich User Profile State
  String _cloudEmail = '';
  String _userName = 'FinBlend User';
  String _userPhone = '';
  String _userDob = '';
  String _userGender = '';
  String _userOccupation = '';
  String _userOrganization = '';
  String _userAddress = '';
  String _userPhotoBase64 = '';
  String _passwordHash = '';

  // Appearance, Notifications & Permissions State
  bool _isDarkMode = true;
  bool _notificationsEnabled = true;
  bool _permissionsGranted = true;

  // Cloud Sync State
  String _customCloudUrl = '';
  bool _isSyncing = false;
  String _lastSyncedAt = 'Not synced yet';
  String _cloudStatus = 'Cloud Ready';
  int _lastUpdatedTimestamp = 0;
  Timer? _autoSyncTimer;

  TransactionProvider() {
    _loadData();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  // Getters
  List<TransactionModel> get transactions => _transactions.reversed.toList();
  Map<String, double> get budgets => _budgets;
  List<String> get expenseCategories => _expenseCategories;
  List<String> get incomeCategories => _incomeCategories;
  List<GroupModel> get groups => _groups;
  List<String> get savedMembers => _savedMembers;
  List<WalletModel> get wallets => _wallets;
  List<ScheduledTxModel> get scheduledTxs => _scheduledTxs;

  // User Profile Getters
  String get cloudEmail => _cloudEmail.isEmpty ? 'Not signed in' : _cloudEmail;
  String get userName => _userName;
  String get userPhone => _userPhone;
  String get userDob => _userDob;
  String get userGender => _userGender;
  String get userOccupation => _userOccupation;
  String get userOrganization => _userOrganization;
  String get userAddress => _userAddress;
  String get userPhotoBase64 => _userPhotoBase64;

  bool get isDarkMode => _isDarkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get permissionsGranted => _permissionsGranted;

  String get customCloudUrl => _customCloudUrl;
  bool get isSyncing => _isSyncing;
  String get lastSyncedAt => _lastSyncedAt;
  String get cloudStatus => _cloudStatus;

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

  String _getCloudChannelKey(String email) {
    final clean = email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'finblend_cloud_db_v3_$clean';
  }

  String _hashPassword(String password) {
    return base64Encode(utf8.encode('fb_salt_${password.trim()}'));
  }

  // Completely empty state for new user accounts
  void _resetToCleanAccount() {
    _transactions = [];
    _budgets = {};
    _expenseCategories = ['Food & Dining', 'Transportation', 'Shopping', 'Entertainment'];
    _incomeCategories = ['Salary', 'Freelance / Projects', 'Investments', 'Gifts'];
    _groups = [];
    _savedMembers = [];
    _wallets = [];
    _scheduledTxs = [];
    _products = [];
    _parties = [];
    _businessTxs = [];
    _userPhone = '';
    _userDob = '';
    _userGender = '';
    _userOccupation = '';
    _userOrganization = '';
    _userAddress = '';
    _userPhotoBase64 = '';
    _lastUpdatedTimestamp = DateTime.now().millisecondsSinceEpoch;
  }

  Map<String, dynamic> exportFullStateMap() {
    if (_lastUpdatedTimestamp == 0) {
      _lastUpdatedTimestamp = DateTime.now().millisecondsSinceEpoch;
    }
    return {
      'updatedAt': _lastUpdatedTimestamp,
      'email': _cloudEmail,
      'userName': _userName,
      'userPhone': _userPhone,
      'userDob': _userDob,
      'userGender': _userGender,
      'userOccupation': _userOccupation,
      'userOrganization': _userOrganization,
      'userAddress': _userAddress,
      'userPhotoBase64': _userPhotoBase64,
      'passwordHash': _passwordHash,
      'tx_data': _transactions.map((t) => t.toJson()).toList(),
      'bdg_data': _budgets,
      'exp_cat_data': _expenseCategories,
      'inc_cat_data': _incomeCategories,
      'grp_data': _groups.map((g) => g.toJson()).toList(),
      'saved_members_data': _savedMembers,
      'wal_data': _wallets.map((w) => w.toJson()).toList(),
      'sch_data': _scheduledTxs.map((s) => s.toJson()).toList(),
      'biz_prod_data': _products.map((p) => p.toJson()).toList(),
      'biz_party_data': _parties.map((p) => p.toJson()).toList(),
      'biz_tx_data': _businessTxs.map((t) => t.toJson()).toList(),
      'pref_dark_mode': _isDarkMode,
    };
  }

  void _applyStateMap(Map<String, dynamic> map) {
    _lastUpdatedTimestamp = (map['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    if (map['userName'] != null) _userName = map['userName'].toString();
    if (map['userPhone'] != null) _userPhone = map['userPhone'].toString();
    if (map['userDob'] != null) _userDob = map['userDob'].toString();
    if (map['userGender'] != null) _userGender = map['userGender'].toString();
    if (map['userOccupation'] != null) _userOccupation = map['userOccupation'].toString();
    if (map['userOrganization'] != null) _userOrganization = map['userOrganization'].toString();
    if (map['userAddress'] != null) _userAddress = map['userAddress'].toString();
    if (map['userPhotoBase64'] != null) _userPhotoBase64 = map['userPhotoBase64'].toString();
    if (map['passwordHash'] != null && map['passwordHash'].toString().isNotEmpty) {
      _passwordHash = map['passwordHash'].toString();
    }
    if (map['tx_data'] != null) {
      _transactions = (map['tx_data'] as List).map((i) => TransactionModel.fromJson(Map<String, dynamic>.from(i))).toList();
    }
    if (map['bdg_data'] != null) {
      _budgets = Map<String, double>.from((map['bdg_data'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())));
    }
    if (map['exp_cat_data'] != null) _expenseCategories = List<String>.from(map['exp_cat_data']);
    if (map['inc_cat_data'] != null) _incomeCategories = List<String>.from(map['inc_cat_data']);
    if (map['grp_data'] != null) {
      _groups = (map['grp_data'] as List).map((i) => GroupModel.fromJson(Map<String, dynamic>.from(i))).toList();
    }
    if (map['saved_members_data'] != null) _savedMembers = List<String>.from(map['saved_members_data']);
    if (map['wal_data'] != null) {
      _wallets = (map['wal_data'] as List).map((i) => WalletModel.fromJson(Map<String, dynamic>.from(i))).toList();
    }
    if (map['sch_data'] != null) {
      _scheduledTxs = (map['sch_data'] as List).map((i) => ScheduledTxModel.fromJson(Map<String, dynamic>.from(i))).toList();
    }
    if (map['biz_prod_data'] != null) {
      _products = (map['biz_prod_data'] as List).map((i) => ProductModel.fromJson(Map<String, dynamic>.from(i))).toList();
    }
    if (map['biz_party_data'] != null) {
      _parties = (map['biz_party_data'] as List).map((i) => PartyModel.fromJson(Map<String, dynamic>.from(i))).toList();
    }
    if (map['biz_tx_data'] != null) {
      _businessTxs = (map['biz_tx_data'] as List).map((i) => BusinessTxModel.fromJson(Map<String, dynamic>.from(i))).toList();
    }
    if (map['pref_dark_mode'] != null) _isDarkMode = map['pref_dark_mode'] as bool;
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customCloudUrl = prefs.getString('custom_cloud_url') ?? '';
      _lastSyncedAt = prefs.getString('last_synced_at') ?? 'Not synced yet';
      if (prefs.containsKey('pref_dark_mode')) _isDarkMode = prefs.getBool('pref_dark_mode') ?? true;
      if (prefs.containsKey('pref_notif')) _notificationsEnabled = prefs.getBool('pref_notif') ?? true;
      if (prefs.containsKey('pref_perm')) _permissionsGranted = prefs.getBool('pref_perm') ?? true;

      final isLogged = prefs.getBool('is_logged_in') ?? false;
      _cloudEmail = (prefs.getString('user_email') ?? '').trim().toLowerCase();
      _userName = prefs.getString('user_name') ?? 'FinBlend User';

      if (isLogged && _cloudEmail.isNotEmpty) {
        final localKey = 'account_cache_${_getCloudChannelKey(_cloudEmail)}';
        if (prefs.containsKey(localKey)) {
          final cachedMap = jsonDecode(prefs.getString(localKey)!) as Map<String, dynamic>;
          _applyStateMap(cachedMap);
        }
        _startAutoSyncTimer();
        unawaited(pullFromCloud(silent: true));
      }
    } catch (e) {
      debugPrint("Data load error: $e");
    }
    notifyListeners();
  }

  void _startAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_cloudEmail.isNotEmpty && !_isSyncing) {
        pullFromCloud(silent: true);
      }
    });
  }

  Future<void> _saveData({bool syncCloud = true}) async {
    _lastUpdatedTimestamp = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('pref_dark_mode', _isDarkMode);
    await prefs.setBool('pref_notif', _notificationsEnabled);
    await prefs.setBool('pref_perm', _permissionsGranted);
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _cloudEmail);

    if (_cloudEmail.isNotEmpty) {
      final localKey = 'account_cache_${_getCloudChannelKey(_cloudEmail)}';
      await prefs.setString(localKey, jsonEncode(exportFullStateMap()));
    }

    if (syncCloud && _cloudEmail.isNotEmpty) {
      unawaited(pushToCloud(silent: true));
    }
  }

  // --- UPDATE RICH USER PROFILE ---
  Future<void> updateUserProfile({
    required String name,
    required String email,
    required String phone,
    required String dob,
    required String gender,
    required String occupation,
    required String organization,
    required String address,
    required String photoBase64,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    _userName = name.trim();
    if (cleanEmail.isNotEmpty) {
      _cloudEmail = cleanEmail;
    }
    _userPhone = phone.trim();
    _userDob = dob.trim();
    _userGender = gender.trim();
    _userOccupation = occupation.trim();
    _userOrganization = organization.trim();
    _userAddress = address.trim();
    _userPhotoBase64 = photoBase64;

    await _saveData(syncCloud: true);
    notifyListeners();
  }

  // --- CLOUD ACCOUNT AUTHENTICATION ---
  Future<Map<String, dynamic>> authenticateCloudAccount({
    required String name,
    required String email,
    required String password,
    required bool isSignUp,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final passHash = _hashPassword(password);
    _isSyncing = true;
    _cloudStatus = 'Connecting to Cloud...';
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final remoteMap = await _fetchRemoteCloudMap(cleanEmail);

    if (isSignUp) {
      if (remoteMap != null &&
          remoteMap['passwordHash'] != null &&
          remoteMap['passwordHash'].toString().isNotEmpty &&
          remoteMap['passwordHash'] != passHash) {
        _isSyncing = false;
        _cloudStatus = 'Account exists';
        notifyListeners();
        return {
          'success': false,
          'message': 'An account with this email already exists in the Cloud. Please Sign In instead.',
        };
      }

      // Start 100% clean & empty for a new signup
      _resetToCleanAccount();
      _cloudEmail = cleanEmail;
      _userName = name.trim().isEmpty ? cleanEmail.split('@').first : name.trim();
      _passwordHash = passHash;

      // Clear any legacy shared_preferences keys on this device so nothing leaks into the new account
      await prefs.remove('tx_data');
      await prefs.remove('bdg_data');
      await prefs.remove('grp_data');
      await prefs.remove('saved_members_data');
      await prefs.remove('wal_data');
      await prefs.remove('sch_data');
      await prefs.remove('biz_prod_data');
      await prefs.remove('biz_party_data');
      await prefs.remove('biz_tx_data');

      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_name', _userName);
      await prefs.setString('user_email', _cloudEmail);

      await _saveData(syncCloud: false);
      await pushToCloud(silent: false);
      _startAutoSyncTimer();

      return {'success': true, 'message': 'Clean Cloud account created and synced!'};
    } else {
      if (remoteMap != null) {
        final cloudPassHash = remoteMap['passwordHash']?.toString() ?? '';
        if (cloudPassHash.isNotEmpty && cloudPassHash != passHash) {
          _isSyncing = false;
          _cloudStatus = 'Auth Failed';
          notifyListeners();
          return {
            'success': false,
            'message': 'Incorrect password for this Cloud account.',
          };
        }

        _resetToCleanAccount();
        _cloudEmail = cleanEmail;
        _passwordHash = passHash;
        _applyStateMap(remoteMap);
        if (_passwordHash.isEmpty) _passwordHash = passHash;

        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_name', _userName);
        await prefs.setString('user_email', _cloudEmail);

        await _saveData(syncCloud: false);
        _lastSyncedAt = _generateTimestamp();
        _cloudStatus = 'Synced with Cloud ✓';
        _isSyncing = false;
        _startAutoSyncTimer();
        notifyListeners();

        return {'success': true, 'message': 'Signed in and loaded your Cloud account!'};
      } else {
        final localKey = 'account_cache_${_getCloudChannelKey(cleanEmail)}';
        if (prefs.containsKey(localKey)) {
          final cachedMap = jsonDecode(prefs.getString(localKey)!) as Map<String, dynamic>;
          final cachedPass = cachedMap['passwordHash']?.toString() ?? '';
          if (cachedPass.isNotEmpty && cachedPass != passHash) {
            _isSyncing = false;
            notifyListeners();
            return {'success': false, 'message': 'Incorrect password.'};
          }
          _resetToCleanAccount();
          _cloudEmail = cleanEmail;
          _passwordHash = passHash;
          _applyStateMap(cachedMap);
        } else {
          _resetToCleanAccount();
          _cloudEmail = cleanEmail;
          _userName = name.trim().isEmpty ? cleanEmail.split('@').first : name.trim();
          _passwordHash = passHash;
        }

        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_name', _userName);
        await prefs.setString('user_email', _cloudEmail);

        await _saveData(syncCloud: false);
        await pushToCloud(silent: false);
        _startAutoSyncTimer();

        return {'success': true, 'message': 'Signed in and synced to Cloud!'};
      }
    }
  }

  Future<void> clearSessionOnLogout() async {
    _autoSyncTimer?.cancel();
    if (_cloudEmail.isNotEmpty) {
      await pushToCloud(silent: true);
    }
    _cloudEmail = '';
    _userName = 'FinBlend User';
    _passwordHash = '';
    _resetToCleanAccount();
    notifyListeners();
  }

  Future<void> setCustomCloudUrl(String url) async {
    _customCloudUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_cloud_url', _customCloudUrl);
    notifyListeners();
    if (_cloudEmail.isNotEmpty) {
      await pushToCloud();
    }
  }

  Future<void> syncOnLogin(String email) async {
    _cloudEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', _cloudEmail);
    _startAutoSyncTimer();
    final pulled = await pullFromCloud(silent: false, forceApply: true);
    if (!pulled) {
      await pushToCloud(silent: false);
    }
  }

  Future<Map<String, dynamic>?> _fetchRemoteCloudMap(String email) async {
    try {
      final channel = _getCloudChannelKey(email);
      String? base64Payload;

      if (_customCloudUrl.isNotEmpty && _customCloudUrl.startsWith('http')) {
        final cleanBase = _customCloudUrl.endsWith('/') ? _customCloudUrl.substring(0, _customCloudUrl.length - 1) : _customCloudUrl;
        final res = await http.get(Uri.parse('$cleanBase/finblend_users/$channel.json')).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
          final data = jsonDecode(res.body);
          if (data is Map && data['payload'] != null) {
            base64Payload = data['payload'].toString();
          }
        }
      } else {
        final res = await http
            .get(Uri.parse('https://ntfy.sh/$channel/json?poll=1&since=all'))
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
          final lines = res.body.trim().split('\n');
          Map<String, dynamic>? latestMsg;

          for (var line in lines) {
            if (line.trim().isEmpty) continue;
            final decodedLine = jsonDecode(line);
            if (decodedLine is Map<String, dynamic> && decodedLine['event'] == 'message') {
              latestMsg = decodedLine;
            }
          }

          if (latestMsg != null) {
            if (latestMsg['attachment'] != null && latestMsg['attachment']['url'] != null) {
              final attRes = await http
                  .get(Uri.parse(latestMsg['attachment']['url'].toString()))
                  .timeout(const Duration(seconds: 10));
              if (attRes.statusCode == 200) {
                base64Payload = attRes.body.trim();
              }
            } else if (latestMsg['message'] != null) {
              base64Payload = latestMsg['message'].toString().trim();
            }
          }
        }
      }

      if (base64Payload != null && base64Payload.isNotEmpty) {
        final decodedJsonStr = utf8.decode(base64Decode(base64Payload));
        return jsonDecode(decodedJsonStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Cloud fetch error: $e');
    }
    return null;
  }

  Future<bool> pushToCloud({bool silent = false}) async {
    if (_cloudEmail.isEmpty) return false;
    _isSyncing = true;
    _cloudStatus = 'Syncing to Cloud...';
    if (!silent) notifyListeners();

    try {
      final channel = _getCloudChannelKey(_cloudEmail);
      final stateJson = jsonEncode(exportFullStateMap());
      final base64Payload = base64Encode(utf8.encode(stateJson));

      bool success = false;

      if (_customCloudUrl.isNotEmpty && _customCloudUrl.startsWith('http')) {
        final cleanBase = _customCloudUrl.endsWith('/') ? _customCloudUrl.substring(0, _customCloudUrl.length - 1) : _customCloudUrl;
        final res = await http
            .put(
          Uri.parse('$cleanBase/finblend_users/$channel.json'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'payload': base64Payload,
            'updatedAt': _lastUpdatedTimestamp,
            'email': _cloudEmail,
          }),
        )
            .timeout(const Duration(seconds: 10));
        success = res.statusCode >= 200 && res.statusCode < 300;
      } else {
        final res = await http
            .post(
          Uri.parse('https://ntfy.sh/$channel'),
          body: base64Payload,
        )
            .timeout(const Duration(seconds: 10));
        success = res.statusCode >= 200 && res.statusCode < 300;
      }

      if (success) {
        _lastSyncedAt = _generateTimestamp();
        _cloudStatus = 'Synced to Cloud ✓';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_synced_at', _lastSyncedAt);
      } else {
        _cloudStatus = 'Offline (Saved Locally)';
      }
      _isSyncing = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isSyncing = false;
      _cloudStatus = 'Offline Mode (Local Saved)';
      notifyListeners();
      return false;
    }
  }

  Future<bool> pullFromCloud({bool silent = false, bool forceApply = false}) async {
    if (_cloudEmail.isEmpty) return false;
    if (!silent) {
      _isSyncing = true;
      _cloudStatus = 'Checking Cloud...';
      notifyListeners();
    }

    try {
      final remoteMap = await _fetchRemoteCloudMap(_cloudEmail);
      if (remoteMap != null) {
        final remoteTime = (remoteMap['updatedAt'] as num?)?.toInt() ?? 0;

        if (forceApply || remoteTime >= _lastUpdatedTimestamp || _transactions.isEmpty) {
          final changed = remoteTime != _lastUpdatedTimestamp || forceApply;
          _applyStateMap(remoteMap);

          final prefs = await SharedPreferences.getInstance();
          final localKey = 'account_cache_${_getCloudChannelKey(_cloudEmail)}';
          await prefs.setString(localKey, jsonEncode(exportFullStateMap()));
          if (_userName.isNotEmpty) {
            await prefs.setString('user_name', _userName);
          }

          _lastSyncedAt = _generateTimestamp();
          _cloudStatus = 'Synced with Cloud ✓';
          await prefs.setString('last_synced_at', _lastSyncedAt);
          _isSyncing = false;
          if (changed || !silent) notifyListeners();
          return true;
        }
      }

      _isSyncing = false;
      _cloudStatus = 'Synced with Cloud ✓';
      if (!silent) notifyListeners();
      return false;
    } catch (e) {
      _isSyncing = false;
      _cloudStatus = 'Offline Mode';
      if (!silent) notifyListeners();
      return false;
    }
  }

  Future<bool> importFromSyncCode(String base64Code) async {
    try {
      final decodedJsonStr = utf8.decode(base64Decode(base64Code.trim()));
      final decodedMap = jsonDecode(decodedJsonStr) as Map<String, dynamic>;
      _applyStateMap(decodedMap);
      await _saveData(syncCloud: true);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  String generateSyncCode() {
    return base64Encode(utf8.encode(jsonEncode(exportFullStateMap())));
  }

  // --- SAVED MEMBERS DIRECTORY CRUD ---
  void addSavedMember(String name) {
    final clean = name.trim();
    if (clean.isNotEmpty && !_savedMembers.any((m) => m.toLowerCase() == clean.toLowerCase())) {
      _savedMembers.add(clean);
      _saveData();
      notifyListeners();
    }
  }

  void updateSavedMember(String oldName, String newName) {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    final idx = _savedMembers.indexOf(oldName);
    if (idx != -1) {
      _savedMembers[idx] = clean;
      _saveData();
      notifyListeners();
    }
  }

  void deleteSavedMember(String name) {
    _savedMembers.remove(name);
    _saveData();
    notifyListeners();
  }

  // --- PERSONAL CRUD ---
  void saveTransaction({String? id, required String title, required String category, required double amount, required bool isExpense}) {
    final newTx = TransactionModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      subtitle: category,
      amount: amount,
      isExpense: isExpense,
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

  // --- ADVANCED GROUP & TRIP SPLIT CRUD ---
  void saveGroupPlan({
    String? id,
    required String name,
    required double totalBudget,
    List<GroupMemberModel>? updatedMembers,
  }) {
    if (updatedMembers != null) {
      for (var m in updatedMembers) {
        if (m.name.trim().isNotEmpty && !_savedMembers.any((s) => s.toLowerCase() == m.name.trim().toLowerCase())) {
          _savedMembers.add(m.name.trim());
        }
      }
    }

    if (id == null) {
      _groups.add(
        GroupModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          totalBudget: totalBudget,
          createdAt: _generateTimestamp(),
          members: updatedMembers ?? [],
          expenses: [],
        ),
      );
    } else {
      final index = _groups.indexWhere((g) => g.id == id);
      if (index != -1) {
        final existing = _groups[index];
        _groups[index] = GroupModel(
          id: existing.id,
          name: name,
          totalBudget: totalBudget,
          createdAt: existing.createdAt,
          members: updatedMembers ?? existing.members,
          expenses: existing.expenses,
        );
      }
    }
    _saveData();
    notifyListeners();
  }

  void deleteGroup(String id) {
    _groups.removeWhere((g) => g.id == id);
    _saveData();
    notifyListeners();
  }

  void saveGroupMember({
    required String groupId,
    String? memberId,
    required String name,
    required double paidAmount,
  }) {
    final gIdx = _groups.indexWhere((g) => g.id == groupId);
    if (gIdx == -1) return;

    final cleanName = name.trim();
    if (cleanName.isNotEmpty && !_savedMembers.any((s) => s.toLowerCase() == cleanName.toLowerCase())) {
      _savedMembers.add(cleanName);
    }

    final group = _groups[gIdx];
    final updatedMembers = List<GroupMemberModel>.from(group.members);

    if (memberId == null) {
      updatedMembers.add(
        GroupMemberModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: cleanName,
          paidAmount: paidAmount,
        ),
      );
    } else {
      final mIdx = updatedMembers.indexWhere((m) => m.id == memberId);
      if (mIdx != -1) {
        updatedMembers[mIdx] = GroupMemberModel(
          id: memberId,
          name: cleanName,
          paidAmount: paidAmount,
        );
      }
    }

    _groups[gIdx] = GroupModel(
      id: group.id,
      name: group.name,
      totalBudget: group.totalBudget,
      createdAt: group.createdAt,
      members: updatedMembers,
      expenses: group.expenses,
    );
    _saveData();
    notifyListeners();
  }

  void deleteGroupMember({required String groupId, required String memberId}) {
    final gIdx = _groups.indexWhere((g) => g.id == groupId);
    if (gIdx == -1) return;

    final group = _groups[gIdx];
    final updatedMembers = group.members.where((m) => m.id != memberId).toList();

    _groups[gIdx] = GroupModel(
      id: group.id,
      name: group.name,
      totalBudget: group.totalBudget,
      createdAt: group.createdAt,
      members: updatedMembers,
      expenses: group.expenses,
    );
    _saveData();
    notifyListeners();
  }

  void saveGroupExpense({
    required String groupId,
    String? expenseId,
    required String title,
    required double amount,
    required String paidByMemberId,
    required String paidByMemberName,
    bool creditMemberPaidAmount = false,
  }) {
    final gIdx = _groups.indexWhere((g) => g.id == groupId);
    if (gIdx == -1) return;

    final group = _groups[gIdx];
    final updatedExpenses = List<GroupExpenseModel>.from(group.expenses);
    final updatedMembers = List<GroupMemberModel>.from(group.members);

    if (expenseId == null) {
      updatedExpenses.insert(
        0,
        GroupExpenseModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          amount: amount,
          paidByMemberId: paidByMemberId,
          paidByMemberName: paidByMemberName,
          date: _generateTimestamp(),
        ),
      );

      if (creditMemberPaidAmount && paidByMemberId != 'pool') {
        final mIdx = updatedMembers.indexWhere((m) => m.id == paidByMemberId);
        if (mIdx != -1) {
          final m = updatedMembers[mIdx];
          updatedMembers[mIdx] = GroupMemberModel(
            id: m.id,
            name: m.name,
            paidAmount: m.paidAmount + amount,
          );
        }
      }
    } else {
      final eIdx = updatedExpenses.indexWhere((e) => e.id == expenseId);
      if (eIdx != -1) {
        updatedExpenses[eIdx] = GroupExpenseModel(
          id: expenseId,
          title: title,
          amount: amount,
          paidByMemberId: paidByMemberId,
          paidByMemberName: paidByMemberName,
          date: _generateTimestamp(),
        );
      }
    }

    _groups[gIdx] = GroupModel(
      id: group.id,
      name: group.name,
      totalBudget: group.totalBudget,
      createdAt: group.createdAt,
      members: updatedMembers,
      expenses: updatedExpenses,
    );
    _saveData();
    notifyListeners();
  }

  void deleteGroupExpense({required String groupId, required String expenseId}) {
    final gIdx = _groups.indexWhere((g) => g.id == groupId);
    if (gIdx == -1) return;

    final group = _groups[gIdx];
    final updatedExpenses = group.expenses.where((e) => e.id != expenseId).toList();

    _groups[gIdx] = GroupModel(
      id: group.id,
      name: group.name,
      totalBudget: group.totalBudget,
      createdAt: group.createdAt,
      members: group.members,
      expenses: updatedExpenses,
    );
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
      title: title,
      amount: amount,
      dueDate: dueDate,
      isExpense: isExpense,
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
      title: title,
      type: type,
      amount: amount,
      date: _generateTimestamp(),
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
      name: name,
      phone: phone,
      isCustomer: isCustomer,
      dueAmount: dueAmount,
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

  // --- APPEARANCE, NOTIFICATIONS & PERMISSIONS ---
  void toggleDarkMode(bool isDark) {
    _isDarkMode = isDark;
    _saveData();
    notifyListeners();
  }

  void toggleNotifications(bool enabled) {
    _notificationsEnabled = enabled;
    _saveData();
    notifyListeners();
  }

  void updatePermissions(bool granted) {
    _permissionsGranted = granted;
    _saveData();
    notifyListeners();
  }

  List<Map<String, dynamic>> get activeAlerts {
    if (!_notificationsEnabled) return [];
    final List<Map<String, dynamic>> alerts = [];

    Map<String, double> spentByCat = {};
    for (var tx in _transactions.where((t) => t.isExpense)) {
      spentByCat[tx.title] = (spentByCat[tx.title] ?? 0) + tx.amount;
    }
    _budgets.forEach((cat, limit) {
      final spent = spentByCat[cat] ?? 0;
      if (limit > 0 && spent >= limit * 0.85) {
        alerts.add({
          'title': spent >= limit ? 'Budget Exceeded: $cat' : 'Budget Warning: $cat',
          'body': 'Spent ৳${spent.toStringAsFixed(0)} of ৳${limit.toStringAsFixed(0)} (${((spent / limit) * 100).toStringAsFixed(0)}%)',
          'color': 0xFFFF5252,
        });
      }
    });

    for (var g in _groups) {
      if (g.totalOwedToBudget > 0) {
        alerts.add({
          'title': 'Group Collection Pending: ${g.name}',
          'body': 'Members still owe ৳${g.totalOwedToBudget.toStringAsFixed(0)} toward the ৳${g.totalBudget.toStringAsFixed(0)} budget.',
          'color': 0xFFFFAB40,
        });
      }
    }

    for (var s in _scheduledTxs) {
      alerts.add({
        'title': 'Scheduled Bill Reminder: ${s.title}',
        'body': '৳${s.amount.toStringAsFixed(0)} due on ${s.dueDate}',
        'color': 0xFF64FFDA,
      });
    }

    for (var p in _products.where((p) => p.stock <= 5)) {
      alerts.add({
        'title': 'Low Stock Alert: ${p.name}',
        'body': 'Only ${p.stock} units remaining in Business Inventory.',
        'color': 0xFFFF5252,
      });
    }

    return alerts;
  }
}