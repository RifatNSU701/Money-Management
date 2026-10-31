import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// PERSONAL & WALLET MODELS (WITH PDF / IMAGE RECEIPT ATTACHMENTS)
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
  final String attachmentBase64;
  final String attachmentName;

  TransactionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isExpense,
    required this.date,
    required this.iconCode,
    required this.colorValue,
    this.attachmentBase64 = '',
    this.attachmentName = '',
  });

  bool get hasAttachment => attachmentBase64.isNotEmpty;
  IconData get icon => isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
  Color get color => Color(colorValue);

  Map toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'amount': amount,
    'isExpense': isExpense,
    'date': date,
    'iconCode': iconCode,
    'colorValue': colorValue,
    'attachmentBase64': attachmentBase64,
    'attachmentName': attachmentName,
  };

  factory TransactionModel.fromJson(Map json) => TransactionModel(
    id: json['id'].toString(),
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString() ?? '',
    amount: ((json['amount'] ?? 0) as num).toDouble(),
    isExpense: json['isExpense'] == true,
    date: json['date']?.toString() ?? '',
    iconCode: ((json['iconCode'] ?? 0) as num).toInt(),
    colorValue: ((json['colorValue'] ?? 0xFF10B981) as num).toInt(),
    attachmentBase64: json['attachmentBase64']?.toString() ?? '',
    attachmentName: json['attachmentName']?.toString() ?? '',
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

  Map toJson() => {
    'id': id,
    'name': name,
    'paidAmount': paidAmount,
  };

  factory GroupMemberModel.fromJson(Map json) => GroupMemberModel(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    paidAmount: ((json['paidAmount'] ?? 0) as num).toDouble(),
  );
}

class GroupExpenseModel {
  final String id;
  final String title;
  final double amount;
  final String paidByMemberId;
  final String paidByMemberName;
  final String date;
  final String attachmentBase64;
  final String attachmentName;

  GroupExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidByMemberId,
    required this.paidByMemberName,
    required this.date,
    this.attachmentBase64 = '',
    this.attachmentName = '',
  });

  bool get hasAttachment => attachmentBase64.isNotEmpty;

  Map toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'paidByMemberId': paidByMemberId,
    'paidByMemberName': paidByMemberName,
    'date': date,
    'attachmentBase64': attachmentBase64,
    'attachmentName': attachmentName,
  };

  factory GroupExpenseModel.fromJson(Map json) => GroupExpenseModel(
    id: json['id'].toString(),
    title: json['title']?.toString() ?? '',
    amount: ((json['amount'] ?? 0) as num).toDouble(),
    paidByMemberId: json['paidByMemberId']?.toString() ?? 'pool',
    paidByMemberName: json['paidByMemberName']?.toString() ?? 'Group Pool',
    date: json['date']?.toString() ?? '',
    attachmentBase64: json['attachmentBase64']?.toString() ?? '',
    attachmentName: json['attachmentName']?.toString() ?? '',
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

  Map toJson() => {
    'id': id,
    'name': name,
    'totalBudget': totalBudget,
    'createdAt': createdAt,
    'members': members.map((m) => m.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
  };

  factory GroupModel.fromJson(Map json) {
    return GroupModel(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Group Plan',
      totalBudget: ((json['totalBudget'] ?? json['amount'] ?? 0) as num).toDouble(),
      createdAt: json['createdAt']?.toString() ?? 'Active Plan',
      members: json['members'] != null
          ? (json['members'] as List).map((m) => GroupMemberModel.fromJson(Map.from(m as Map))).toList()
          : [],
      expenses: json['expenses'] != null
          ? (json['expenses'] as List).map((e) => GroupExpenseModel.fromJson(Map.from(e as Map))).toList()
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

  Map toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'providerName': providerName,
    'accountNumber': accountNumber,
    'balance': balance,
  };

  factory WalletModel.fromJson(Map json) {
    String rawType = json['type']?.toString() ?? 'Cash';
    if (rawType == 'Mobile') rawType = 'Mobile Banking';
    if (rawType == 'Bank') rawType = 'Bank Account';

    return WalletModel(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Account',
      type: rawType,
      providerName: json['providerName']?.toString() ?? (json['name']?.toString() ?? 'Cash'),
      accountNumber: json['accountNumber']?.toString() ?? '',
      balance: ((json['balance'] ?? 0) as num).toDouble(),
    );
  }
}

class ScheduledTxModel {
  final String id;
  final String title;
  final double amount;
  final String dueDate;
  final bool isExpense;
  final String attachmentBase64;
  final String attachmentName;

  ScheduledTxModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.isExpense,
    this.attachmentBase64 = '',
    this.attachmentName = '',
  });

  bool get hasAttachment => attachmentBase64.isNotEmpty;

  Map toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'dueDate': dueDate,
    'isExpense': isExpense,
    'attachmentBase64': attachmentBase64,
    'attachmentName': attachmentName,
  };

  factory ScheduledTxModel.fromJson(Map json) => ScheduledTxModel(
    id: json['id'].toString(),
    title: json['title']?.toString() ?? '',
    amount: ((json['amount'] ?? 0) as num).toDouble(),
    dueDate: json['dueDate']?.toString() ?? '',
    isExpense: json['isExpense'] ?? true,
    attachmentBase64: json['attachmentBase64']?.toString() ?? '',
    attachmentName: json['attachmentName']?.toString() ?? '',
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

  Map toJson() => {'id': id, 'name': name, 'price': price, 'stock': stock};

  factory ProductModel.fromJson(Map json) => ProductModel(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    price: ((json['price'] ?? 0) as num).toDouble(),
    stock: ((json['stock'] ?? 0) as num).toInt(),
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

  Map toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'isCustomer': isCustomer,
    'dueAmount': dueAmount,
  };

  factory PartyModel.fromJson(Map json) => PartyModel(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    isCustomer: json['isCustomer'] ?? true,
    dueAmount: ((json['dueAmount'] ?? 0) as num).toDouble(),
  );
}

