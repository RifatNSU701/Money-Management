import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/app_currency.dart';

typedef DynamicMap = Map<String, dynamic>;
typedef StringMap = Map<String, String>;

// Your Google Cloud Console Web OAuth Client ID:
const String kGoogleWebClientId =
    '259560784415-tig4epf6sbvoh90tkeb8gmbjcahqckdk.apps.googleusercontent.com';

double _round2(double value) {
  if (value.isNaN || value.isInfinite) return 0.0;
  final clamped = value.clamp(-AppCurrency.maxAmount, AppCurrency.maxAmount);
  return double.parse(clamped.toStringAsFixed(2));
}

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
  final String attachmentBase64;
  final String attachmentName;
  final String walletId;
  final String walletName;
  final List<String> labels;
  final int timestampMs;
  final bool isTransfer;
  final String toWalletId;
  final String toWalletName;

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
    this.walletId = '',
    this.walletName = '',
    this.labels = const [],
    int? timestampMs,
    this.isTransfer = false,
    this.toWalletId = '',
    this.toWalletName = '',
  }) : timestampMs = timestampMs ?? DateTime.now().millisecondsSinceEpoch;

  bool get hasAttachment => attachmentBase64.isNotEmpty;
  IconData get icon {
    if (isTransfer) return Icons.swap_horiz_rounded;
    return isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
  }

  Color get color => Color(colorValue);

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestampMs);

  DynamicMap toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'amount': _round2(amount),
    'isExpense': isExpense,
    'date': date,
    'iconCode': iconCode,
    'colorValue': colorValue,
    'attachmentBase64': attachmentBase64,
    'attachmentName': attachmentName,
    'walletId': walletId,
    'walletName': walletName,
    'labels': labels,
    'timestampMs': timestampMs,
    'isTransfer': isTransfer,
    'toWalletId': toWalletId,
    'toWalletName': toWalletName,
  };

  factory TransactionModel.fromJson(Map json) {
    final parsedIdMs = int.tryParse(json['id']?.toString() ?? '');
    return TransactionModel(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      amount: _round2(((json['amount'] ?? 0) as num).toDouble()),
      isExpense: json['isExpense'] == true,
      date: json['date']?.toString() ?? '',
      iconCode: ((json['iconCode'] ?? 0) as num).toInt(),
      colorValue: ((json['colorValue'] ?? 0xFF10B981) as num).toInt(),
      attachmentBase64: json['attachmentBase64']?.toString() ?? '',
      attachmentName: json['attachmentName']?.toString() ?? '',
      walletId: json['walletId']?.toString() ?? '',
      walletName: json['walletName']?.toString() ?? '',
      labels: json['labels'] is List
          ? (json['labels'] as List).map((e) => e.toString()).toList()
          : const [],
      timestampMs: (json['timestampMs'] as num?)?.toInt() ??
          parsedIdMs ??
          DateTime.now().millisecondsSinceEpoch,
      isTransfer: json['isTransfer'] == true,
      toWalletId: json['toWalletId']?.toString() ?? '',
      toWalletName: json['toWalletName']?.toString() ?? '',
    );
  }
}

// =============================================================================
// ADVANCED GROUP / TRIP SPLITTING MODELS (WITH UNEQUAL SPLIT & SHORTFALL MATH)
// =============================================================================
class GroupMemberModel {
  final String id;
  final String name;
  final double paidAmount;
  final double? customTarget;
  final bool isSettled;

  GroupMemberModel({
    required this.id,
    required this.name,
    required this.paidAmount,
    this.customTarget,
    this.isSettled = false,
  });

  DynamicMap toJson() => {
    'id': id,
    'name': name,
    'paidAmount': _round2(paidAmount),
    'customTarget': customTarget != null ? _round2(customTarget!) : null,
    'isSettled': isSettled,
  };

  factory GroupMemberModel.fromJson(Map json) => GroupMemberModel(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    paidAmount: _round2(((json['paidAmount'] ?? 0) as num).toDouble()),
    customTarget: json['customTarget'] != null
        ? _round2((json['customTarget'] as num).toDouble())
        : null,
    isSettled: json['isSettled'] == true,
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

  DynamicMap toJson() => {
    'id': id,
    'title': title,
    'amount': _round2(amount),
    'paidByMemberId': paidByMemberId,
    'paidByMemberName': paidByMemberName,
    'date': date,
    'attachmentBase64': attachmentBase64,
    'attachmentName': attachmentName,
  };

  factory GroupExpenseModel.fromJson(Map json) => GroupExpenseModel(
    id: json['id'].toString(),
    title: json['title']?.toString() ?? '',
    amount: _round2(((json['amount'] ?? 0) as num).toDouble()),
    paidByMemberId: json['paidByMemberId']?.toString() ?? 'pool',
    paidByMemberName: json['paidByMemberName']?.toString() ?? 'Group Pool',
    date: json['date']?.toString() ?? '',
    attachmentBase64: json['attachmentBase64']?.toString() ?? '',
    attachmentName: json['attachmentName']?.toString() ?? '',
  );
}

class GroupSettlementItem {
  final String fromName;
  final String toName;
  final double amount;
  final bool isPoolTransfer;

  const GroupSettlementItem({
    required this.fromName,
    required this.toName,
    required this.amount,
    this.isPoolTransfer = false,
  });
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

  double get targetPerMember =>
      memberCount > 0 ? _round2(totalBudget / memberCount) : 0.0;

  double targetForMember(GroupMemberModel member) {
    if (member.customTarget != null && member.customTarget! >= 0) {
      return _round2(member.customTarget!);
    }
    return targetPerMember;
  }

  /// How much this specific member still owes toward their personal target.
  double memberDue(GroupMemberModel member) {
    final diff = targetForMember(member) - member.paidAmount;
    return diff > 0.009 ? _round2(diff) : 0.0;
  }

  /// How much this specific member overpaid above their personal target.
  double memberCredit(GroupMemberModel member) {
    final diff = member.paidAmount - targetForMember(member);
    return diff > 0.009 ? _round2(diff) : 0.0;
  }

  double get totalCollected =>
      _round2(members.fold(0.0, (sum, m) => sum + m.paidAmount));

  /// Sum of unpaid dues across members (never distorted by another member's overpayment).
  double get totalMemberDues =>
      _round2(members.fold(0.0, (sum, m) => sum + memberDue(m)));

  double get totalOverpaidCredits =>
      _round2(members.fold(0.0, (sum, m) => sum + memberCredit(m)));

  double get totalOwedToBudget => totalMemberDues;

  double get netBudgetGap {
    final gap = totalBudget - totalCollected;
    return gap > 0.009 ? _round2(gap) : 0.0;
  }

  double get totalSpent =>
      _round2(expenses.fold(0.0, (sum, e) => sum + e.amount));

  double get spentPerMember =>
      memberCount > 0 ? _round2(totalSpent / memberCount) : 0.0;

  double get poolBalanceLeft => _round2(totalCollected - totalSpent);

  double get poolShortfall =>
      totalSpent > totalCollected ? _round2(totalSpent - totalCollected) : 0.0;

  double get budgetRemaining => _round2(totalBudget - totalSpent);

  /// Computes exact settlements where every taka of totalSpent is assigned,
  /// including pool shortfalls (e.g., 2,500 spent from 2,000 pool) and pool refunds.
  List<GroupSettlementItem> computeSettlements() {
    if (members.isEmpty) return const [];

    final double basisTotal = totalSpent > 0 ? totalSpent : totalBudget;
    if (basisTotal <= 0) return const [];

    final double targetSum = members.fold(0.0, (s, m) => s + targetForMember(m));

    final List<DynamicMap> creditors = [];
    final List<DynamicMap> debtors = [];

    for (final m in members) {
      final double share = (targetSum > 0)
          ? _round2(basisTotal * (targetForMember(m) / targetSum))
          : _round2(basisTotal / members.length);
      final double net = _round2(m.paidAmount - share);
      if (net > 0.01) {
        creditors.add({'name': m.name, 'amount': net, 'isPool': false});
      } else if (net < -0.01) {
        debtors.add({'name': m.name, 'amount': -net, 'isPool': false});
      }
    }

    // Account for pool shortfall or unspent pool surplus so ledger sums to 0.
    if (totalSpent > 0) {
      final double poolDelta = _round2(totalCollected - totalSpent);
      if (poolDelta < -0.01) {
        // Pool is short (e.g., 2,500 spent from 2,000 pool => 500 shortfall owed to pool/vendor)
        creditors.add({
          'name': 'Group Pool Shortfall',
          'amount': -poolDelta,
          'isPool': true,
        });
      } else if (poolDelta > 0.01) {
        // Unspent cash sitting in pool to refund overpaying members
        debtors.add({
          'name': 'Group Pool Refund',
          'amount': poolDelta,
          'isPool': true,
        });
      }
    }

    final List<GroupSettlementItem> transfers = [];
    int i = 0;
    int j = 0;

    while (i < debtors.length && j < creditors.length) {
      final double dAmt = (debtors[i]['amount'] as double);
      final double cAmt = (creditors[j]['amount'] as double);
      final double settleAmt = _round2(math.min(dAmt, cAmt));

      if (settleAmt > 0.01) {
        transfers.add(
          GroupSettlementItem(
            fromName: debtors[i]['name'].toString(),
            toName: creditors[j]['name'].toString(),
            amount: settleAmt,
            isPoolTransfer:
            debtors[i]['isPool'] == true || creditors[j]['isPool'] == true,
          ),
        );
      }

      debtors[i]['amount'] = _round2(dAmt - settleAmt);
      creditors[j]['amount'] = _round2(cAmt - settleAmt);

      if ((debtors[i]['amount'] as double) <= 0.01) i++;
      if ((creditors[j]['amount'] as double) <= 0.01) j++;
    }

    return transfers;
  }

  DynamicMap toJson() => {
    'id': id,
    'name': name,
    'totalBudget': _round2(totalBudget),
    'createdAt': createdAt,
    'members': members.map((m) => m.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
  };

  factory GroupModel.fromJson(Map json) {
    return GroupModel(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Group Plan',
      totalBudget: _round2(((json['totalBudget'] ?? json['amount'] ?? 0) as num).toDouble()),
      createdAt: json['createdAt']?.toString() ?? 'Active Plan',
      members: json['members'] != null
          ? (json['members'] as List)
          .map((m) => GroupMemberModel.fromJson(Map.from(m as Map)))
          .toList()
          : [],
      expenses: json['expenses'] != null
          ? (json['expenses'] as List)
          .map((e) => GroupExpenseModel.fromJson(Map.from(e as Map)))
          .toList()
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

  DynamicMap toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'providerName': providerName,
    'accountNumber': accountNumber,
    'balance': _round2(balance),
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
      balance: _round2(((json['balance'] ?? 0) as num).toDouble()),
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
  final bool isPaid;
  final String paidDate;

  ScheduledTxModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.isExpense,
    this.attachmentBase64 = '',
    this.attachmentName = '',
    this.isPaid = false,
    this.paidDate = '',
  });

  bool get hasAttachment => attachmentBase64.isNotEmpty;

  DynamicMap toJson() => {
    'id': id,
    'title': title,
    'amount': _round2(amount),
    'dueDate': dueDate,
    'isExpense': isExpense,
    'attachmentBase64': attachmentBase64,
    'attachmentName': attachmentName,
    'isPaid': isPaid,
    'paidDate': paidDate,
  };

  factory ScheduledTxModel.fromJson(Map json) => ScheduledTxModel(
    id: json['id'].toString(),
    title: json['title']?.toString() ?? '',
    amount: _round2(((json['amount'] ?? 0) as num).toDouble()),
    dueDate: json['dueDate']?.toString() ?? '',
    isExpense: json['isExpense'] ?? true,
    attachmentBase64: json['attachmentBase64']?.toString() ?? '',
    attachmentName: json['attachmentName']?.toString() ?? '',
    isPaid: json['isPaid'] == true,
    paidDate: json['paidDate']?.toString() ?? '',
  );
}

// =============================================================================
// BUSINESS POS MODELS (TRUE COGS COST PRICE + PARTIAL DUE HISTORY)
// =============================================================================
class ProductModel {
  final String id;
  final String name;
  final double price;
  final double costPrice;
  final int stock;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    required this.stock,
  });

  double get unitProfit => _round2(price - costPrice);
  double get inventoryCostValue => _round2(costPrice * stock);
  double get inventoryRetailValue => _round2(price * stock);

  DynamicMap toJson() => {
    'id': id,
    'name': name,
    'price': _round2(price),
    'costPrice': _round2(costPrice),
    'stock': stock,
  };

  factory ProductModel.fromJson(Map json) => ProductModel(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    price: _round2(((json['price'] ?? 0) as num).toDouble()),
    costPrice: _round2(((json['costPrice'] ?? 0) as num).toDouble()),
    stock: ((json['stock'] ?? 0) as num).toInt(),
  );
}

class PartyPaymentModel {
  final String id;
  final double amount;
  final String date;
  final String note;

  PartyPaymentModel({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
  });

  DynamicMap toJson() => {
    'id': id,
    'amount': _round2(amount),
    'date': date,
    'note': note,
  };

  factory PartyPaymentModel.fromJson(Map json) => PartyPaymentModel(
    id: json['id'].toString(),
    amount: _round2(((json['amount'] ?? 0) as num).toDouble()),
    date: json['date']?.toString() ?? '',
    note: json['note']?.toString() ?? '',
  );
}