class BusinessTxModel {
  final String id;
  final String title;
  final String type;
  final double amount;
  final String date;
  final String attachmentBase64;
  final String attachmentName;

  BusinessTxModel({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.date,
    this.attachmentBase64 = '',
    this.attachmentName = '',
  });

  bool get hasAttachment => attachmentBase64.isNotEmpty;

  Map toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'amount': amount,
    'date': date,
    'attachmentBase64': attachmentBase64,
    'attachmentName': attachmentName,
  };

  factory BusinessTxModel.fromJson(Map json) => BusinessTxModel(
    id: json['id'].toString(),
    title: json['title']?.toString() ?? '',
    type: json['type']?.toString() ?? 'Sale',
    amount: ((json['amount'] ?? 0) as num).toDouble(),
    date: json['date']?.toString() ?? '',
    attachmentBase64: json['attachmentBase64']?.toString() ?? '',
    attachmentName: json['attachmentName']?.toString() ?? '',
  );
}

// =============================================================================
// UNIVERSAL RECEIPT / MEMO ATTACHMENT PICKER & VIEWER (PDF, JPG, JPEG, PNG)
// =============================================================================
class AttachmentHelper {
  static Future pickReceiptOrMemo(BuildContext context) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;
      final PlatformFile file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null) return null;

      final String ext = (file.extension ?? '').toLowerCase();
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final resized = decoded.width > 900 ? img.copyResize(decoded, width: 900) : decoded;
          bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 82));
        }
      }

      return {
        'base64': base64Encode(bytes),
        'name': file.name,
      };
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach file: $e')),
        );
      }
      return null;
    }
  }

  static void viewAttachment(BuildContext context, String base64Data, String fileName) {
    if (base64Data.isEmpty) return;
    final Uint8List bytes = base64Decode(base64Data);
    final bool isPdf = fileName.toLowerCase().endsWith('.pdf');

    if (isPdf) {
      Printing.sharePdf(bytes: bytes, filename: fileName.isEmpty ? 'Document.pdf' : fileName);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        fileName.isEmpty ? 'Attached Memo / Receipt' : fileName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: InteractiveViewer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Printing.sharePdf(
                      bytes: bytes,
                      filename: fileName.isEmpty ? 'Receipt.jpg' : fileName,
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download / Share Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// REUSABLE REALISTIC CHARTS FOR ALL SCREENS
// =============================================================================
class RealisticDonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final List<String> labels;
  final String centerTitle;
  final String centerValue;

  const RealisticDonutChart({
    super.key,
    required this.values,
    required this.colors,
    required this.labels,
    required this.centerTitle,
    required this.centerValue,
  });

  @override
  Widget build(BuildContext context) {
    final double total = values.fold(0, (s, v) => s + v);
    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(130, 130),
                painter: _DonutPainter(values: values, colors: colors),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(centerTitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(centerValue, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(values.length, (i) {
              final double pct = total > 0 ? (values[i] / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        labels[i],
                        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _DonutPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0, (s, v) => s + v);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 10;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;

    if (total == 0 || total.isNegative) {
      paint.color = const Color(0xFF334155);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (final i in Iterable.generate(values.length)) {
      if (values[i] == 0 || values[i].isNegative) continue;
      final double sweep = (values[i] / total) * 2 * math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep - 0.03, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =============================================================================
// UNIFIED PROVIDER (CLOUD DATABASE + BENGALI/ENGLISH + ATTACHMENTS)
// =============================================================================
class TransactionProvider with ChangeNotifier {
  List<TransactionModel> _transactions = [];
  Map<String, double> _budgets = {};
  List<String> _expenseCategories = ['Food & Dining', 'Transportation', 'Shopping', 'Utilities & Rent'];
  List<String> _incomeCategories = ['Monthly Salary', 'Freelance Revenue', 'Investments', 'Business Dividend'];
  List<GroupModel> _groups = [];
  List<String> _savedMembers = [];
  List<WalletModel> _wallets = [];
  List<ScheduledTxModel> _scheduledTxs = [];

  List<ProductModel> _products = [];
  List<PartyModel> _parties = [];
  List<BusinessTxModel> _businessTxs = [];

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

  bool _isDarkMode = true;
  String _language = 'en';
  bool _notificationsEnabled = true;
  bool _permissionsGranted = true;

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

  List<TransactionModel> get transactions => _transactions.reversed.toList();
  Map<String, double> get budgets => _budgets;
  List<String> get expenseCategories => _expenseCategories;
  List<String> get incomeCategories => _incomeCategories;
  List<GroupModel> get groups => _groups;
  List<String> get savedMembers => _savedMembers;
  List<WalletModel> get wallets => _wallets;
  List<ScheduledTxModel> get scheduledTxs => _scheduledTxs;

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
  String get language => _language;
  bool get isBengali => _language == 'bn';
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

  List<ProductModel> get products => _products;
  List<PartyModel> get parties => _parties;
  List<BusinessTxModel> get businessTxs => _businessTxs.reversed.toList();

  double get totalSales => _businessTxs.where((t) => t.type == 'Sale').fold(0, (s, t) => s + t.amount);
  double get totalPurchases => _businessTxs.where((t) => t.type == 'Purchase').fold(0, (s, t) => s + t.amount);
  double get totalBizExpenses => _businessTxs.where((t) => t.type == 'Expense').fold(0, (s, t) => s + t.amount);
  double get netProfit => totalSales - totalPurchases - totalBizExpenses;
  double get totalCustomerDue => _parties.where((p) => p.isCustomer).fold(0, (s, p) => s + p.dueAmount);
  int get totalCustomersCount => _parties.where((p) => p.isCustomer).length;
  int get lowStockCount => _products.where((p) => p.stock.clamp(0, 5) == p.stock).length;

  void setLanguage(String langCode) {
    _language = langCode;
    _saveData();
    notifyListeners();
  }

  void toggleLanguage() {
    _language = _language == 'en' ? 'bn' : 'en';
    _saveData();
    notifyListeners();
  }

  String tr(String enText, String bnText) {
    return _language == 'bn' ? bnText : enText;
  }

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

  void _resetToCleanAccount() {
    _transactions = [];
    _budgets = {};
    _expenseCategories = ['Food & Dining', 'Transportation', 'Shopping', 'Utilities & Rent'];
    _incomeCategories = ['Monthly Salary', 'Freelance Revenue', 'Investments', 'Business Dividend'];
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

  Map exportFullStateMap() {
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
      'language': _language,
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

  void _applyStateMap(Map map) {
    _lastUpdatedTimestamp = (map['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    if (map['userName'] != null) _userName = map['userName'].toString();
    if (map['userPhone'] != null) _userPhone = map['userPhone'].toString();
    if (map['userDob'] != null) _userDob = map['userDob'].toString();
    if (map['userGender'] != null) _userGender = map['userGender'].toString();
    if (map['userOccupation'] != null) _userOccupation = map['userOccupation'].toString();
    if (map['userOrganization'] != null) _userOrganization = map['userOrganization'].toString();
    if (map['userAddress'] != null) _userAddress = map['userAddress'].toString();
    if (map['userPhotoBase64'] != null) _userPhotoBase64 = map['userPhotoBase64'].toString();
    if (map['language'] != null) _language = map['language'].toString();
    if (map['passwordHash'] != null && map['passwordHash'].toString().isNotEmpty) {
      _passwordHash = map['passwordHash'].toString();
    }
    if (map['tx_data'] != null) {
      _transactions = (map['tx_data'] as List).map((i) => TransactionModel.fromJson(Map.from(i as Map))).toList();
    }
    if (map['bdg_data'] != null) {
      final rawBdg = Map.from(map['bdg_data'] as Map);
      _budgets = {};
      rawBdg.forEach((k, v) {
        _budgets[k.toString()] = (v as num).toDouble();
      });
    }
    if (map['exp_cat_data'] != null) _expenseCategories = List<String>.from(map['exp_cat_data'] as List);
    if (map['inc_cat_data'] != null) _incomeCategories = List<String>.from(map['inc_cat_data'] as List);
    if (map['grp_data'] != null) {
      _groups = (map['grp_data'] as List).map((i) => GroupModel.fromJson(Map.from(i as Map))).toList();
    }
    if (map['saved_members_data'] != null) _savedMembers = List<String>.from(map['saved_members_data'] as List);
    if (map['wal_data'] != null) {
      _wallets = (map['wal_data'] as List).map((i) => WalletModel.fromJson(Map.from(i as Map))).toList();
    }
    if (map['sch_data'] != null) {
      _scheduledTxs = (map['sch_data'] as List).map((i) => ScheduledTxModel.fromJson(Map.from(i as Map))).toList();
    }
    if (map['biz_prod_data'] != null) {
      _products = (map['biz_prod_data'] as List).map((i) => ProductModel.fromJson(Map.from(i as Map))).toList();
    }
    if (map['biz_party_data'] != null) {
      _parties = (map['biz_party_data'] as List).map((i) => PartyModel.fromJson(Map.from(i as Map))).toList();
    }
    if (map['biz_tx_data'] != null) {
      _businessTxs = (map['biz_tx_data'] as List).map((i) => BusinessTxModel.fromJson(Map.from(i as Map))).toList();
    }
    if (map['pref_dark_mode'] != null) _isDarkMode = map['pref_dark_mode'] as bool;
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customCloudUrl = prefs.getString('custom_cloud_url') ?? '';
      _lastSyncedAt = prefs.getString('last_synced_at') ?? 'Not synced yet';
      if (prefs.containsKey('pref_dark_mode')) _isDarkMode = prefs.getBool('pref_dark_mode') ?? true;
      if (prefs.containsKey('pref_lang')) _language = prefs.getString('pref_lang') ?? 'en';
      if (prefs.containsKey('pref_notif')) _notificationsEnabled = prefs.getBool('pref_notif') ?? true;
      if (prefs.containsKey('pref_perm')) _permissionsGranted = prefs.getBool('pref_perm') ?? true;

      final isLogged = prefs.getBool('is_logged_in') ?? false;
      _cloudEmail = (prefs.getString('user_email') ?? '').trim().toLowerCase();
      _userName = prefs.getString('user_name') ?? 'FinBlend User';

      if (isLogged && _cloudEmail.isNotEmpty) {
        final localKey = 'account_cache_${_getCloudChannelKey(_cloudEmail)}';
        if (prefs.containsKey(localKey)) {
          final cachedMap = jsonDecode(prefs.getString(localKey)!) as Map;
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
    await prefs.setString('pref_lang', _language);
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

  // ===========================================================================
  // PROFESSIONAL CLOUD REGISTRATION & AUTHENTICATION
  // ===========================================================================
  Future authenticateCloudAccount({
    required String name,
    required String email,
    required String password,
    required bool isSignUp,
    String phone = '',
    String occupation = '',
    String address = '',
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final passHash = _hashPassword(password);
    _isSyncing = true;
    _cloudStatus = tr('Connecting to Cloud...', 'ক্লাউডে সংযুক্ত হচ্ছে...');
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
          'message': tr(
            'An account with this email already exists in the Cloud. Please Sign In instead.',
            'এই ইমেইল দিয়ে ইতিমধ্যে একটি অ্যাকাউন্ট রয়েছে। অনুগ্রহ করে সাইন ইন করুন।',
          ),
        };
      }

      _resetToCleanAccount();
      _cloudEmail = cleanEmail;
      _userName = name.trim().isEmpty ? cleanEmail.split('@').first : name.trim();
      _userPhone = phone.trim();
      _userOccupation = occupation.trim();
      _userAddress = address.trim();
      _passwordHash = passHash;

      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_name', _userName);
      await prefs.setString('user_email', _cloudEmail);

      await _saveData(syncCloud: false);
      await pushToCloud(silent: false);
      _startAutoSyncTimer();

      return {
        'success': true,
        'message': tr('Account registered and synced to Cloud!', 'অ্যাকাউন্ট সফলভাবে তৈরি ও ক্লাউডে সিঙ্ক হয়েছে!'),
      };
    } else {
      if (remoteMap != null) {
        final cloudPassHash = remoteMap['passwordHash']?.toString() ?? '';
        if (cloudPassHash.isNotEmpty && cloudPassHash != passHash) {
          _isSyncing = false;
          _cloudStatus = 'Auth Failed';
          notifyListeners();
          return {
            'success': false,
            'message': tr('Incorrect password for this account.', 'ভুল পাসওয়ার্ড প্রদান করা হয়েছে।'),
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
        _cloudStatus = 'Synced ✓';
        _isSyncing = false;
        _startAutoSyncTimer();
        notifyListeners();

        return {'success': true, 'message': tr('Signed in successfully!', 'সফলভাবে সাইন ইন হয়েছে!')};
      } else {
        final localKey = 'account_cache_${_getCloudChannelKey(cleanEmail)}';
        if (prefs.containsKey(localKey)) {
          final cachedMap = jsonDecode(prefs.getString(localKey)!) as Map;
          final cachedPass = cachedMap['passwordHash']?.toString() ?? '';
          if (cachedPass.isNotEmpty && cachedPass != passHash) {
            _isSyncing = false;
            notifyListeners();
            return {'success': false, 'message': tr('Incorrect password.', 'ভুল পাসওয়ার্ড।')};
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

        return {'success': true, 'message': tr('Signed in and synced!', 'সাইন ইন ও সিঙ্ক সম্পন্ন হয়েছে!')};
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

  Future _fetchRemoteCloudMap(String email) async {
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
          Map? latestMsg;

          for (var line in lines) {
            if (line.trim().isEmpty) continue;
            final decodedLine = jsonDecode(line);
            if (decodedLine is Map && decodedLine['event'] == 'message') {
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
        return jsonDecode(decodedJsonStr) as Map;
      }
    } catch (e) {
      debugPrint('Cloud fetch error: $e');
    }
    return null;
  }

  Future<bool> pushToCloud({bool silent = false}) async {
    if (_cloudEmail.isEmpty) return false;
    _isSyncing = true;
    _cloudStatus = 'Syncing...';
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
        success = res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204;
      } else {
        final res = await http
            .post(
          Uri.parse('https://ntfy.sh/$channel'),
          body: base64Payload,
        )
            .timeout(const Duration(seconds: 10));
        success = res.statusCode == 200 || res.statusCode == 201;
      }

      if (success) {
        _lastSyncedAt = _generateTimestamp();
        _cloudStatus = 'Synced ✓';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_synced_at', _lastSyncedAt);
      } else {
        _cloudStatus = 'Saved Locally';
      }
      _isSyncing = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isSyncing = false;
      _cloudStatus = 'Local Mode';
      notifyListeners();
      return false;
    }
  }

  Future<bool> pullFromCloud({bool silent = false, bool forceApply = false}) async {
    if (_cloudEmail.isEmpty) return false;
    if (!silent) {
      _isSyncing = true;
      _cloudStatus = 'Checking...';
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
          _cloudStatus = 'Synced ✓';
          await prefs.setString('last_synced_at', _lastSyncedAt);
          _isSyncing = false;
          if (changed || !silent) notifyListeners();
          return true;
        }
      }

      _isSyncing = false;
      _cloudStatus = 'Synced ✓';
      if (!silent) notifyListeners();
      return false;
    } catch (e) {
      _isSyncing = false;
      _cloudStatus = 'Local Mode';
      if (!silent) notifyListeners();
      return false;
    }
  }

  Future<bool> importFromSyncCode(String base64Code) async {
    try {
      final decodedJsonStr = utf8.decode(base64Decode(base64Code.trim()));
      final decodedMap = jsonDecode(decodedJsonStr) as Map;
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
  void saveTransaction({
    String? id,
    required String title,
    required String category,
    required double amount,
    required bool isExpense,
    String attachmentBase64 = '',
    String attachmentName = '',
  }) {
    final newTx = TransactionModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      subtitle: category,
      amount: amount,
      isExpense: isExpense,
      date: _generateTimestamp(),
      iconCode: isExpense ? Icons.arrow_upward_rounded.codePoint : Icons.arrow_downward_rounded.codePoint,
      colorValue: isExpense ? 0xFFEF4444 : 0xFF10B981,
      attachmentBase64: attachmentBase64,
      attachmentName: attachmentName,
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
    String attachmentBase64 = '',
    String attachmentName = '',
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
          attachmentBase64: attachmentBase64,
          attachmentName: attachmentName,
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
          attachmentBase64: attachmentBase64,
          attachmentName: attachmentName,
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

  void saveScheduledTx({
    String? id,
    required String title,
    required double amount,
    required String dueDate,
    required bool isExpense,
    String attachmentBase64 = '',
    String attachmentName = '',
  }) {
    final newSch = ScheduledTxModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      dueDate: dueDate,
      isExpense: isExpense,
      attachmentBase64: attachmentBase64,
      attachmentName: attachmentName,
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
  void saveBusinessTx({
    String? id,
    required String title,
    required String type,
    required double amount,
    String attachmentBase64 = '',
    String attachmentName = '',
  }) {
    final newTx = BusinessTxModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      type: type,
      amount: amount,
      date: _generateTimestamp(),
      attachmentBase64: attachmentBase64,
      attachmentName: attachmentName,
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

  List get activeAlerts {
    if (!_notificationsEnabled) return [];
    final List alerts = [];

    final Map<String, double> spentByCat = {};
    for (var tx in _transactions.where((t) => t.isExpense)) {
      spentByCat[tx.title] = (spentByCat[tx.title] ?? 0) + tx.amount;
    }
    _budgets.forEach((cat, limit) {
      final spent = spentByCat[cat] ?? 0;
      if (limit > 0 && spent >= limit * 0.85) {
        alerts.add({
          'title': spent >= limit ? 'Budget Exceeded: $cat' : 'Budget Warning: $cat',
          'body': 'Spent ৳${spent.toStringAsFixed(0)} of ৳${limit.toStringAsFixed(0)} (${((spent / limit) * 100).toStringAsFixed(0)}%)',
          'color': 0xFFEF4444,
        });
      }
    });

    for (var g in _groups) {
      if (g.totalOwedToBudget > 0) {
        alerts.add({
          'title': 'Group Collection Pending: ${g.name}',
          'body': 'Members still owe ৳${g.totalOwedToBudget.toStringAsFixed(0)} toward the ৳${g.totalBudget.toStringAsFixed(0)} budget.',
          'color': 0xFFF59E0B,
        });
      }
    }

    for (var s in _scheduledTxs) {
      alerts.add({
        'title': 'Scheduled Bill Reminder: ${s.title}',
        'body': '৳${s.amount.toStringAsFixed(0)} due on ${s.dueDate}',
        'color': 0xFF0EA5E9,
      });
    }

    for (var p in _products.where((p) => p.stock.clamp(0, 5) == p.stock)) {
      alerts.add({
        'title': 'Low Stock Alert: ${p.name}',
        'body': 'Only ${p.stock} units remaining in Business Inventory.',
        'color': 0xFFEF4444,
      });
    }

    return alerts;
  }
}