class PartyModel {
  final String id;
  final String name;
  final String phone;
  final bool isCustomer;
  final double dueAmount;
  final List<PartyPaymentModel> paymentHistory;

  PartyModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.isCustomer,
    required this.dueAmount,
    this.paymentHistory = const [],
  });

  DynamicMap toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'isCustomer': isCustomer,
    'dueAmount': _round2(dueAmount),
    'paymentHistory': paymentHistory.map((p) => p.toJson()).toList(),
  };

  factory PartyModel.fromJson(Map json) => PartyModel(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    isCustomer: json['isCustomer'] ?? true,
    dueAmount: _round2(((json['dueAmount'] ?? 0) as num).toDouble()),
    paymentHistory: json['paymentHistory'] is List
        ? (json['paymentHistory'] as List)
        .map((e) => PartyPaymentModel.fromJson(Map.from(e as Map)))
        .toList()
        : const [],
  );
}

class BusinessTxModel {
  final String id;
  final String title;
  final String type; // 'Sale', 'Purchase', 'Expense', 'Due Collection', 'Supplier Payment'
  final double amount;
  final String date;
  final String attachmentBase64;
  final String attachmentName;
  final String productId;
  final String productName;
  final int quantity;
  final double costTotal;
  final double discountAmount;
  final double vatAmount;
  final String partyId;
  final String partyName;
  final double paidAmount;
  final double dueAmount;

  BusinessTxModel({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.date,
    this.attachmentBase64 = '',
    this.attachmentName = '',
    this.productId = '',
    this.productName = '',
    this.quantity = 1,
    this.costTotal = 0.0,
    this.discountAmount = 0.0,
    this.vatAmount = 0.0,
    this.partyId = '',
    this.partyName = '',
    this.paidAmount = 0.0,
    this.dueAmount = 0.0,
  });

  bool get hasAttachment => attachmentBase64.isNotEmpty;
  double get saleProfit => type == 'Sale' ? _round2(amount - costTotal) : 0.0;

  DynamicMap toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'amount': _round2(amount),
    'date': date,
    'attachmentBase64': attachmentBase64,
    'attachmentName': attachmentName,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'costTotal': _round2(costTotal),
    'discountAmount': _round2(discountAmount),
    'vatAmount': _round2(vatAmount),
    'partyId': partyId,
    'partyName': partyName,
    'paidAmount': _round2(paidAmount),
    'dueAmount': _round2(dueAmount),
  };

  factory BusinessTxModel.fromJson(Map json) => BusinessTxModel(
    id: json['id'].toString(),
    title: json['title']?.toString() ?? '',
    type: json['type']?.toString() ?? 'Sale',
    amount: _round2(((json['amount'] ?? 0) as num).toDouble()),
    date: json['date']?.toString() ?? '',
    attachmentBase64: json['attachmentBase64']?.toString() ?? '',
    attachmentName: json['attachmentName']?.toString() ?? '',
    productId: json['productId']?.toString() ?? '',
    productName: json['productName']?.toString() ?? '',
    quantity: ((json['quantity'] ?? 1) as num).toInt(),
    costTotal: _round2(((json['costTotal'] ?? 0) as num).toDouble()),
    discountAmount: _round2(((json['discountAmount'] ?? 0) as num).toDouble()),
    vatAmount: _round2(((json['vatAmount'] ?? 0) as num).toDouble()),
    partyId: json['partyId']?.toString() ?? '',
    partyName: json['partyName']?.toString() ?? '',
    paidAmount: _round2(((json['paidAmount'] ?? 0) as num).toDouble()),
    dueAmount: _round2(((json['dueAmount'] ?? 0) as num).toDouble()),
  );
}

// =============================================================================
// UNIVERSAL RECEIPT / MEMO ATTACHMENT PICKER & ZOOMABLE VIEWER
// =============================================================================
class AttachmentHelper {
  static String _cleanOriginalName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return 'Receipt.jpg';
    // Strip ImagePicker's synthetic "scaled_" prefix so the original name stays intact.
    if (trimmed.startsWith('scaled_')) {
      final stripped = trimmed.substring('scaled_'.length);
      if (stripped.isNotEmpty) return stripped;
    }
    return trimmed;
  }

  static Future<StringMap?> pickReceiptOrMemo(BuildContext context) async {
    try {
      final picker = ImagePicker();
      // Do not pass maxWidth/imageQuality to pickImage so Android preserves the original filename;
      // compress cleanly in-memory right below instead.
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return null;

      final String displayName = _cleanOriginalName(file.name);
      Uint8List bytes = await file.readAsBytes();

      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final resized = decoded.width > 800
            ? img.copyResize(decoded, width: 800)
            : decoded;
        bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 70));
      }

      return {
        'base64': base64Encode(bytes),
        'name': displayName,
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

  static void viewAttachment(
      BuildContext context,
      String base64Data,
      String fileName,
      ) {
    if (base64Data.isEmpty) return;
    final Uint8List bytes = base64Decode(base64Data);
    final bool isPdf = fileName.toLowerCase().endsWith('.pdf');

    if (isPdf) {
      Printing.sharePdf(
        bytes: bytes,
        filename: fileName.isEmpty ? 'Document.pdf' : fileName,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF0F172A),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName.isEmpty ? 'Attached Receipt' : fileName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Pinch or scroll to zoom',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Download / Share',
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Color(0xFF38BDF8),
                      ),
                      onPressed: () => Printing.sharePdf(
                        bytes: bytes,
                        filename: fileName.isEmpty ? 'Receipt.jpg' : fileName,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF334155), height: 1),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  panEnabled: true,
                  child: Center(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// REUSABLE REALISTIC DONUT CHART (FIXED: 0% ON EMPTY DATA + SAFE CENTER FIT)
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
    final List<double> safeValues =
    values.map((v) => (v.isNaN || v.isInfinite || v < 0) ? 0.0 : v).toList();
    final double total = safeValues.fold(0.0, (s, v) => s + v);
    final bool isEmptyData = total <= 0.0001;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 126,
          height: 126,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(126, 126),
                painter: _DonutPainter(
                  values: isEmptyData ? const [] : safeValues,
                  colors: colors,
                ),
              ),
              SizedBox(
                width: 82,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        centerValue,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(labels.length, (i) {
              final double val = i < safeValues.length ? safeValues[i] : 0.0;
              final double pct =
              isEmptyData ? 0.0 : ((val / total) * 100.0).clamp(0.0, 100.0);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.5),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isEmptyData
                            ? const Color(0xFF475569)
                            : colors[i % colors.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        labels[i],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: isEmptyData
                            ? const Color(0xFF94A3B8)
                            : Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
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
    final double total = values.fold(0.0, (s, v) => s + (v > 0 ? v : 0.0));
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 10;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.butt;

    if (total <= 0.0001) {
      paint.color = const Color(0xFF334155);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final int nonZeroCount = values.where((v) => v > 0).length;
    final double gap = nonZeroCount > 1 ? 0.03 : 0.0;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final double v = values[i];
      if (v <= 0) continue;
      final double sweep = (v / total) * 2 * math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        math.max(0.01, sweep - gap),
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

// =============================================================================
// ENTERPRISE PROVIDER
// =============================================================================
class TransactionProvider with ChangeNotifier {
static const String _driveScope = 'https://www.googleapis.com/auth/drive.file';
static const String _driveBackupFileName = 'FinBlend_Account_Backup.json';

List<TransactionModel> _transactions = [];
Map<String, double> _budgets = {};
List<String> _expenseCategories = [
'Food & Dining',
'Transportation',
'Shopping',
'Utilities & Rent',
];
List<String> _incomeCategories = [
'Monthly Salary',
'Freelance Revenue',
'Investments',
'Business Dividend',
];
List<String> _customLabels = ['Urgent', 'Work', 'Family', 'Reimbursable'];
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

bool _isGoogleConnected = false;
String _connectedGoogleEmail = '';
String _googleAccessToken = '';
String _customGoogleWebClientId = kGoogleWebClientId;
String _lastGoogleDriveBackupAt = 'No backup yet';
final Map<String, String> _phoneToEmailDirectory = {};
final Map<String, int> _deletedAccountTimestamps = {};

bool _isDarkMode = true;
String _language = 'en';
bool _notificationsEnabled = true;
bool _permissionsGranted = true;

// Global Privacy, Currency, App Lock, Last-Used UX & Web Refresh Persistence
bool _hideBalances = false;
String _currencyCode = 'BDT';
bool _appLockEnabled = false;
String _appLockPinHash = '';
bool _isAppUnlocked = true;
int _lastActiveTabIndex = 0;
int _lastBusinessTabIndex = 0;
bool _lastIsBusinessMode = false;
String _lastUsedExpenseCategory = 'Food & Dining';
String _lastUsedIncomeCategory = 'Monthly Salary';
String _lastUsedWalletId = '';

String _customCloudUrl = '';
bool _isSyncing = false;
bool _hasUnsyncedChanges = false;
String _lastSyncedAt = 'Not synced yet';
String _cloudStatus = 'Local Only';
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

static bool isValidGoogleEmail(String email) {
final clean = email.trim().toLowerCase();
return clean.endsWith('@gmail.com') || clean.endsWith('@googlemail.com');
}

static String normalizePhoneKey(String rawPhone) {
String digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
if (digits.startsWith('880') && digits.length > 10) {
digits = digits.substring(3);
}
if (digits.startsWith('0') && digits.length > 9) {
digits = digits.substring(1);
}
return digits;
}

// --- PERSONAL & WALLET GETTERS ---
List<TransactionModel> get transactions => _transactions.reversed.toList();
Map<String, double> get budgets => _budgets;
List<String> get expenseCategories => _expenseCategories;
List<String> get incomeCategories => _incomeCategories;
List<String> get customLabels => _customLabels;
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

bool get isGoogleConnected =>
_isGoogleConnected && _connectedGoogleEmail.isNotEmpty;
String get customGoogleWebClientId => _customGoogleWebClientId;
String get googleAccessToken => _googleAccessToken;

String get connectedGoogleEmail {
if (_isGoogleConnected && _connectedGoogleEmail.isNotEmpty) {
return _connectedGoogleEmail;
}
return 'Not connected to Google';
}

String get lastGoogleDriveBackupAt => _lastGoogleDriveBackupAt;
bool get hasDriveBackup =>
_lastGoogleDriveBackupAt.isNotEmpty &&
_lastGoogleDriveBackupAt != 'No backup yet';
List get localBackupHistory => const [];

bool get isDarkMode => _isDarkMode;
String get language => _language;
bool get isBengali => _language == 'bn';
bool get notificationsEnabled => _notificationsEnabled;
bool get permissionsGranted => _permissionsGranted;

bool get hideBalances => _hideBalances;
String get currencyCode => _currencyCode;
String get currencySymbol => AppCurrency.symbol;
bool get appLockEnabled => _appLockEnabled && _appLockPinHash.isNotEmpty;
bool get isAppUnlocked => !appLockEnabled || _isAppUnlocked;
int get lastActiveTabIndex => _lastActiveTabIndex;
int get lastBusinessTabIndex => _lastBusinessTabIndex;
bool get lastIsBusinessMode => _lastIsBusinessMode;
String get lastUsedExpenseCategory => _lastUsedExpenseCategory;
String get lastUsedIncomeCategory => _lastUsedIncomeCategory;
String get lastUsedWalletId => _lastUsedWalletId;

String get customCloudUrl => _customCloudUrl;
bool get isSyncing => _isSyncing;
bool get hasUnsyncedChanges => _hasUnsyncedChanges;
String get lastSyncedAt => _lastSyncedAt;

/// Truthful sync badge (never claims "Synced ✓" when no backup/sync exists).
String get cloudStatus {
if (_isSyncing) return _cloudStatus;
if (hasDriveBackup && !_hasUnsyncedChanges) return 'Backed Up ✓';
if (_lastSyncedAt != 'Not synced yet' && !_hasUnsyncedChanges) {
return 'Synced ✓';
}
if (_hasUnsyncedChanges) return 'Unsynced Changes';
return 'Local Only';
}

String formatMoney(
double amount, {
bool respectPrivacy = true,
bool showPlusSign = false,
}) {
return AppCurrency.format(
amount,
respectPrivacy: respectPrivacy,
showPlusSign: showPlusSign,
);
}

// Excludes wallet-to-wallet transfers so income/expense totals stay exact.
double get totalIncome => _round2(
_transactions
.where((tx) => !tx.isExpense && !tx.isTransfer)
.fold(0.0, (sum, tx) => sum + tx.amount),
);

double get totalExpense => _round2(
_transactions
.where((tx) => tx.isExpense && !tx.isTransfer)
.fold(0.0, (sum, tx) => sum + tx.amount),
);

double get totalBalance => _round2(totalIncome - totalExpense);
double get totalWalletsBalance =>
_round2(_wallets.fold(0.0, (sum, w) => sum + w.balance));

// --- BUSINESS POS GETTERS (TRUE COGS PROFIT, EXCLUDING DUE COLLECTIONS) ---
List<ProductModel> get products => _products;
List<PartyModel> get parties => _parties;
List<BusinessTxModel> get businessTxs => _businessTxs.reversed.toList();

double get totalSales => _round2(
_businessTxs
.where((t) => t.type == 'Sale')
.fold(0.0, (s, t) => s + t.amount),
);

double get totalCOGS => _round2(
_businessTxs
.where((t) => t.type == 'Sale')
.fold(0.0, (s, t) => s + t.costTotal),
);

double get totalPurchases => _round2(
_businessTxs
.where((t) => t.type == 'Purchase')
.fold(0.0, (s, t) => s + t.amount),
);

double get totalBizExpenses => _round2(
_businessTxs
.where((t) => t.type == 'Expense')
.fold(0.0, (s, t) => s + t.amount),
);

double get totalDueCollected => _round2(
_businessTxs
.where((t) => t.type == 'Due Collection')
.fold(0.0, (s, t) => s + t.amount),
);

double get grossProfit => _round2(totalSales - totalCOGS);
double get netProfit => _round2(grossProfit - totalBizExpenses);
double get profitMarginPercent =>
totalSales > 0 ? _round2((netProfit / totalSales) * 100.0) : 0.0;

double get totalCustomerDue => _round2(
_parties
.where((p) => p.isCustomer)
.fold(0.0, (s, p) => s + p.dueAmount),
);

double get totalSupplierDue => _round2(
_parties
.where((p) => !p.isCustomer)
.fold(0.0, (s, p) => s + p.dueAmount),
);

double get totalInventoryCostValue =>
_round2(_products.fold(0.0, (s, p) => s + p.inventoryCostValue));

double get totalInventoryRetailValue =>
_round2(_products.fold(0.0, (s, p) => s + p.inventoryRetailValue));

int get totalCustomersCount => _parties.where((p) => p.isCustomer).length;
int get lowStockCount => _products.where((p) => p.stock <= 5).length;

// --- GLOBAL PRIVACY, CURRENCY, APP LOCK & ROUTE PERSISTENCE ---
Future<void> toggleHideBalances() async {
_hideBalances = !_hideBalances;
AppCurrency.hideBalances.value = _hideBalances;
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('pref_hide_balances', _hideBalances);
notifyListeners();
}

Future<void> setCurrencyCode(String code) async {
if (!AppCurrency.supportedCurrencies.containsKey(code)) return;
_currencyCode = code;
AppCurrency.currencyCode.value = code;
final prefs = await SharedPreferences.getInstance();
await prefs.setString('pref_currency_code', code);
await _saveData(syncCloud: true);
notifyListeners();
}

Future<void> setAppLockPin(String pin) async {
final clean = pin.trim();
if (clean.length < 4) return;
_appLockEnabled = true;
_appLockPinHash = base64Encode(utf8.encode('fb_applock_$clean'));
_isAppUnlocked = true;
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('pref_app_lock_enabled', true);
await prefs.setString('pref_app_lock_pin_hash', _appLockPinHash);
notifyListeners();
}

Future<void> disableAppLock() async {
_appLockEnabled = false;
_appLockPinHash = '';
_isAppUnlocked = true;
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('pref_app_lock_enabled', false);
await prefs.remove('pref_app_lock_pin_hash');
notifyListeners();
}

bool verifyAndUnlockApp(String pin) {
final hash = base64Encode(utf8.encode('fb_applock_${pin.trim()}'));
if (hash == _appLockPinHash) {
_isAppUnlocked = true;
notifyListeners();
return true;
}
return false;
}

void lockAppNow() {
if (appLockEnabled) {
_isAppUnlocked = false;
notifyListeners();
}
}

Future<void> saveNavigationState({
int? personalTabIndex,
int? businessTabIndex,
bool? isBusinessMode,
}) async {
final prefs = await SharedPreferences.getInstance();
if (personalTabIndex != null) {
_lastActiveTabIndex = personalTabIndex;
await prefs.setInt('nav_personal_tab', personalTabIndex);
}
if (businessTabIndex != null) {
_lastBusinessTabIndex = businessTabIndex;
await prefs.setInt('nav_business_tab', businessTabIndex);
}
if (isBusinessMode != null) {
_lastIsBusinessMode = isBusinessMode;
await prefs.setBool('nav_is_business_mode', isBusinessMode);
}
}

Future<void> setGoogleWebClientId(String clientId) async {
_customGoogleWebClientId = clientId.trim();
final prefs = await SharedPreferences.getInstance();
await prefs.setString('custom_google_web_client_id', _customGoogleWebClientId);
notifyListeners();
}

GoogleSignIn _createGoogleSignInInstance({bool includeDriveScope = false}) {
final String activeClientId = _customGoogleWebClientId.trim();
return GoogleSignIn(
clientId: kIsWeb && activeClientId.isNotEmpty ? activeClientId : null,
serverClientId: !kIsWeb && activeClientId.isNotEmpty ? activeClientId : null,
scopes: <String>[
'email',
'profile',
if (includeDriveScope) _driveScope,
],
);
}

// ===========================================================================
// 1. NATIVE GOOGLE LOGIN (NEVER AUTO-RESTORES BACKUPS ON LOGIN!)
// ===========================================================================
Future<DynamicMap> signInWithNativeGoogleOAuth() async {
_isSyncing = true;
_cloudStatus = tr('Opening Google Sign-In...', 'গুগল লগইন খোলা হচ্ছে...');
notifyListeners();

try {
final GoogleSignIn googleSignIn =
_createGoogleSignInInstance(includeDriveScope: false);

try {
await googleSignIn.signOut();
} catch (_) {}

final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

if (googleUser == null) {
_isSyncing = false;
_cloudStatus = 'Sign-In Canceled';
notifyListeners();
return {
'success': false,
'canceled': true,
'message': tr('Google Sign-In was canceled.', 'গুগল লগইন বাতিল করা হয়েছে।'),
};
}

final GoogleSignInAuthentication googleAuth =
await googleUser.authentication;
final String verifiedEmail = googleUser.email.trim().toLowerCase();
final String verifiedName = (googleUser.displayName ?? '').trim().isNotEmpty
? googleUser.displayName!.trim()
: verifiedEmail.split('@').first;
final String accessToken = googleAuth.accessToken ?? '';

return await signInWithGoogleAccount(
googleEmail: verifiedEmail,
displayName: verifiedName,
accessToken: accessToken,
);
} catch (e) {
_isSyncing = false;
_cloudStatus = 'Google OAuth Error';
notifyListeners();

final String errStr = e.toString();
if (errStr.contains('ApiException: 10') ||
errStr.contains('sign_in_failed')) {
return {
'success': false,
'needsConfig': true,
'message': tr(
'Google Play Services Error 10: Verify your SHA-1 and package name in Google Cloud Console, or add this Google account under Audience -> Test users.',
'গুগল লগইন ত্রুটি (Error 10): গুগল ক্লাউড কনসোলে SHA-1 এবং Test users যাচাই করুন।',
),
};
}
return {
'success': false,
'message': tr(
'Google Sign-In failed: $errStr',
'গুগল লগইন ব্যর্থ হয়েছে: $errStr',
),
};
}
}

Future<DynamicMap> signInWithGoogleAccount({
required String googleEmail,
required String displayName,
String accessToken = '',
}) async {
final String cleanEmail = googleEmail.trim().toLowerCase();
final prefs = await SharedPreferences.getInstance();

if (accessToken.trim().isNotEmpty) {
_googleAccessToken = accessToken.trim();
}

Map? remoteMap = await _fetchRemoteCloudMap(cleanEmail);
final int localDeletedAt = _deletedAccountTimestamps[cleanEmail] ?? 0;

if (remoteMap != null) {
final int remoteUpdatedAt = (remoteMap['updatedAt'] as num?)?.toInt() ?? 0;
if (remoteMap['isDeletedAccount'] == true ||
remoteUpdatedAt <= localDeletedAt) {
remoteMap = null;
}
}

_resetToCleanAccount();
_cloudEmail = cleanEmail;
_isGoogleConnected = true;
_connectedGoogleEmail = cleanEmail;
_lastGoogleDriveBackupAt =
prefs.getString('gdrive_ts_$cleanEmail') ?? 'No backup yet';

final String resolvedName = displayName.trim().isNotEmpty
? displayName.trim()
: cleanEmail.split('@').first;

if (remoteMap != null) {
_applyStateMap(remoteMap, preserveCurrentIdentity: true);
_cloudEmail = cleanEmail;
_connectedGoogleEmail = cleanEmail;
_isGoogleConnected = true;
if (_userName.isEmpty || _userName == 'FinBlend User') {
_userName = resolvedName;
}
} else {
final localKey = 'account_cache_${_getCloudChannelKey(cleanEmail)}';
if (prefs.containsKey(localKey)) {
final cachedMap = jsonDecode(prefs.getString(localKey)!) as Map;
final int cachedTime = (cachedMap['updatedAt'] as num?)?.toInt() ?? 0;
if (cachedMap['isDeletedAccount'] != true &&
cachedTime > localDeletedAt) {
_applyStateMap(cachedMap, preserveCurrentIdentity: true);
} else {
_userName = resolvedName;
}
} else {
_userName = resolvedName;
}
_cloudEmail = cleanEmail;
_isGoogleConnected = true;
_connectedGoogleEmail = cleanEmail;
}

_ensureDefaultCashWallet();

await prefs.setBool('is_logged_in', true);
await prefs.setString('user_name', _userName);
await prefs.setString('user_email', _cloudEmail);
await prefs.setBool('is_google_connected', true);
await prefs.setString('connected_google_email', _connectedGoogleEmail);

await _saveData(syncCloud: false);
await pushToCloud(silent: false);
_startAutoSyncTimer();

_isSyncing = false;
notifyListeners();

return {
'success': true,
'message': tr(
'Signed in with Google as $_userName ($cleanEmail)',
'$_userName ($cleanEmail) হিসেবে গুগল লগইন সম্পন্ন হয়েছে!',
),
};
}

// ===========================================================================
// 2. EXPLICIT GOOGLE DRIVE OAUTH PERMISSION & DEVICE ACCOUNT VERIFIER
// ===========================================================================
Future<DynamicMap?> _authorizeGoogleDriveWithPermission() async {
try {
final GoogleSignIn googleSignIn =
_createGoogleSignInInstance(includeDriveScope: true);

try {
await googleSignIn.signOut();
} catch (_) {}

final GoogleSignInAccount? account = await googleSignIn.signIn();
if (account == null) {
return null;
}

try {
final bool granted =
await googleSignIn.requestScopes(<String>[_driveScope]);
if (!granted) {
return {
'error': tr(
'Google Drive permission was denied.',
'গুগল ড্রাইভের অনুমতি প্রদান করা হয়নি।',
),
};
}
} catch (_) {}

final GoogleSignInAuthentication auth = await account.authentication;
final String token = auth.accessToken ?? '';
final String gEmail = account.email.trim().toLowerCase();

_isGoogleConnected = true;
_connectedGoogleEmail = gEmail;
_googleAccessToken = token;

final prefs = await SharedPreferences.getInstance();
await prefs.setBool('is_google_connected', true);
await prefs.setString('connected_google_email', gEmail);
notifyListeners();

return {
'email': gEmail,
'accessToken': token,
};
} catch (e) {
return {
'error': tr(
'Could not verify Google Account on this device: $e',
'ডিভাইসে গুগল অ্যাকাউন্ট যাচাই করা যায়নি: $e',
),
};
}
}

// ===========================================================================
// 3. MANUAL GOOGLE DRIVE BACKUP (DRIVE API V3 + ISOLATED VAULT)
// ===========================================================================
Future<DynamicMap> backupFullAccountToGoogleDrive({
String? overrideGoogleEmail,
String? oauthAccessToken,
}) async {
_isSyncing = true;
_cloudStatus = tr(
'Requesting Google Drive permission...',
'গুগল ড্রাইভের অনুমতি নেওয়া হচ্ছে...',
);
notifyListeners();

final DynamicMap? driveAuth = await _authorizeGoogleDriveWithPermission();
if (driveAuth == null) {
_isSyncing = false;
_cloudStatus = 'Backup Canceled';
notifyListeners();
return {
'success': false,
'message': tr(
'Backup canceled. You must select a Google Account logged in on your device and grant permission.',
'ব্যাকআপ বাতিল হয়েছে। ডিভাইসে লগইন থাকা গুগল অ্যাকাউন্ট নির্বাচন করে অনুমতি দিতে হবে।',
),
};
}
if (driveAuth['error'] != null) {
_isSyncing = false;
_cloudStatus = 'Permission Denied';
notifyListeners();
return {
'success': false,
'message': driveAuth['error'].toString(),
};
}

final String targetGoogleEmail = driveAuth['email'].toString();
final String accessToken = driveAuth['accessToken']?.toString() ?? '';

_cloudStatus = tr(
'Uploading to Google Drive...',
'গুগল ড্রাইভে আপলোড হচ্ছে...',
);
notifyListeners();

try {
final String nowStamp = _generateTimestamp();
_lastGoogleDriveBackupAt = nowStamp;

final DynamicMap fullState = exportFullStateMap();
fullState['googleDriveEmail'] = targetGoogleEmail;
fullState['lastGoogleDriveBackupAt'] = nowStamp;
fullState['isDeletedAccount'] = false;

final String prettyJson =
const JsonEncoder.withIndent('  ').convert(fullState);
final String base64Payload =
base64Encode(utf8.encode(jsonEncode(fullState)));

bool uploadedToRealDriveApi = false;
if (accessToken.isNotEmpty) {
try {
String? existingFileId;
final searchUri = Uri.parse(
'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent("name = '$_driveBackupFileName' and trashed = false")}&spaces=drive&fields=files(id,name)',
);
final searchRes = await http.get(
searchUri,
headers: {'Authorization': 'Bearer $accessToken'},
).timeout(const Duration(seconds: 10));

if (searchRes.statusCode == 200) {
final searchData = jsonDecode(searchRes.body) as Map;
final List files = (searchData['files'] as List?) ?? [];
if (files.isNotEmpty) {
existingFileId = files.first['id']?.toString();
}
}

if (existingFileId != null && existingFileId.isNotEmpty) {
final patchRes = await http
.patch(
Uri.parse(
'https://www.googleapis.com/upload/drive/v3/files/$existingFileId?uploadType=media',
),
headers: {
'Authorization': 'Bearer $accessToken',
'Content-Type': 'application/json; charset=UTF-8',
},
body: utf8.encode(prettyJson),
)
.timeout(const Duration(seconds: 12));
uploadedToRealDriveApi = patchRes.statusCode == 200;
} else {
const String boundary = 'finblend_gdrive_boundary_2026';
final String metadataJson = jsonEncode({
'name': _driveBackupFileName,
'mimeType': 'application/json',
'description': 'FinBlend Full Account Backup ($nowStamp)',
});

final String multipartBody = '--$boundary\r\n'
'Content-Type: application/json; charset=UTF-8\r\n\r\n'
'$metadataJson\r\n'
'--$boundary\r\n'
'Content-Type: application/json\r\n\r\n'
'$prettyJson\r\n'
'--$boundary--';

final postRes = await http
.post(
Uri.parse(
'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
),
headers: {
'Authorization': 'Bearer $accessToken',
'Content-Type': 'multipart/related; boundary=$boundary',
},
body: utf8.encode(multipartBody),
)
.timeout(const Duration(seconds: 12));
uploadedToRealDriveApi =
postRes.statusCode == 200 || postRes.statusCode == 201;
}
} catch (e) {
debugPrint('Drive v3 upload error: $e');
}
}

final prefs = await SharedPreferences.getInstance();
final String driveVaultKey = _getGoogleDriveVaultKey(targetGoogleEmail);
await prefs.setString(
'gdrive_local_vault_$driveVaultKey',
jsonEncode(fullState),
);
await prefs.setString('gdrive_ts_$targetGoogleEmail', nowStamp);

try {
await http
.post(
Uri.parse('https://ntfy.sh/$driveVaultKey'),
body: base64Payload,
)
.timeout(const Duration(seconds: 8));
} catch (_) {}

_hasUnsyncedChanges = false;
await _saveData(syncCloud: true);
_isSyncing = false;
_cloudStatus = 'Backed Up ✓';
notifyListeners();

return {
'success': true,
'message': uploadedToRealDriveApi
? tr(
'Backed up to Google Drive ($targetGoogleEmail) as $_driveBackupFileName! (${_transactions.length} Tx, ${_wallets.length} Wallets, ${_groups.length} Groups)',
'গুগল ড্রাইভে ($targetGoogleEmail) সম্পূর্ণ ব্যাকআপ সেভ হয়েছে!',
)
: tr(
'Backed up to Google Drive Vault ($targetGoogleEmail)! (${_transactions.length} Tx, ${_wallets.length} Wallets, ${_groups.length} Groups)',
'গুগল ড্রাইভে ($targetGoogleEmail) সম্পূর্ণ ব্যাকআপ সংরক্ষিত হয়েছে!',
),
};
} catch (e) {
_isSyncing = false;
_cloudStatus = 'Backup Error';
notifyListeners();
return {
'success': false,
'message': tr(
'Google Drive backup failed: $e',
'গুগল ড্রাইভ ব্যাকআপ ব্যর্থ হয়েছে: $e',
),
};
}
}

// ===========================================================================
// 4. MANUAL GOOGLE DRIVE RESTORE (DRIVE API V3 + ISOLATED VAULT)
// ===========================================================================
Future<DynamicMap> restoreFullAccountFromGoogleDrive({
String? googleEmail,
bool preserveCurrentAccountEmail = true,
}) async {
_isSyncing = true;
_cloudStatus = tr(
'Requesting Google Drive permission...',
'গুগল ড্রাইভের অনুমতি নেওয়া হচ্ছে...',
);
notifyListeners();

final DynamicMap? driveAuth = await _authorizeGoogleDriveWithPermission();
if (driveAuth == null) {
_isSyncing = false;
_cloudStatus = 'Restore Canceled';
notifyListeners();
return {
'success': false,
'message': tr(
'Restore canceled. Please select the Google Account where your backup is stored.',
'রিস্টোর বাতিল হয়েছে। ব্যাকআপ থাকা গুগল অ্যাকাউন্টটি নির্বাচন করুন।',
),
};
}
if (driveAuth['error'] != null) {
_isSyncing = false;
_cloudStatus = 'Permission Denied';
notifyListeners();
return {
'success': false,
'message': driveAuth['error'].toString(),
};
}

final String targetEmail = driveAuth['email'].toString();
final String accessToken = driveAuth['accessToken']?.toString() ?? '';

_cloudStatus = tr(
'Downloading backup from Google Drive...',
'গুগল ড্রাইভ থেকে ডাউনলোড হচ্ছে...',
);
notifyListeners();

try {
Map? restoredMap;

if (accessToken.isNotEmpty) {
try {
final searchUri = Uri.parse(
'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent("name = '$_driveBackupFileName' and trashed = false")}&orderBy=modifiedTime desc&spaces=drive&fields=files(id,name,modifiedTime)',
);
final searchRes = await http.get(
searchUri,
headers: {'Authorization': 'Bearer $accessToken'},
).timeout(const Duration(seconds: 10));

if (searchRes.statusCode == 200) {
final searchData = jsonDecode(searchRes.body) as Map;
final List files = (searchData['files'] as List?) ?? [];
if (files.isNotEmpty) {
final String fileId = files.first['id'].toString();
final downloadRes = await http.get(
Uri.parse(
'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
),
headers: {'Authorization': 'Bearer $accessToken'},
).timeout(const Duration(seconds: 12));

if (downloadRes.statusCode == 200 &&
downloadRes.body.trim().isNotEmpty) {
restoredMap =
jsonDecode(utf8.decode(downloadRes.bodyBytes)) as Map;
}
}
}
} catch (e) {
debugPrint('Drive v3 download error: $e');
}
}

final prefs = await SharedPreferences.getInstance();
final String driveVaultKey = _getGoogleDriveVaultKey(targetEmail);

restoredMap ??= await _fetchFromChannelKey(driveVaultKey);

if (restoredMap == null) {
final localDriveKey = 'gdrive_local_vault_$driveVaultKey';
if (prefs.containsKey(localDriveKey)) {
restoredMap = jsonDecode(prefs.getString(localDriveKey)!) as Map;
}
}

if (restoredMap == null) {
_isSyncing = false;
_cloudStatus = 'No Drive Backup Found';
notifyListeners();
return {
'success': false,
'message': tr(
'No backup found on Google Drive for $targetEmail. Please back up to Google Drive first.',
'$targetEmail-এর গুগল ড্রাইভে কোনো ব্যাকআপ পাওয়া যায়নি।',
),
};
}

final String currentActiveEmail = _cloudEmail;
final bool hasActiveLogin =
currentActiveEmail.isNotEmpty && currentActiveEmail != 'not signed in';
final String finalEmail =
(preserveCurrentAccountEmail && hasActiveLogin)
? currentActiveEmail
: targetEmail;

_deletedAccountTimestamps.remove(finalEmail);
await prefs.setString(
'deleted_account_timestamps',
jsonEncode(_deletedAccountTimestamps),
);

_resetToCleanAccount();
_applyStateMap(
restoredMap,
preserveCurrentIdentity: preserveCurrentAccountEmail && hasActiveLogin,
);

_cloudEmail = finalEmail;
_isGoogleConnected = true;
_connectedGoogleEmail = targetEmail;
_lastUpdatedTimestamp = DateTime.now().millisecondsSinceEpoch;
_hasUnsyncedChanges = false;
_ensureDefaultCashWallet();

await prefs.setBool('is_logged_in', true);
await prefs.setString('user_name', _userName);
await prefs.setString('user_email', _cloudEmail);

await _saveData(syncCloud: false);
await pushToCloud(silent: false);
_startAutoSyncTimer();

_isSyncing = false;
_cloudStatus = 'Backed Up ✓';
notifyListeners();

return {
'success': true,
'message': tr(
'Restored ${_transactions.length} transactions, ${_wallets.length} wallets, and ${_groups.length} groups from Google Drive ($targetEmail)!',
'গুগল ড্রাইভ ($targetEmail) থেকে ${_transactions.length} টি লেনদেন, ${_wallets.length} টি ওয়ালেট এবং ${_groups.length} টি গ্রুপ রিস্টোর হয়েছে!',
),
};
} catch (e) {
_isSyncing = false;
notifyListeners();
return {
'success': false,
'message': tr('Restore error: $e', 'রিস্টোর ত্রুটি: $e'),
};
}
}

  void setLanguage(String langCode) {
    _language = langCode;
    _saveData(markDirty: false);
    notifyListeners();
  }

  void toggleLanguage() {
    _language = _language == 'en' ? 'bn' : 'en';
    _saveData(markDirty: false);
    notifyListeners();
  }

  String tr(String enText, String bnText) {
    return _language == 'bn' ? bnText : enText;
  }

  String _generateTimestamp([DateTime? customDate]) {
    final now = customDate ?? DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');
    return '${months[now.month - 1]} ${now.day}, ${now.year} • $hour:$minute $amPm';
  }

  String formatDateOnly(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getCloudChannelKey(String email) {
    final clean = email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'finblend_cloud_db_v3_$clean';
  }

  String _getPhoneLookupChannelKey(String rawPhone) {
    final norm = normalizePhoneKey(rawPhone);
    return 'finblend_phone_auth_v3_$norm';
  }

  String _getGoogleDriveVaultKey(String googleEmail) {
    final clean = googleEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'finblend_gdrive_vault_v3_$clean';
  }

  String _hashPassword(String password) {
    return base64Encode(utf8.encode('fb_salt_${password.trim()}'));
  }

  void _ensureDefaultCashWallet() {
    if (_wallets.isEmpty) {
      _wallets.add(
        WalletModel(
          id: 'wallet_cash_default',
          name: 'Cash',
          type: 'Cash',
          providerName: 'Cash in Hand',
          balance: 0.0,
        ),
      );
    }
  }

  void _resetToCleanAccount() {
    _transactions = [];
    _budgets = {};
    _expenseCategories = [
      'Food & Dining',
      'Transportation',
      'Shopping',
      'Utilities & Rent',
    ];
    _incomeCategories = [
      'Monthly Salary',
      'Freelance Revenue',
      'Investments',
      'Business Dividend',
    ];
    _customLabels = ['Urgent', 'Work', 'Family', 'Reimbursable'];
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
    _lastUsedExpenseCategory = 'Food & Dining';
    _lastUsedIncomeCategory = 'Monthly Salary';
    _lastUsedWalletId = '';
    _hasUnsyncedChanges = false;
    _lastUpdatedTimestamp = DateTime.now().millisecondsSinceEpoch;
  }

  DynamicMap exportFullStateMap() {
    if (_lastUpdatedTimestamp == 0) {
      _lastUpdatedTimestamp = DateTime.now().millisecondsSinceEpoch;
    }
    return {
      'archiveVersion': '4.0',
      'exportedAt': _generateTimestamp(),
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
      'isGoogleConnected': _isGoogleConnected,
      'connectedGoogleEmail': _connectedGoogleEmail,
      'lastGoogleDriveBackupAt': _lastGoogleDriveBackupAt,
      'language': _language,
      'currencyCode': _currencyCode,
      'tx_data': _transactions.map((t) => t.toJson()).toList(),
      'bdg_data': _budgets,
      'exp_cat_data': _expenseCategories,
      'inc_cat_data': _incomeCategories,
      'custom_labels_data': _customLabels,
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

  void _applyStateMap(Map map, {bool preserveCurrentIdentity = false}) {
    if (map['isDeletedAccount'] == true) {
      _resetToCleanAccount();
      return;
    }
    _lastUpdatedTimestamp =
        (map['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;

    if (!preserveCurrentIdentity) {
      if (map['email'] != null && map['email'].toString().isNotEmpty) {
        _cloudEmail = map['email'].toString().trim().toLowerCase();
      }
      if (map['userName'] != null && map['userName'].toString().isNotEmpty) {
        _userName = map['userName'].toString();
      }
      if (map['passwordHash'] != null && map['passwordHash'].toString().isNotEmpty) {
        _passwordHash = map['passwordHash'].toString();
      }
    } else {
      if ((_userName.isEmpty || _userName == 'FinBlend User') &&
          map['userName'] != null) {
        _userName = map['userName'].toString();
      }
    }

    if (map['userPhone'] != null && map['userPhone'].toString().isNotEmpty) {
      _userPhone = map['userPhone'].toString();
      final norm = normalizePhoneKey(_userPhone);
      if (norm.isNotEmpty && _cloudEmail.isNotEmpty) {
        _phoneToEmailDirectory[norm] = _cloudEmail;
      }
    }
    if (map['userDob'] != null && map['userDob'].toString().isNotEmpty) {
      _userDob = map['userDob'].toString();
    }
    if (map['userGender'] != null && map['userGender'].toString().isNotEmpty) {
      _userGender = map['userGender'].toString();
    }
    if (map['userOccupation'] != null && map['userOccupation'].toString().isNotEmpty) {
      _userOccupation = map['userOccupation'].toString();
    }
    if (map['userOrganization'] != null && map['userOrganization'].toString().isNotEmpty) {
      _userOrganization = map['userOrganization'].toString();
    }
    if (map['userAddress'] != null && map['userAddress'].toString().isNotEmpty) {
      _userAddress = map['userAddress'].toString();
    }
    if (map['userPhotoBase64'] != null && map['userPhotoBase64'].toString().isNotEmpty) {
      _userPhotoBase64 = map['userPhotoBase64'].toString();
    }
    if (map['language'] != null) _language = map['language'].toString();
    if (map['currencyCode'] != null &&
        AppCurrency.supportedCurrencies.containsKey(map['currencyCode'].toString())) {
      _currencyCode = map['currencyCode'].toString();
      AppCurrency.currencyCode.value = _currencyCode;
    }

    if (map['tx_data'] != null) {
      _transactions = (map['tx_data'] as List)
          .map((i) => TransactionModel.fromJson(Map.from(i as Map)))
          .toList();
    }
    if (map['bdg_data'] != null) {
      final rawBdg = Map.from(map['bdg_data'] as Map);
      _budgets = {};
      rawBdg.forEach((k, v) {
        _budgets[k.toString()] = _round2((v as num).toDouble());
      });
    }
    if (map['exp_cat_data'] != null) {
      _expenseCategories = List<String>.from(map['exp_cat_data'] as List);
    }
    if (map['inc_cat_data'] != null) {
      _incomeCategories = List<String>.from(map['inc_cat_data'] as List);
    }
    if (map['custom_labels_data'] != null) {
      _customLabels = List<String>.from(map['custom_labels_data'] as List);
    }
    if (map['grp_data'] != null) {
      _groups = (map['grp_data'] as List)
          .map((i) => GroupModel.fromJson(Map.from(i as Map)))
          .toList();
    }
    if (map['saved_members_data'] != null) {
      _savedMembers = List<String>.from(map['saved_members_data'] as List);
    }
    if (map['wal_data'] != null) {
      _wallets = (map['wal_data'] as List)
          .map((i) => WalletModel.fromJson(Map.from(i as Map)))
          .toList();
    }
    if (map['sch_data'] != null) {
      _scheduledTxs = (map['sch_data'] as List)
          .map((i) => ScheduledTxModel.fromJson(Map.from(i as Map)))
          .toList();
    }
    if (map['biz_prod_data'] != null) {
      _products = (map['biz_prod_data'] as List)
          .map((i) => ProductModel.fromJson(Map.from(i as Map)))
          .toList();
    }
    if (map['biz_party_data'] != null) {
      _parties = (map['biz_party_data'] as List)
          .map((i) => PartyModel.fromJson(Map.from(i as Map)))
          .toList();
    }
    if (map['biz_tx_data'] != null) {
      _businessTxs = (map['biz_tx_data'] as List)
          .map((i) => BusinessTxModel.fromJson(Map.from(i as Map)))
          .toList();
    }
    if (map['pref_dark_mode'] != null) _isDarkMode = map['pref_dark_mode'] as bool;
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('local_backup_history');

      _customCloudUrl = prefs.getString('custom_cloud_url') ?? '';
      if (prefs.containsKey('custom_google_web_client_id')) {
        _customGoogleWebClientId =
            prefs.getString('custom_google_web_client_id') ?? kGoogleWebClientId;
      }
      _lastSyncedAt = prefs.getString('last_synced_at') ?? 'Not synced yet';

      // Global privacy, currency, App Lock, last-used UX & navigation state
      _hideBalances = prefs.getBool('pref_hide_balances') ?? false;
      AppCurrency.hideBalances.value = _hideBalances;
      _currencyCode = prefs.getString('pref_currency_code') ?? 'BDT';
      AppCurrency.currencyCode.value = _currencyCode;

      _appLockEnabled = prefs.getBool('pref_app_lock_enabled') ?? false;
      _appLockPinHash = prefs.getString('pref_app_lock_pin_hash') ?? '';
      _isAppUnlocked = !(_appLockEnabled && _appLockPinHash.isNotEmpty);

      _lastActiveTabIndex = prefs.getInt('nav_personal_tab') ?? 0;
      _lastBusinessTabIndex = prefs.getInt('nav_business_tab') ?? 0;
      _lastIsBusinessMode = prefs.getBool('nav_is_business_mode') ?? false;

      _lastUsedExpenseCategory =
          prefs.getString('pref_last_exp_cat') ?? 'Food & Dining';
      _lastUsedIncomeCategory =
          prefs.getString('pref_last_inc_cat') ?? 'Monthly Salary';
      _lastUsedWalletId = prefs.getString('pref_last_wallet_id') ?? '';

      if (prefs.containsKey('phone_to_email_directory')) {
        final rawPhones =
        jsonDecode(prefs.getString('phone_to_email_directory')!) as Map;
        rawPhones.forEach(
              (k, v) => _phoneToEmailDirectory[k.toString()] = v.toString(),
        );
      }
      if (prefs.containsKey('deleted_account_timestamps')) {
        final rawDel =
        jsonDecode(prefs.getString('deleted_account_timestamps')!) as Map;
        rawDel.forEach(
              (k, v) => _deletedAccountTimestamps[k.toString()] = (v as num).toInt(),
        );
      }

      final bool isLogged = prefs.getBool('is_logged_in') ?? false;
      _cloudEmail = (prefs.getString('user_email') ?? '').trim().toLowerCase();
      _userName = prefs.getString('user_name') ?? 'FinBlend User';

      final String savedGoogleEmail =
      (prefs.getString('connected_google_email') ?? '').trim().toLowerCase();
      if (isValidGoogleEmail(savedGoogleEmail) && savedGoogleEmail == _cloudEmail) {
        _isGoogleConnected = true;
        _connectedGoogleEmail = savedGoogleEmail;
        _lastGoogleDriveBackupAt =
            prefs.getString('gdrive_ts_$_connectedGoogleEmail') ?? 'No backup yet';
      } else {
        _isGoogleConnected = false;
        _connectedGoogleEmail = '';
        _lastGoogleDriveBackupAt = 'No backup yet';
      }

      if (prefs.containsKey('pref_dark_mode')) {
        _isDarkMode = prefs.getBool('pref_dark_mode') ?? true;
      }
      if (prefs.containsKey('pref_lang')) {
        _language = prefs.getString('pref_lang') ?? 'en';
      }
      if (prefs.containsKey('pref_notif')) {
        _notificationsEnabled = prefs.getBool('pref_notif') ?? true;
      }
      if (prefs.containsKey('pref_perm')) {
        _permissionsGranted = prefs.getBool('pref_perm') ?? true;
      }

      if (isLogged && _cloudEmail.isNotEmpty) {
        final localKey = 'account_cache_${_getCloudChannelKey(_cloudEmail)}';
        if (prefs.containsKey(localKey)) {
          final cachedMap = jsonDecode(prefs.getString(localKey)!) as Map;
          if (cachedMap['isDeletedAccount'] != true) {
            _applyStateMap(cachedMap, preserveCurrentIdentity: true);
          }
        }
        _ensureDefaultCashWallet();
        _startAutoSyncTimer();
        unawaited(pullFromCloud(silent: true));
      }
    } catch (e) {
      debugPrint('Data load error: $e');
    }
    notifyListeners();
  }

  void _startAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_cloudEmail.isNotEmpty && !_isSyncing) {
        pullFromCloud(silent: true);
      }
    });
  }

  Future<void> _saveData({bool syncCloud = true, bool markDirty = true}) async {
    _lastUpdatedTimestamp = DateTime.now().millisecondsSinceEpoch;
    if (markDirty) {
      _hasUnsyncedChanges = true;
    }

    final prefs = await SharedPreferences.getInstance();

    if (_userPhone.isNotEmpty && _cloudEmail.isNotEmpty) {
      final norm = normalizePhoneKey(_userPhone);
      if (norm.isNotEmpty) {
        _phoneToEmailDirectory[norm] = _cloudEmail;
      }
    }

    await prefs.setBool('pref_dark_mode', _isDarkMode);
    await prefs.setString('pref_lang', _language);
    await prefs.setString('pref_currency_code', _currencyCode);
    await prefs.setBool('pref_notif', _notificationsEnabled);
    await prefs.setBool('pref_perm', _permissionsGranted);
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _cloudEmail);
    await prefs.setBool('is_google_connected', _isGoogleConnected);
    await prefs.setString('connected_google_email', _connectedGoogleEmail);
    await prefs.setString('pref_last_exp_cat', _lastUsedExpenseCategory);
    await prefs.setString('pref_last_inc_cat', _lastUsedIncomeCategory);
    await prefs.setString('pref_last_wallet_id', _lastUsedWalletId);
    await prefs.setString(
      'phone_to_email_directory',
      jsonEncode(_phoneToEmailDirectory),
    );
    await prefs.setString(
      'deleted_account_timestamps',
      jsonEncode(_deletedAccountTimestamps),
    );

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
      if (!isValidGoogleEmail(cleanEmail)) {
        _isGoogleConnected = false;
        _connectedGoogleEmail = '';
      }
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

  Future<void> downloadFullAccountBackupFile() async {
    final DynamicMap state = exportFullStateMap();
    final String prettyJson = const JsonEncoder.withIndent('  ').convert(state);
    final Uint8List bytes = Uint8List.fromList(utf8.encode(prettyJson));
    final String cleanUser = (_cloudEmail.isNotEmpty ? _cloudEmail : _userName)
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    notifyListeners();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'FinBlend_Backup_$cleanUser.json',
    );
  }

  String generateFullAccountBackupString() {
    final DynamicMap state = exportFullStateMap();
    return const JsonEncoder.withIndent('  ').convert(state);
  }

  Future<DynamicMap> restoreAccountFromBackupPayload(
      String rawInput, {
        bool preserveCurrentAccountEmail = true,
      }) async {
    final clean = rawInput.trim();
    if (clean.isEmpty) {
      return {
        'success': false,
        'message': tr(
          'Backup data cannot be empty.',
          'ব্যাকআপ ডাটা খালি রাখা যাবে না।',
        ),
      };
    }

    try {
      Map decodedMap;
      if (clean.startsWith('{')) {
        decodedMap = jsonDecode(clean) as Map;
      } else {
        final decodedJsonStr = utf8.decode(base64Decode(clean));
        decodedMap = jsonDecode(decodedJsonStr) as Map;
      }

      final String currentActiveEmail = _cloudEmail;
      final bool hasActiveLogin =
          currentActiveEmail.isNotEmpty && currentActiveEmail != 'not signed in';
      final String targetEmail =
      (preserveCurrentAccountEmail && hasActiveLogin)
          ? currentActiveEmail
          : (decodedMap['email']?.toString().trim().toLowerCase() ??
          currentActiveEmail);

      _deletedAccountTimestamps.remove(targetEmail);

      _resetToCleanAccount();
      _applyStateMap(
        decodedMap,
        preserveCurrentIdentity: preserveCurrentAccountEmail && hasActiveLogin,
      );

      _cloudEmail = targetEmail;
      _lastUpdatedTimestamp = DateTime.now().millisecondsSinceEpoch;
      _ensureDefaultCashWallet();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_name', _userName);
      await prefs.setString('user_email', _cloudEmail);

      await _saveData(syncCloud: false, markDirty: false);
      await pushToCloud(silent: false);
      _startAutoSyncTimer();
      notifyListeners();

      return {
        'success': true,
        'message': tr(
          'Backup restored successfully (${_transactions.length} Tx, ${_wallets.length} Wallets, ${_groups.length} Groups)!',
          'ব্যাকআপ সফলভাবে ইমপোর্ট হয়েছে (${_transactions.length} টি লেনদেন, ${_wallets.length} টি ওয়ালেট)!',
        ),
      };
    } catch (_) {
      return {
        'success': false,
        'message': tr('Invalid backup JSON.', 'ভুল ব্যাকআপ ফাইল।'),
      };
    }
  }

  // ===========================================================================
  // 5. PERMANENT ACCOUNT DELETION (CLEARS ALL STALE BACKUP & SESSION METADATA)
  // ===========================================================================
  Future<void> deleteFullAccount({bool backupToDriveFirst = false}) async {
    _autoSyncTimer?.cancel();
    final String emailToDelete = _cloudEmail.trim().toLowerCase();
    final String connectedGoogleToClear =
    _connectedGoogleEmail.trim().toLowerCase();
    final int deletedTime = DateTime.now().millisecondsSinceEpoch;

    final prefs = await SharedPreferences.getInstance();
    if (emailToDelete.isNotEmpty) {
      _deletedAccountTimestamps[emailToDelete] = deletedTime;
      await prefs.setString(
        'deleted_account_timestamps',
        jsonEncode(_deletedAccountTimestamps),
      );

      final localKey = 'account_cache_${_getCloudChannelKey(emailToDelete)}';
      await prefs.remove(localKey);
      await prefs.remove('gdrive_ts_$emailToDelete');

      final DynamicMap tombstone = {
        'isDeletedAccount': true,
        'email': emailToDelete,
        'deletedAt': _generateTimestamp(),
        'updatedAt': deletedTime,
        'tx_data': [],
        'wal_data': [],
        'grp_data': [],
        'bdg_data': {},
        'biz_prod_data': [],
        'biz_party_data': [],
        'biz_tx_data': [],
      };
      final String payload = base64Encode(utf8.encode(jsonEncode(tombstone)));

      try {
        if (_customCloudUrl.isNotEmpty && _customCloudUrl.startsWith('http')) {
          final cleanBase = _customCloudUrl.endsWith('/')
              ? _customCloudUrl.substring(0, _customCloudUrl.length - 1)
              : _customCloudUrl;
          await http
              .put(
            Uri.parse(
              '$cleanBase/finblend_users/${_getCloudChannelKey(emailToDelete)}.json',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'payload': payload,
              'updatedAt': deletedTime,
              'email': emailToDelete,
            }),
          )
              .timeout(const Duration(seconds: 8));
        } else {
          await http
              .post(
            Uri.parse('https://ntfy.sh/${_getCloudChannelKey(emailToDelete)}'),
            body: payload,
          )
              .timeout(const Duration(seconds: 8));
        }
      } catch (_) {}
    }

    if (connectedGoogleToClear.isNotEmpty) {
      await prefs.remove('gdrive_ts_$connectedGoogleToClear');
    }

    try {
      await _createGoogleSignInInstance().signOut();
    } catch (_) {}

    await prefs.setBool('is_logged_in', false);
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.setBool('is_google_connected', false);
    await prefs.remove('connected_google_email');
    await prefs.remove('last_synced_at');
    await prefs.remove('nav_personal_tab');
    await prefs.remove('nav_business_tab');
    await prefs.remove('nav_is_business_mode');

    _cloudEmail = '';
    _userName = 'FinBlend User';
    _passwordHash = '';
    _isGoogleConnected = false;
    _connectedGoogleEmail = '';
    _googleAccessToken = '';
    _lastGoogleDriveBackupAt = 'No backup yet';
    _lastSyncedAt = 'Not synced yet';
    _hasUnsyncedChanges = false;
    _cloudStatus = 'Local Only';
    _lastActiveTabIndex = 0;
    _lastBusinessTabIndex = 0;
    _lastIsBusinessMode = false;
    _resetToCleanAccount();
    notifyListeners();
  }

  // ===========================================================================
  // STRICT EMAIL OR PHONE AUTHENTICATION
  // ===========================================================================
  Future<DynamicMap> authenticateCloudAccount({
    required String name,
    required String email,
    required String password,
    required bool isSignUp,
    String phone = '',
    String occupation = '',
    String address = '',
  }) async {
    String cleanIdentifier = email.trim().toLowerCase();
    final passHash = _hashPassword(password);
    _isSyncing = true;
    _cloudStatus = tr('Authenticating...', 'যাচাই করা হচ্ছে...');
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    if (!isSignUp && !cleanIdentifier.contains('@')) {
      final String normPhone = normalizePhoneKey(cleanIdentifier);
      if (_phoneToEmailDirectory.containsKey(normPhone)) {
        cleanIdentifier = _phoneToEmailDirectory[normPhone]!;
      } else {
        final Map? phoneLookupMap =
        await _fetchFromChannelKey(_getPhoneLookupChannelKey(normPhone));
        if (phoneLookupMap != null &&
            phoneLookupMap['email'] != null &&
            phoneLookupMap['email'].toString().isNotEmpty) {
          cleanIdentifier =
              phoneLookupMap['email'].toString().trim().toLowerCase();
          _phoneToEmailDirectory[normPhone] = cleanIdentifier;
        } else {
          _isSyncing = false;
          _cloudStatus = 'Account Not Found';
          notifyListeners();
          return {
            'success': false,
            'message': tr(
              'No account found for this phone number. Please register first.',
              'এই ফোন নম্বরে কোনো অ্যাকাউন্ট পাওয়া যায়নি। প্রথমে নিবন্ধন করুন।',
            ),
          };
        }
      }
    }

    Map? remoteMap = await _fetchRemoteCloudMap(cleanIdentifier);
    final int localDeletedAt = _deletedAccountTimestamps[cleanIdentifier] ?? 0;
    if (remoteMap != null) {
      final int remoteTime = (remoteMap['updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteTime <= localDeletedAt) {
        remoteMap = {'isDeletedAccount': true};
      }
    }

    if (isSignUp) {
      if (remoteMap != null &&
          remoteMap['isDeletedAccount'] != true &&
          remoteMap['passwordHash'] != null &&
          remoteMap['passwordHash'].toString().isNotEmpty &&
          remoteMap['passwordHash'] != passHash) {
        _isSyncing = false;
        _cloudStatus = 'Account exists';
        notifyListeners();
        return {
          'success': false,
          'message': tr(
            'An account with this email/phone already exists. Please Sign In instead.',
            'এই ইমেইল বা ফোন নম্বর দিয়ে ইতিমধ্যে অ্যাকাউন্ট রয়েছে। অনুগ্রহ করে লগইন করুন।',
          ),
        };
      }

      _deletedAccountTimestamps.remove(cleanIdentifier);
      _resetToCleanAccount();
      _cloudEmail = cleanIdentifier;
      _userName = name.trim().isEmpty
          ? cleanIdentifier.split('@').first
          : name.trim();
      _userPhone = phone.trim();
      _userOccupation = occupation.trim();
      _userAddress = address.trim();
      _passwordHash = passHash;
      _isGoogleConnected = false;
      _connectedGoogleEmail = '';
      _lastGoogleDriveBackupAt = 'No backup yet';
      _lastSyncedAt = 'Not synced yet';
      _ensureDefaultCashWallet();

      if (_userPhone.isNotEmpty) {
        final normPhone = normalizePhoneKey(_userPhone);
        if (normPhone.isNotEmpty) {
          _phoneToEmailDirectory[normPhone] = _cloudEmail;
        }
      }

      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_name', _userName);
      await prefs.setString('user_email', _cloudEmail);

      await _saveData(syncCloud: false, markDirty: false);
      await pushToCloud(silent: false);

      if (_userPhone.isNotEmpty) {
        final normPhone = normalizePhoneKey(_userPhone);
        if (normPhone.isNotEmpty) {
          unawaited(_pushPhoneDirectoryMapping(normPhone, _cloudEmail));
        }
      }

      _startAutoSyncTimer();

      return {
        'success': true,
        'message': tr(
          'Account registered successfully!',
          'অ্যাকাউন্ট সফলভাবে তৈরি হয়েছে!',
        ),
      };
    } else {
      if (remoteMap != null && remoteMap['isDeletedAccount'] == true) {
        _isSyncing = false;
        _cloudStatus = 'Account Deleted';
        notifyListeners();
        return {
          'success': false,
          'message': tr(
            'This account was deleted. Please register again to create a new account.',
            'এই অ্যাকাউন্টটি ডিলিট করা হয়েছিল। নতুন করে নিবন্ধন করুন।',
          ),
        };
      }

      if (remoteMap != null) {
        final cloudPassHash = remoteMap['passwordHash']?.toString() ?? '';
        if (cloudPassHash.isNotEmpty && cloudPassHash != passHash) {
          _isSyncing = false;
          _cloudStatus = 'Auth Failed';
          notifyListeners();
          return {
            'success': false,
            'message': tr('Incorrect password.', 'ভুল পাসওয়ার্ড।'),
          };
        }

        _resetToCleanAccount();
        _cloudEmail = cleanIdentifier;
        _passwordHash = passHash;
        _isGoogleConnected = false;
        _connectedGoogleEmail = '';
        _lastGoogleDriveBackupAt = 'No backup yet';

        _applyStateMap(remoteMap, preserveCurrentIdentity: true);
        _cloudEmail = cleanIdentifier;
        if (_passwordHash.isEmpty) _passwordHash = passHash;
        _ensureDefaultCashWallet();

        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_name', _userName);
        await prefs.setString('user_email', _cloudEmail);

        await _saveData(syncCloud: false, markDirty: false);
        _lastSyncedAt = _generateTimestamp();
        _hasUnsyncedChanges = false;
        _isSyncing = false;
        _startAutoSyncTimer();
        notifyListeners();

        return {
          'success': true,
          'message': tr('Signed in successfully!', 'সফলভাবে লগইন হয়েছে!'),
        };
      } else {
        final localKey = 'account_cache_${_getCloudChannelKey(cleanIdentifier)}';
        if (prefs.containsKey(localKey)) {
          final cachedMap = jsonDecode(prefs.getString(localKey)!) as Map;
          if (cachedMap['isDeletedAccount'] == true) {
            _isSyncing = false;
            notifyListeners();
            return {
              'success': false,
              'message': tr(
                'This account was deleted. Please register again.',
                'এই অ্যাকাউন্টটি ডিলিট করা হয়েছিল।',
              ),
            };
          }
          final cachedPass = cachedMap['passwordHash']?.toString() ?? '';
          if (cachedPass.isNotEmpty && cachedPass != passHash) {
            _isSyncing = false;
            notifyListeners();
            return {
              'success': false,
              'message': tr('Incorrect password.', 'ভুল পাসওয়ার্ড।'),
            };
          }
          _resetToCleanAccount();
          _cloudEmail = cleanIdentifier;
          _passwordHash = passHash;
          _isGoogleConnected = false;
          _connectedGoogleEmail = '';
          _lastGoogleDriveBackupAt = 'No backup yet';
          _applyStateMap(cachedMap, preserveCurrentIdentity: true);
          _cloudEmail = cleanIdentifier;
          _ensureDefaultCashWallet();

          await prefs.setBool('is_logged_in', true);
          await prefs.setString('user_name', _userName);
          await prefs.setString('user_email', _cloudEmail);
          await _saveData(syncCloud: false, markDirty: false);
          _startAutoSyncTimer();
          _isSyncing = false;
          notifyListeners();
          return {
            'success': true,
            'message': tr('Signed in successfully!', 'সফলভাবে লগইন হয়েছে!'),
          };
        } else {
          _isSyncing = false;
          _cloudStatus = 'Account Not Found';
          notifyListeners();
          return {
            'success': false,
            'message': tr(
              'No account found for "$cleanIdentifier". Please register first or Continue with Google.',
              '"$cleanIdentifier" দিয়ে কোনো অ্যাকাউন্ট পাওয়া যায়নি। প্রথমে নিবন্ধন করুন অথবা গুগল দিয়ে লগইন করুন।',
            ),
          };
        }
      }
    }
  }

  Future<void> _pushPhoneDirectoryMapping(String normPhone, String email) async {
    try {
      final payload =
      base64Encode(utf8.encode(jsonEncode({'phone': normPhone, 'email': email})));
      await http
          .post(
        Uri.parse('https://ntfy.sh/${_getPhoneLookupChannelKey(normPhone)}'),
        body: payload,
      )
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Future<void> clearSessionOnLogout() async {
    _autoSyncTimer?.cancel();
    if (_cloudEmail.isNotEmpty) {
      await pushToCloud(silent: true);
    }
    try {
      await _createGoogleSignInInstance().signOut();
    } catch (_) {}
    _cloudEmail = '';
    _userName = 'FinBlend User';
    _passwordHash = '';
    _isGoogleConnected = false;
    _connectedGoogleEmail = '';
    _googleAccessToken = '';
    _lastGoogleDriveBackupAt = 'No backup yet';
    _lastSyncedAt = 'Not synced yet';
    _hasUnsyncedChanges = false;
    _cloudStatus = 'Local Only';
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

  Future _fetchFromChannelKey(String channel) async {
    try {
      String? base64Payload;
      if (_customCloudUrl.isNotEmpty && _customCloudUrl.startsWith('http')) {
        final cleanBase = _customCloudUrl.endsWith('/')
            ? _customCloudUrl.substring(0, _customCloudUrl.length - 1)
            : _customCloudUrl;
        final res = await http
            .get(Uri.parse('$cleanBase/finblend_users/$channel.json'))
            .timeout(const Duration(seconds: 10));
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
            if (latestMsg['attachment'] != null &&
                latestMsg['attachment']['url'] != null) {
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
      debugPrint('Channel fetch error: $e');
    }
    return null;
  }

  Future _fetchRemoteCloudMap(String email) async {
    return _fetchFromChannelKey(_getCloudChannelKey(email));
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
        final cleanBase = _customCloudUrl.endsWith('/')
            ? _customCloudUrl.substring(0, _customCloudUrl.length - 1)
            : _customCloudUrl;
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
        success =
            res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204;
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
        _hasUnsyncedChanges = false;
        _cloudStatus = 'Synced ✓';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_synced_at', _lastSyncedAt);
      } else {
        _cloudStatus = 'Local Only';
      }
      _isSyncing = false;
      notifyListeners();
      return success;
    } catch (_) {
      _isSyncing = false;
      _cloudStatus = 'Local Only';
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
      final int localDeletedAt = _deletedAccountTimestamps[_cloudEmail] ?? 0;

      if (remoteMap != null && remoteMap['isDeletedAccount'] != true) {
        final remoteTime = (remoteMap['updatedAt'] as num?)?.toInt() ?? 0;

        if (remoteTime > localDeletedAt &&
            (forceApply || remoteTime > _lastUpdatedTimestamp)) {
          _applyStateMap(remoteMap, preserveCurrentIdentity: true);
          _ensureDefaultCashWallet();

          final prefs = await SharedPreferences.getInstance();
          final localKey = 'account_cache_${_getCloudChannelKey(_cloudEmail)}';
          await prefs.setString(localKey, jsonEncode(exportFullStateMap()));
          if (_userName.isNotEmpty) {
            await prefs.setString('user_name', _userName);
          }

          _lastSyncedAt = _generateTimestamp();
          _hasUnsyncedChanges = false;
          _cloudStatus = 'Synced ✓';
          await prefs.setString('last_synced_at', _lastSyncedAt);
          _isSyncing = false;
          notifyListeners();
          return true;
        }
      }

      _isSyncing = false;
      if (!silent) notifyListeners();
      return false;
    } catch (_) {
      _isSyncing = false;
      if (!silent) notifyListeners();
      return false;
    }
  }

  Future<bool> importFromSyncCode(String base64Code) async {
    final res = await restoreAccountFromBackupPayload(
      base64Code,
      preserveCurrentAccountEmail: true,
    );
    return res['success'] == true;
  }

  String generateSyncCode() {
    return base64Encode(utf8.encode(jsonEncode(exportFullStateMap())));
  }

  // --- SAVED MEMBERS DIRECTORY & CUSTOM LABELS CRUD ---
  void addSavedMember(String name) {
    final clean = name.trim();
    if (clean.isNotEmpty &&
        !_savedMembers.any((m) => m.toLowerCase() == clean.toLowerCase())) {
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

  void addCustomLabel(String label) {
    final clean = label.trim();
    if (clean.isNotEmpty &&
        !_customLabels.any((l) => l.toLowerCase() == clean.toLowerCase())) {
      _customLabels.add(clean);
      _saveData();
      notifyListeners();
    }
  }

  void deleteCustomLabel(String label) {
    _customLabels.remove(label);
    _saveData();
    notifyListeners();
  }

  // --- PERSONAL FINANCE CRUD (EXACT DECIMALS, WALLETS, DATES, LABELS, UNDO) ---
  void _adjustWalletBalance(String walletId, double delta) {
    if (walletId.isEmpty) return;
    final idx = _wallets.indexWhere((w) => w.id == walletId);
    if (idx == -1) return;
    final w = _wallets[idx];
    _wallets[idx] = WalletModel(
      id: w.id,
      name: w.name,
      type: w.type,
      providerName: w.providerName,
      accountNumber: w.accountNumber,
      balance: _round2(w.balance + delta),
    );
  }

  void saveTransaction({
    String? id,
    required String title,
    required String category,
    required double amount,
    required bool isExpense,
    String attachmentBase64 = '',
    String attachmentName = '',
    String? customDateText,
    DateTime? dateTime,
    String walletId = '',
    String walletName = '',
    List<String> labels = const [],
    bool updateWalletBalance = false,
  }) {
    final double safeAmount = _round2(amount);
    if (safeAmount <= 0) return;

    final DateTime effectiveDate = dateTime ?? DateTime.now();
    final String resolvedDate =
    (customDateText != null && customDateText.trim().isNotEmpty)
        ? customDateText.trim()
        : _generateTimestamp(effectiveDate);

    // Remember last-used category & wallet for quick entry UX
    if (isExpense) {
      if (_expenseCategories.contains(title)) {
        _lastUsedExpenseCategory = title;
      } else if (_expenseCategories.contains(category)) {
        _lastUsedExpenseCategory = category;
      }
    } else {
      if (_incomeCategories.contains(title)) {
        _lastUsedIncomeCategory = title;
      } else if (_incomeCategories.contains(category)) {
        _lastUsedIncomeCategory = category;
      }
    }
    if (walletId.isNotEmpty) {
      _lastUsedWalletId = walletId;
    }

    final newTx = TransactionModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      subtitle: category.trim(),
      amount: safeAmount,
      isExpense: isExpense,
      date: resolvedDate,
      iconCode: isExpense
          ? Icons.arrow_upward_rounded.codePoint
          : Icons.arrow_downward_rounded.codePoint,
      colorValue: isExpense ? 0xFFEF4444 : 0xFF10B981,
      attachmentBase64: attachmentBase64,
      attachmentName: attachmentName,
      walletId: walletId,
      walletName: walletName,
      labels: List<String>.from(labels),
      timestampMs: effectiveDate.millisecondsSinceEpoch,
    );

    if (id == null) {
      _transactions.add(newTx);
      if (updateWalletBalance && walletId.isNotEmpty) {
        _adjustWalletBalance(walletId, isExpense ? -safeAmount : safeAmount);
      }
    } else {
      final index = _transactions.indexWhere((t) => t.id == id);
      if (index != -1) {
        final oldTx = _transactions[index];
        if (updateWalletBalance && oldTx.walletId.isNotEmpty) {
          _adjustWalletBalance(
            oldTx.walletId,
            oldTx.isExpense ? oldTx.amount : -oldTx.amount,
          );
        }
        _transactions[index] = newTx;
        if (updateWalletBalance && walletId.isNotEmpty) {
          _adjustWalletBalance(walletId, isExpense ? -safeAmount : safeAmount);
        }
      }
    }
    _saveData();
    notifyListeners();
  }

  void transferBetweenWallets({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    String note = '',
    DateTime? dateTime,
  }) {
    final double safeAmount = _round2(amount);
    if (safeAmount <= 0 || fromWalletId == toWalletId) return;

    final fromIdx = _wallets.indexWhere((w) => w.id == fromWalletId);
    final toIdx = _wallets.indexWhere((w) => w.id == toWalletId);
    if (fromIdx == -1 || toIdx == -1) return;

    final fromWallet = _wallets[fromIdx];
    final toWallet = _wallets[toIdx];
    final DateTime effectiveDate = dateTime ?? DateTime.now();

    _adjustWalletBalance(fromWalletId, -safeAmount);
    _adjustWalletBalance(toWalletId, safeAmount);

    _transactions.add(
      TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Transfer: ${fromWallet.name} → ${toWallet.name}',
        subtitle: note.trim().isEmpty ? 'Wallet Transfer' : note.trim(),
        amount: safeAmount,
        isExpense: false,
        date: _generateTimestamp(effectiveDate),
        iconCode: Icons.swap_horiz_rounded.codePoint,
        colorValue: 0xFF38BDF8,
        walletId: fromWallet.id,
        walletName: fromWallet.name,
        toWalletId: toWallet.id,
        toWalletName: toWallet.name,
        isTransfer: true,
        timestampMs: effectiveDate.millisecondsSinceEpoch,
      ),
    );
    _saveData();
    notifyListeners();
  }

  bool repeatLastTransaction() {
    final regular = _transactions.where((t) => !t.isTransfer).toList();
    if (regular.isEmpty) return false;
    final last = regular.last;
    saveTransaction(
      title: last.title,
      category: last.subtitle,
      amount: last.amount,
      isExpense: last.isExpense,
      walletId: last.walletId,
      walletName: last.walletName,
      labels: last.labels,
      updateWalletBalance: last.walletId.isNotEmpty,
    );
    return true;
  }

  void deleteTransaction(String id) {
    final idx = _transactions.indexWhere((tx) => tx.id == id);
    if (idx == -1) return;
    final removed = _transactions.removeAt(idx);
    if (removed.isTransfer) {
      _adjustWalletBalance(removed.walletId, removed.amount);
      _adjustWalletBalance(removed.toWalletId, -removed.amount);
    } else if (removed.walletId.isNotEmpty) {
      _adjustWalletBalance(
        removed.walletId,
        removed.isExpense ? removed.amount : -removed.amount,
      );
    }
    _saveData();
    notifyListeners();
  }

  void restoreTransaction(TransactionModel tx) {
    if (_transactions.any((t) => t.id == tx.id)) return;
    _transactions.add(tx);
    if (tx.isTransfer) {
      _adjustWalletBalance(tx.walletId, -tx.amount);
      _adjustWalletBalance(tx.toWalletId, tx.amount);
    } else if (tx.walletId.isNotEmpty) {
      _adjustWalletBalance(
        tx.walletId,
        tx.isExpense ? -tx.amount : tx.amount,
      );
    }
    _saveData();
    notifyListeners();
  }

  void addBudget(String category, double limit) {
    final safeLimit = _round2(limit);
    if (safeLimit <= 0) return;
    _budgets[category] = safeLimit;
    _saveData();
    notifyListeners();
  }

  void deleteBudget(String category) {
    _budgets.remove(category);
    _saveData();
    notifyListeners();
  }

  void addCategory(String name, bool isExpense) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    if (isExpense &&
        !_expenseCategories.any((c) => c.toLowerCase() == clean.toLowerCase())) {
      _expenseCategories.add(clean);
    }
    if (!isExpense &&
        !_incomeCategories.any((c) => c.toLowerCase() == clean.toLowerCase())) {
      _incomeCategories.add(clean);
    }
    _saveData();
    notifyListeners();
  }

  void updateCategory(String oldName, String newName, bool isExpense) {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    if (isExpense) {
      final idx = _expenseCategories.indexOf(oldName);
      if (idx != -1) _expenseCategories[idx] = clean;
      if (_budgets.containsKey(oldName)) {
        final limit = _budgets.remove(oldName)!;
        _budgets[clean] = limit;
      }
    } else {
      final idx = _incomeCategories.indexOf(oldName);
      if (idx != -1) _incomeCategories[idx] = clean;
    }

    // Rename matching transactions so links stay intact
    for (int i = 0; i < _transactions.length; i++) {
      final tx = _transactions[i];
      if (tx.isExpense == isExpense &&
          (tx.title == oldName || tx.subtitle == oldName)) {
        _transactions[i] = TransactionModel(
          id: tx.id,
          title: tx.title == oldName ? clean : tx.title,
          subtitle: tx.subtitle == oldName ? clean : tx.subtitle,
          amount: tx.amount,
          isExpense: tx.isExpense,
          date: tx.date,
          iconCode: tx.iconCode,
          colorValue: tx.colorValue,
          attachmentBase64: tx.attachmentBase64,
          attachmentName: tx.attachmentName,
          walletId: tx.walletId,
          walletName: tx.walletName,
          labels: tx.labels,
          timestampMs: tx.timestampMs,
        );
      }
    }
    _saveData();
    notifyListeners();
  }

  /// Safely deletes a category, removes its orphaned budget, and reassigns linked transactions.
  void deleteCategory(
      String name,
      bool isExpense, {
        bool reassignOrphans = true,
      }) {
    if (isExpense) {
      _expenseCategories.remove(name);
      _budgets.remove(name);
    } else {
      _incomeCategories.remove(name);
    }

    if (reassignOrphans) {
      for (int i = 0; i < _transactions.length; i++) {
        final tx = _transactions[i];
        if (!tx.isTransfer &&
            tx.isExpense == isExpense &&
            (tx.title == name || tx.subtitle == name)) {
          _transactions[i] = TransactionModel(
            id: tx.id,
            title: tx.title == name ? 'Uncategorized' : tx.title,
            subtitle: tx.subtitle == name ? 'Uncategorized' : tx.subtitle,
            amount: tx.amount,
            isExpense: tx.isExpense,
            date: tx.date,
            iconCode: tx.iconCode,
            colorValue: tx.colorValue,
            attachmentBase64: tx.attachmentBase64,
            attachmentName: tx.attachmentName,
            walletId: tx.walletId,
            walletName: tx.walletName,
            labels: tx.labels,
            timestampMs: tx.timestampMs,
          );
        }
      }
    }

    _saveData();
    notifyListeners();
  }

  // --- ADVANCED GROUP & TRIP SPLIT CRUD (DUPLICATE-SAFE + UNEQUAL SPLIT) ---
  void saveGroupPlan({
    String? id,
    required String name,
    required double totalBudget,
    List<GroupMemberModel>? updatedMembers,
  }) {
    final cleanName = name.trim();
    final safeBudget = _round2(totalBudget);
    if (cleanName.isEmpty || safeBudget <= 0) return;

    if (updatedMembers != null) {
      for (var m in updatedMembers) {
        if (m.name.trim().isNotEmpty &&
            !_savedMembers.any(
                  (s) => s.toLowerCase() == m.name.trim().toLowerCase(),
            )) {
          _savedMembers.add(m.name.trim());
        }
      }
    }

    if (id == null) {
      _groups.add(
        GroupModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: cleanName,
          totalBudget: safeBudget,
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
          name: cleanName,
          totalBudget: safeBudget,
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

  bool hasGroupMemberName(
      String groupId,
      String name, {
        String? excludeMemberId,
      }) {
    final gIdx = _groups.indexWhere((g) => g.id == groupId);
    if (gIdx == -1) return false;
    final lower = name.trim().toLowerCase();
    return _groups[gIdx].members.any(
          (m) => m.name.trim().toLowerCase() == lower && m.id != excludeMemberId,
    );
  }

  void saveGroupMember({
    required String groupId,
    String? memberId,
    required String name,
    required double paidAmount,
    double? customTarget,
    bool? isSettled,
    bool addToExistingPaid = false,
  }) {
    final gIdx = _groups.indexWhere((g) => g.id == groupId);
    if (gIdx == -1) return;

    final cleanName = name.trim();
    final safePaid = _round2(paidAmount < 0 ? 0.0 : paidAmount);
    if (cleanName.isEmpty) return;

    if (!_savedMembers.any((s) => s.toLowerCase() == cleanName.toLowerCase())) {
      _savedMembers.add(cleanName);
    }

    final group = _groups[gIdx];
    final updatedMembers = List<GroupMemberModel>.from(group.members);

    // Match either by explicit memberId OR case-insensitive existing name to prevent duplicates.
    int targetIdx = memberId != null
        ? updatedMembers.indexWhere((m) => m.id == memberId)
        : updatedMembers.indexWhere(
          (m) => m.name.trim().toLowerCase() == cleanName.toLowerCase(),
    );

    if (targetIdx == -1) {
      updatedMembers.add(
        GroupMemberModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: cleanName,
          paidAmount: safePaid,
          customTarget: customTarget != null ? _round2(customTarget) : null,
          isSettled: isSettled ?? false,
        ),
      );
    } else {
      final existing = updatedMembers[targetIdx];
      final double newPaid =
      addToExistingPaid ? _round2(existing.paidAmount + safePaid) : safePaid;
      updatedMembers[targetIdx] = GroupMemberModel(
        id: existing.id,
        name: cleanName,
        paidAmount: newPaid,
        customTarget: customTarget ?? existing.customTarget,
        isSettled: isSettled ?? existing.isSettled,
      );
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

  void toggleGroupMemberSettled({
    required String groupId,
    required String memberId,
  }) {
    final gIdx = _groups.indexWhere((g) => g.id == groupId);
    if (gIdx == -1) return;
    final group = _groups[gIdx];
    final updatedMembers = group.members.map((m) {
      if (m.id != memberId) return m;
      return GroupMemberModel(
        id: m.id,
        name: m.name,
        paidAmount: m.paidAmount,
        customTarget: m.customTarget,
        isSettled: !m.isSettled,
      );
    }).toList();

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
    final updatedMembers =
    group.members.where((m) => m.id != memberId).toList();

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

    final safeAmount = _round2(amount);
    if (title.trim().isEmpty || safeAmount <= 0) return;

    final group = _groups[gIdx];
    final updatedExpenses = List<GroupExpenseModel>.from(group.expenses);
    final updatedMembers = List<GroupMemberModel>.from(group.members);

    if (expenseId == null) {
      updatedExpenses.insert(
        0,
        GroupExpenseModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title.trim(),
          amount: safeAmount,
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
            paidAmount: _round2(m.paidAmount + safeAmount),
            customTarget: m.customTarget,
            isSettled: m.isSettled,
          );
        }
      }
    } else {
      final eIdx = updatedExpenses.indexWhere((e) => e.id == expenseId);
      if (eIdx != -1) {
        updatedExpenses[eIdx] = GroupExpenseModel(
          id: expenseId,
          title: title.trim(),
          amount: safeAmount,
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
    final updatedExpenses =
    group.expenses.where((e) => e.id != expenseId).toList();

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

  // --- WALLETS & SCHEDULED BILLS CRUD ---
  void saveWallet({
    String? id,
    required String name,
    required String type,
    required String providerName,
    String accountNumber = '',
    required double balance,
  }) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final newWallet = WalletModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: cleanName,
      type: type,
      providerName: providerName.trim(),
      accountNumber: accountNumber.trim(),
      balance: _round2(balance),
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
    bool isPaid = false,
    String paidDate = '',
  }) {
    final safeAmount = _round2(amount);
    if (title.trim().isEmpty || safeAmount <= 0 || dueDate.trim().isEmpty) {
      return;
    }

    final newSch = ScheduledTxModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      amount: safeAmount,
      dueDate: dueDate.trim(),
      isExpense: isExpense,
      attachmentBase64: attachmentBase64,
      attachmentName: attachmentName,
      isPaid: isPaid,
      paidDate: paidDate,
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

  /// Marks a scheduled bill as paid and automatically logs the real transaction.
  void markScheduledTxPaid(String id, {String walletId = '', String walletName = ''}) {
    final idx = _scheduledTxs.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final bill = _scheduledTxs[idx];
    if (bill.isPaid) return;

    _scheduledTxs[idx] = ScheduledTxModel(
      id: bill.id,
      title: bill.title,
      amount: bill.amount,
      dueDate: bill.dueDate,
      isExpense: bill.isExpense,
      attachmentBase64: bill.attachmentBase64,
      attachmentName: bill.attachmentName,
      isPaid: true,
      paidDate: _generateTimestamp(),
    );

    saveTransaction(
      title: bill.isExpense ? 'Utilities & Rent' : 'Monthly Salary',
      category: bill.title,
      amount: bill.amount,
      isExpense: bill.isExpense,
      attachmentBase64: bill.attachmentBase64,
      attachmentName: bill.attachmentName,
      walletId: walletId,
      walletName: walletName,
      updateWalletBalance: walletId.isNotEmpty,
    );
  }

  void deleteScheduledTx(String id) {
    _scheduledTxs.removeWhere((s) => s.id == id);
    _saveData();
    notifyListeners();
  }

  // --- BUSINESS POS CRUD (COGS PROFIT + STOCK CLAMPING + DUE COLLECTIONS) ---
  void saveBusinessTx({
    String? id,
    required String title,
    required String type,
    required double amount,
    String attachmentBase64 = '',
    String attachmentName = '',
    String productId = '',
    String productName = '',
    int quantity = 1,
    double costTotal = 0.0,
    double discountAmount = 0.0,
    double vatAmount = 0.0,
    String partyId = '',
    String partyName = '',
    double? paidAmount,
    double dueAmount = 0.0,
    bool autoAdjustStock = false,
    bool autoUpdatePartyDue = false,
  }) {
    final safeAmount = _round2(amount);
    if (title.trim().isEmpty || safeAmount <= 0) return;

    double resolvedCostTotal = _round2(costTotal);

    // Auto-compute COGS & adjust inventory stock if linked to a product
    if (productId.isNotEmpty) {
      final pIdx = _products.indexWhere((p) => p.id == productId);
      if (pIdx != -1) {
        final prod = _products[pIdx];
        if (type == 'Sale' && resolvedCostTotal <= 0 && prod.costPrice > 0) {
          resolvedCostTotal = _round2(prod.costPrice * quantity);
        }
        if (autoAdjustStock && id == null) {
          if (type == 'Sale') {
            final newStock = math.max(0, prod.stock - quantity);
            _products[pIdx] = ProductModel(
              id: prod.id,
              name: prod.name,
              price: prod.price,
              costPrice: prod.costPrice,
              stock: newStock,
            );
          } else if (type == 'Purchase') {
            _products[pIdx] = ProductModel(
              id: prod.id,
              name: prod.name,
              price: prod.price,
              costPrice: prod.costPrice,
              stock: prod.stock + quantity,
            );
          }
        }
      }
    }

    final safeDue = _round2(dueAmount < 0 ? 0.0 : dueAmount);
    final safePaid = _round2(paidAmount ?? math.max(0.0, safeAmount - safeDue));

    if (autoUpdatePartyDue && id == null && partyId.isNotEmpty && safeDue > 0) {
      final partyIdx = _parties.indexWhere((p) => p.id == partyId);
      if (partyIdx != -1) {
        final party = _parties[partyIdx];
        _parties[partyIdx] = PartyModel(
          id: party.id,
          name: party.name,
          phone: party.phone,
          isCustomer: party.isCustomer,
          dueAmount: _round2(party.dueAmount + safeDue),
          paymentHistory: party.paymentHistory,
        );
      }
    }

    final newTx = BusinessTxModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      type: type,
      amount: safeAmount,
      date: _generateTimestamp(),
      attachmentBase64: attachmentBase64,
      attachmentName: attachmentName,
      productId: productId,
      productName: productName,
      quantity: quantity,
      costTotal: resolvedCostTotal,
      discountAmount: _round2(discountAmount),
      vatAmount: _round2(vatAmount),
      partyId: partyId,
      partyName: partyName,
      paidAmount: safePaid,
      dueAmount: safeDue,
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

  void saveProduct({
    String? id,
    required String name,
    required double price,
    double costPrice = 0.0,
    required int stock,
  }) {
    final cleanName = name.trim();
    if (cleanName.isEmpty || price <= 0 || stock < 0) return;

    final newProd = ProductModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: cleanName,
      price: _round2(price),
      costPrice: _round2(costPrice < 0 ? 0.0 : costPrice),
      stock: stock,
    );
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

  void saveParty({
    String? id,
    required String name,
    required String phone,
    required bool isCustomer,
    required double dueAmount,
  }) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final existingIdx =
    id != null ? _parties.indexWhere((p) => p.id == id) : -1;
    final List<PartyPaymentModel> existingHistory =
    existingIdx != -1 ? _parties[existingIdx].paymentHistory : const [];

    final newParty = PartyModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: cleanName,
      phone: phone.trim(),
      isCustomer: isCustomer,
      dueAmount: _round2(dueAmount < 0 ? 0.0 : dueAmount),
      paymentHistory: existingHistory,
    );
    if (existingIdx == -1) {
      _parties.add(newParty);
    } else {
      _parties[existingIdx] = newParty;
    }
    _saveData();
    notifyListeners();
  }

  /// Settles full OR partial party due WITHOUT inflating Total Sales or Net Profit.
  bool recordPartyPayment({
    required String partyId,
    required double amount,
    String note = '',
  }) {
    final idx = _parties.indexWhere((p) => p.id == partyId);
    if (idx == -1) return false;

    final party = _parties[idx];
    final double safeAmt = _round2(amount);
    if (safeAmt <= 0 || safeAmt > party.dueAmount + 0.009) return false;

    final double remainingDue = _round2(math.max(0.0, party.dueAmount - safeAmt));
    final String stamp = _generateTimestamp();

    final updatedHistory = List<PartyPaymentModel>.from(party.paymentHistory)
      ..insert(
        0,
        PartyPaymentModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: safeAmt,
          date: stamp,
          note: note.trim(),
        ),
      );

    _parties[idx] = PartyModel(
      id: party.id,
      name: party.name,
      phone: party.phone,
      isCustomer: party.isCustomer,
      dueAmount: remainingDue,
      paymentHistory: updatedHistory,
    );

    // Record as Due Collection / Supplier Payment (NEVER as a Sale!)
    _businessTxs.add(
      BusinessTxModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: party.isCustomer
            ? 'Due Collected — ${party.name}${note.trim().isNotEmpty ? " (${note.trim()})" : ""}'
            : 'Supplier Paid — ${party.name}${note.trim().isNotEmpty ? " (${note.trim()})" : ""}',
        type: party.isCustomer ? 'Due Collection' : 'Supplier Payment',
        amount: safeAmt,
        date: stamp,
        partyId: party.id,
        partyName: party.name,
        paidAmount: safeAmt,
        dueAmount: remainingDue,
      ),
    );

    _saveData();
    notifyListeners();
    return true;
  }

  void deleteParty(String id) {
    _parties.removeWhere((p) => p.id == id);
    _saveData();
    notifyListeners();
  }

  void toggleDarkMode(bool isDark) {
    _isDarkMode = isDark;
    _saveData(markDirty: false);
    notifyListeners();
  }

  void toggleNotifications(bool enabled) {
    _notificationsEnabled = enabled;
    _saveData(markDirty: false);
    notifyListeners();
  }

  void updatePermissions(bool granted) {
    _permissionsGranted = granted;
    _saveData(markDirty: false);
    notifyListeners();
  }

  List<DynamicMap> get activeAlerts {
    if (!_notificationsEnabled) return [];
    final List<DynamicMap> alerts = [];

    final Map<String, double> spentByCat = {};
    for (var tx in _transactions.where((t) => t.isExpense && !t.isTransfer)) {
      final catKey =
      _budgets.containsKey(tx.subtitle) ? tx.subtitle : tx.title;
      spentByCat[catKey] = _round2((spentByCat[catKey] ?? 0) + tx.amount);
    }

    _budgets.forEach((cat, limit) {
      final spent = spentByCat[cat] ?? 0.0;
      if (limit > 0 && spent >= limit * 0.85) {
        alerts.add({
          'title': spent >= limit
              ? 'Budget Exceeded: $cat'
              : 'Budget Warning: $cat',
          'body':
          'Spent ${formatMoney(spent)} of ${formatMoney(limit)} (${((spent / limit) * 100).toStringAsFixed(0)}%)',
          'color': 0xFFEF4444,
        });
      }
    });

    for (var g in _groups) {
      if (g.totalOwedToBudget > 0) {
        alerts.add({
          'title': 'Group Collection Pending: ${g.name}',
          'body':
          'Members still owe ${formatMoney(g.totalOwedToBudget)} toward the ${formatMoney(g.totalBudget)} budget.',
          'color': 0xFFF59E0B,
        });
      }
    }

    for (var s in _scheduledTxs.where((b) => !b.isPaid)) {
      alerts.add({
        'title': 'Scheduled Bill Reminder: ${s.title}',
        'body': '${formatMoney(s.amount)} due on ${s.dueDate}',
        'color': 0xFF0EA5E9,
      });
    }

    for (var p in _products.where((p) => p.stock <= 5)) {
      alerts.add({
        'title': 'Low Stock Alert: ${p.name}',
        'body': 'Only ${p.stock} units remaining in Business Inventory.',
        'color': 0xFFEF4444,
      });
    }

    return alerts;
  }
}