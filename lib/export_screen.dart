import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'core/widgets/app_feedback.dart';
import 'providers/transaction_provider.dart';

class ExportScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const ExportScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final GlobalKey _statementBoundaryKey = GlobalKey();
  bool _isExporting = false;
  bool _isDriveBusy = false;
  String _driveStatusText = '';
  String _exportScope = 'All'; // 'All', 'Personal Only', 'Business POS Only'

  String _csvEscape(String value) {
    final cleaned = value.replaceAll('\r\n', ' ').replaceAll('\n', ' ');
    if (cleaned.contains(',') || cleaned.contains('"')) {
      return '"${cleaned.replaceAll('"', '""')}"';
    }
    return cleaned;
  }

  Future<void> _exportCsvSpreadsheet(TransactionProvider provider) async {
    setState(() => _isExporting = true);
    try {
      final buffer = StringBuffer();
      final String code = provider.currencyCode;
      buffer.writeln(
        'Scope,Date,Type,Category / Title,Description / Party,Wallet,Labels,Amount ($code),COGS ($code),Due ($code),Receipt',
      );

      if (_exportScope != 'Business POS Only') {
        for (final tx in provider.transactions) {
          final String typeLabel = tx.isTransfer
              ? 'Transfer'
              : (tx.isExpense ? 'Expense' : 'Income');
          final double signedAmt =
          tx.isTransfer ? tx.amount : (tx.isExpense ? -tx.amount : tx.amount);
          buffer.writeln(
            [
              'Personal',
              _csvEscape(tx.date),
              typeLabel,
              _csvEscape(tx.title),
              _csvEscape(tx.subtitle),
              _csvEscape(tx.walletName),
              _csvEscape(tx.labels.join('; ')),
              signedAmt.toStringAsFixed(2),
              '0.00',
              '0.00',
              _csvEscape(tx.hasAttachment ? tx.attachmentName : ''),
            ].join(','),
          );
        }
      }

      if (_exportScope != 'Personal Only') {
        for (final b in provider.businessTxs) {
          buffer.writeln(
            [
              'Business POS',
              _csvEscape(b.date),
              _csvEscape(b.type),
              _csvEscape(b.title),
              _csvEscape(b.partyName),
              '',
              '',
              b.amount.toStringAsFixed(2),
              b.costTotal.toStringAsFixed(2),
              b.dueAmount.toStringAsFixed(2),
              _csvEscape(b.hasAttachment ? b.attachmentName : ''),
            ].join(','),
          );
        }
      }

      final Uint8List csvBytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      final String scopeSlug = _exportScope == 'All'
          ? 'All'
          : (_exportScope == 'Personal Only' ? 'Personal' : 'POS');

      await Printing.sharePdf(
        bytes: csvBytes,
        filename:
        'FinBlend_${scopeSlug}_Ledger_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'CSV Export Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdfStatement(TransactionProvider provider) async {
    setState(() => _isExporting = true);
    try {
      final doc = pw.Document();
      final String code = provider.currencyCode;
      final double netWorth =
          provider.totalBalance + provider.totalWalletsBalance;
      final int personalReceipts =
          provider.transactions.where((t) => t.hasAttachment).length;
      final int posReceipts =
          provider.businessTxs.where((t) => t.hasAttachment).length;
      final int scopedReceipts = _exportScope == 'Personal Only'
          ? personalReceipts
          : (_exportScope == 'Business POS Only'
          ? posReceipts
          : personalReceipts + posReceipts);

      String pdfMoney(double v) => '$code ${v.toStringAsFixed(2)}';

      List<String> summaryHeaders;
      List<String> summaryRow;

      if (_exportScope == 'Personal Only') {
        summaryHeaders = ['Net Worth', 'Income', 'Expense', 'Wallets'];
        summaryRow = [
          pdfMoney(netWorth),
          pdfMoney(provider.totalIncome),
          pdfMoney(provider.totalExpense),
          pdfMoney(provider.totalWalletsBalance),
        ];
      } else if (_exportScope == 'Business POS Only') {
        summaryHeaders = [
          'POS Sales',
          'COGS',
          'POS Expenses',
          'Net Profit',
          'Customer Due',
          'Supplier Due',
        ];
        summaryRow = [
          pdfMoney(provider.totalSales),
          pdfMoney(provider.totalCOGS),
          pdfMoney(provider.totalBizExpenses),
          pdfMoney(provider.netProfit),
          pdfMoney(provider.totalCustomerDue),
          pdfMoney(provider.totalSupplierDue),
        ];
      } else {
        summaryHeaders = [
          'Net Worth',
          'Income',
          'Expense',
          'Wallets',
          'POS Sales',
          'POS Profit',
        ];
        summaryRow = [
          pdfMoney(netWorth),
          pdfMoney(provider.totalIncome),
          pdfMoney(provider.totalExpense),
          pdfMoney(provider.totalWalletsBalance),
          pdfMoney(provider.totalSales),
          pdfMoney(provider.netProfit),
        ];
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (_) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FINBLEND FINANCIAL STATEMENT',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${provider.userName} (${provider.cloudEmail})',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Scope: $_exportScope',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Receipts: $scopedReceipts',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(height: 22),
            pw.Text(
              '1. Financial Summary',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: summaryHeaders,
              data: [summaryRow],
            ),
            pw.SizedBox(height: 18),
            if (_exportScope != 'Business POS Only') ...[
              pw.Text(
                '2. Personal Transactions (${provider.transactions.length})',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              if (provider.transactions.isEmpty)
                pw.Text(
                  'No personal transactions recorded.',
                  style: const pw.TextStyle(fontSize: 10),
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Category', 'Memo', 'Wallet', 'Date', 'Amount'],
                  data: provider.transactions.take(40).map((tx) {
                    final String sign =
                    tx.isTransfer ? '' : (tx.isExpense ? '-' : '+');
                    return [
                      tx.title,
                      tx.subtitle,
                      tx.walletName.isEmpty ? '-' : tx.walletName,
                      tx.date,
                      '$sign${pdfMoney(tx.amount)}',
                    ];
                  }).toList(),
                ),
              pw.SizedBox(height: 18),
            ],
            if (_exportScope != 'Personal Only') ...[
              pw.Text(
                '${_exportScope == "Business POS Only" ? "2" : "3"}. Business POS Vouchers (${provider.businessTxs.length})',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              if (provider.businessTxs.isEmpty)
                pw.Text(
                  'No POS transactions recorded.',
                  style: const pw.TextStyle(fontSize: 10),
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Title', 'Type', 'Party', 'Date', 'Amount'],
                  data: provider.businessTxs.take(40).map((b) {
                    return [
                      b.title,
                      b.type,
                      b.partyName.isEmpty ? '-' : b.partyName,
                      b.date,
                      pdfMoney(b.amount),
                    ];
                  }).toList(),
                ),
            ],
          ],
        ),
      );

      final Uint8List pdfBytes = await doc.save();
      final String scopeSlug = _exportScope == 'All'
          ? 'All'
          : (_exportScope == 'Personal Only' ? 'Personal' : 'POS');
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
        'FinBlend_${scopeSlug}_Statement_${provider.userName.replaceAll(" ", "_")}.pdf',
      );
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'PDF Export Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportImageStatement({required bool asJpg}) async {
    setState(() => _isExporting = true);
    try {
      final RenderRepaintBoundary? boundary = _statementBoundaryKey
          .currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isExporting = false);
        return;
      }

      final ui.Image capturedImage = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData =
      await capturedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() => _isExporting = false);
        return;
      }

      Uint8List outputBytes = byteData.buffer.asUint8List();
      String ext = 'png';

      if (asJpg) {
        final decoded = img.decodeImage(outputBytes);
        if (decoded != null) {
          outputBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
          ext = 'jpg';
        }
      }

      final String scopeSlug = _exportScope == 'All'
          ? 'All'
          : (_exportScope == 'Personal Only' ? 'Personal' : 'POS');

      await Printing.sharePdf(
        bytes: outputBytes,
        filename:
        'FinBlend_${scopeSlug}_Statement_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Image Export Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showMinimalRestoreSheet(
      BuildContext context,
      TransactionProvider provider,
      ) {
    final jsonBackupCtrl = TextEditingController();
    bool preserveCurrentLogin = true;
    bool isWorking = false;
    String workingMessage = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      provider.tr(
                        'Restore Account Data',
                        'অ্যাকাউন্ট ব্যাকআপ রিস্টোর',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: isWorking ? null : () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFF10B981),
                  title: Text(
                    provider.tr(
                      'Import into current account (${provider.cloudEmail})',
                      'বর্তমান অ্যাকাউন্টে (${provider.cloudEmail}) ইমপোর্ট করুন',
                    ),
                    style:
                    const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                  ),
                  value: preserveCurrentLogin,
                  onChanged: isWorking
                      ? null
                      : (v) => setSheetState(() => preserveCurrentLogin = v),
                ),

                if (isWorking) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            workingMessage,
                            style: const TextStyle(
                              color: Color(0xFFE0F2FE),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // 1. GOOGLE DRIVE RESTORE
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.add_to_drive_rounded,
                            color: Color(0xFF38BDF8),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              provider.isGoogleConnected
                                  ? '${provider.tr("Google Drive", "গুগল ড্রাইভ")}: ${provider.connectedGoogleEmail}'
                                  : provider.tr(
                                'Google Drive (Requires Device Google Account Permission)',
                                'গুগল ড্রাইভ (ডিভাইসের গুগল অ্যাকাউন্টের অনুমতি প্রয়োজন)',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isWorking
                            ? null
                            : () async {
                          setSheetState(() {
                            isWorking = true;
                            workingMessage = provider.tr(
                              'Restoring backup from Google Drive...',
                              'গুগল ড্রাইভ থেকে ব্যাকআপ রিস্টোর হচ্ছে...',
                            );
                          });
                          final res = await provider
                              .restoreFullAccountFromGoogleDrive(
                            preserveCurrentAccountEmail:
                            preserveCurrentLogin,
                          );
                          if (ctx.mounted) {
                            setSheetState(() => isWorking = false);
                            if (res['success'] == true) {
                              Navigator.pop(ctx);
                            }
                          }
                          if (mounted) {
                            if (res['success'] == true) {
                              AppFeedback.showInfo(
                                this.context,
                                res['message']?.toString() ?? '',
                              );
                            } else {
                              AppFeedback.showError(
                                this.context,
                                res['message']?.toString() ?? '',
                              );
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.cloud_download_outlined,
                          size: 18,
                        ),
                        label: Text(
                          provider.tr(
                            'Select Google Account & Restore from Drive',
                            'গুগল অ্যাকাউন্ট নির্বাচন করে ড্রাইভ থেকে রিস্টোর',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. PASTE EXPORTED .JSON BACKUP CONTENT
                TextField(
                  controller: jsonBackupCtrl,
                  enabled: !isWorking,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: provider.tr(
                      'Or paste exported .JSON backup content here...',
                      'অথবা এক্সপোর্ট করা .JSON ফাইল এখানে পেস্ট করুন...',
                    ),
                    hintStyle: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.paste_rounded,
                        color: Color(0xFF38BDF8),
                        size: 18,
                      ),
                      onPressed: isWorking
                          ? null
                          : () async {
                        final data =
                        await Clipboard.getData('text/plain');
                        if (data?.text != null && ctx.mounted) {
                          setSheetState(
                                () => jsonBackupCtrl.text = data!.text!,
                          );
                        }
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isWorking
                      ? null
                      : () async {
                    if (jsonBackupCtrl.text.trim().isEmpty) {
                      AppFeedback.showError(
                        this.context,
                        provider.tr(
                          'Paste valid backup JSON first.',
                          'আগে সঠিক ব্যাকআপ JSON পেস্ট করুন।',
                        ),
                      );
                      return;
                    }
                    setSheetState(() {
                      isWorking = true;
                      workingMessage = provider.tr(
                        'Importing JSON backup...',
                        'JSON ব্যাকআপ ইমপোর্ট হচ্ছে...',
                      );
                    });
                    final res =
                    await provider.restoreAccountFromBackupPayload(
                      jsonBackupCtrl.text,
                      preserveCurrentAccountEmail: preserveCurrentLogin,
                    );
                    if (ctx.mounted) {
                      setSheetState(() => isWorking = false);
                      if (res['success'] == true) {
                        Navigator.pop(ctx);
                      }
                    }
                    if (mounted) {
                      if (res['success'] == true) {
                        AppFeedback.showInfo(
                          this.context,
                          res['message']?.toString() ?? '',
                        );
                      } else {
                        AppFeedback.showError(
                          this.context,
                          res['message']?.toString() ?? '',
                        );
                      }
                    }
                  },
                  child: Text(
                    provider.tr('Import .JSON Backup', '.JSON ব্যাকআপ ইমপোর্ট'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final double netWorth =
        provider.totalBalance + provider.totalWalletsBalance;
    final int personalReceipts =
        provider.transactions.where((t) => t.hasAttachment).length;
    final int posReceipts =
        provider.businessTxs.where((t) => t.hasAttachment).length;
    final int scopedReceipts = _exportScope == 'Personal Only'
        ? personalReceipts
        : (_exportScope == 'Business POS Only'
        ? posReceipts
        : personalReceipts + posReceipts);
    final int totalTxCount =
        provider.transactions.length + provider.businessTxs.length;

    // Build scope-aware preview chart data (strictly reflects All / Personal / POS!)
    late final List<double> chartValues;
    late final List<Color> chartColors;
    late final List<String> chartLabels;
    late final String chartCenterTitle;
    late final String chartCenterValue;

    if (_exportScope == 'Personal Only') {
      chartValues = [
        provider.totalIncome,
        provider.totalExpense,
        provider.totalWalletsBalance > 0 ? provider.totalWalletsBalance : 0.0,
      ];
      chartColors = const [
        Color(0xFF10B981),
        Color(0xFFEF4444),
        Color(0xFF0EA5E9),
      ];
      chartLabels = [
        '${provider.tr("Income", "আয়")} (${provider.formatMoney(provider.totalIncome)})',
        '${provider.tr("Expense", "ব্যয়")} (${provider.formatMoney(provider.totalExpense)})',
        '${provider.tr("Wallets", "ওয়ালেট")} (${provider.formatMoney(provider.totalWalletsBalance)})',
      ];
      chartCenterTitle = provider.tr('Net Worth', 'মোট সম্পদ');
      chartCenterValue = provider.formatMoney(netWorth);
    } else if (_exportScope == 'Business POS Only') {
      chartValues = [
        provider.totalSales,
        provider.totalCOGS,
        provider.totalBizExpenses,
      ];
      chartColors = const [
        Color(0xFF10B981),
        Color(0xFFF59E0B),
        Color(0xFFEF4444),
      ];
      chartLabels = [
        '${provider.tr("POS Sales", "বিক্রয়")} (${provider.formatMoney(provider.totalSales)})',
        '${provider.tr("COGS", "ক্রয়মূল্য")} (${provider.formatMoney(provider.totalCOGS)})',
        '${provider.tr("POS Expense", "ব্যয়")} (${provider.formatMoney(provider.totalBizExpenses)})',
      ];
      chartCenterTitle = provider.tr('POS Profit', 'নিট লাভ');
      chartCenterValue = provider.formatMoney(provider.netProfit);
    } else {
      chartValues = [
        provider.totalIncome,
        provider.totalExpense,
        provider.totalWalletsBalance > 0 ? provider.totalWalletsBalance : 0.0,
        provider.totalSales,
      ];
      chartColors = const [
        Color(0xFF10B981),
        Color(0xFFEF4444),
        Color(0xFF0EA5E9),
        Color(0xFFF59E0B),
      ];
      chartLabels = [
        '${provider.tr("Income", "আয়")} (${provider.formatMoney(provider.totalIncome)})',
        '${provider.tr("Expense", "ব্যয়")} (${provider.formatMoney(provider.totalExpense)})',
        '${provider.tr("Wallets", "ওয়ালেট")} (${provider.formatMoney(provider.totalWalletsBalance)})',
        '${provider.tr("POS Sales", "পিওএস")} (${provider.formatMoney(provider.totalSales)})',
      ];
      chartCenterTitle = provider.tr('Net Worth', 'মোট সম্পদ');
      chartCenterValue = provider.formatMoney(netWorth);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          provider.tr(
            'Backup & Statement Export',
            'ব্যাকআপ ও স্টেটমেন্ট এক্সপোর্ট',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          Padding(
            padding:
            const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => provider.toggleLanguage(),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                alignment: Alignment.center,
                child: Text(
                  provider.isBengali ? 'EN' : 'বাংলা',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // 1. FULL ACCOUNT BACKUP & GOOGLE DRIVE CARD
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                            const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_to_drive_rounded,
                            color: Color(0xFF38BDF8),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.tr(
                                  'Full Account Backup',
                                  'সম্পূর্ণ অ্যাকাউন্ট ব্যাকআপ',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                provider.isGoogleConnected
                                    ? 'Google Drive: ${provider.connectedGoogleEmail} • ${provider.lastGoogleDriveBackupAt}'
                                    : provider.tr(
                                  'Google Drive: Not connected (Tap Drive Backup to authorize)',
                                  'গুগল ড্রাইভ: সংযুক্ত নয় (অনুমতি দিতে Drive Backup চাপুন)',
                                ),
                                style: TextStyle(
                                  color: provider.isGoogleConnected
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_isDriveBusy || provider.isSyncing) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                          const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                            const Color(0xFF38BDF8).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _driveStatusText.isNotEmpty
                                    ? _driveStatusText
                                    : provider.cloudStatus,
                                style: const TextStyle(
                                  color: Color(0xFFE0F2FE),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // NON-TRUNCATING 2x2 METADATA PILLS (NO "0 Wallets • 0 Gro...")
                    Row(
                      children: [
                        Expanded(
                          child: _buildMinimalPill(
                            Icons.person_outline,
                            provider.tr('Profile', 'প্রোফাইল'),
                            provider.userName,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMinimalPill(
                            Icons.swap_vert_rounded,
                            provider.tr('Total Entries', 'মোট লেনদেন'),
                            '$totalTxCount Tx',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMinimalPill(
                            Icons.account_balance_wallet_outlined,
                            provider.tr('Wallets', 'ওয়ালেট'),
                            '${provider.wallets.length} ${provider.tr(provider.wallets.length == 1 ? "Wallet" : "Wallets", "টি")}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMinimalPill(
                            Icons.group_outlined,
                            provider.tr('Groups', 'গ্রুপ'),
                            '${provider.groups.length} ${provider.tr(provider.groups.length == 1 ? "Group" : "Groups", "টি")}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: (_isDriveBusy || provider.isSyncing)
                                ? null
                                : () async {
                              setState(() {
                                _isDriveBusy = true;
                                _driveStatusText = provider.tr(
                                  'Uploading backup to Google Drive...',
                                  'গুগল ড্রাইভে ব্যাকআপ আপলোড হচ্ছে...',
                                );
                              });
                              final res = await provider
                                  .backupFullAccountToGoogleDrive();
                              if (!context.mounted) return;
                              setState(() {
                                _isDriveBusy = false;
                                _driveStatusText = '';
                              });
                              if (res['success'] == true) {
                                AppFeedback.showInfo(
                                  context,
                                  res['message']?.toString() ?? '',
                                );
                              } else {
                                AppFeedback.showError(
                                  context,
                                  res['message']?.toString() ?? '',
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.cloud_upload_outlined,
                              size: 16,
                            ),
                            label: Text(
                              provider.tr('Drive Backup', 'ড্রাইভ ব্যাকআপ'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () =>
                                provider.downloadFullAccountBackupFile(),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: Text(
                              provider.tr('Export .JSON', 'ফাইল (.JSON)'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF59E0B),
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () =>
                                _showMinimalRestoreSheet(context, provider),
                            icon: const Icon(Icons.restore_rounded, size: 16),
                            label: Text(
                              provider.tr('Restore', 'রিস্টোর'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. STATEMENT FILTER & EXPORT TOOLBAR (PDF, CSV, PNG, JPG)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      provider.tr('Financial Statement', 'আর্থিক বিবরণী'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: ['All', 'Personal Only', 'Business POS Only']
                        .map((scope) {
                      final isSel = _exportScope == scope;
                      final shortLabel = scope == 'All'
                          ? 'All'
                          : (scope == 'Personal Only' ? 'Personal' : 'POS');
                      return ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          shortLabel,
                          style: TextStyle(
                            color:
                            isSel ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: const Color(0xFF0EA5E9),
                        backgroundColor: const Color(0xFF1E293B),
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => _exportScope = scope),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isExporting
                          ? null
                          : () => _exportPdfStatement(provider),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text(
                        'PDF',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isExporting
                          ? null
                          : () => _exportCsvSpreadsheet(provider),
                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                      label: const Text(
                        'CSV',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isExporting
                          ? null
                          : () => _exportImageStatement(asJpg: false),
                      icon: const Icon(Icons.image_outlined, size: 16),
                      label: const Text(
                        'PNG',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isExporting
                          ? null
                          : () => _exportImageStatement(asJpg: true),
                      icon: const Icon(
                        Icons.photo_camera_back_outlined,
                        size: 16,
                      ),
                      label: const Text(
                        'JPG',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. SCOPE-FILTERED STATEMENT PREVIEW CARD (ZERO-SAFE CHART)
              RepaintBoundary(
                key: _statementBoundaryKey,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${provider.cloudEmail} • $_exportScope',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border:
                              Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Text(
                              '$scopedReceipts ${provider.tr(scopedReceipts == 1 ? "Receipt" : "Receipts", "রসিদ")}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.0),
                        child: Divider(color: Color(0xFF334155), height: 1),
                      ),
                      RealisticDonutChart(
                        values: chartValues,
                        colors: chartColors,
                        labels: chartLabels,
                        centerTitle: chartCenterTitle,
                        centerValue: chartCenterValue,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.0),
                        child: Divider(color: Color(0xFF334155), height: 1),
                      ),
                      ..._buildScopedPreviewRows(provider),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildScopedPreviewRows(TransactionProvider provider) {
    final List<Widget> rows = [];

    if (_exportScope != 'Business POS Only') {
      if (provider.transactions.isNotEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              provider.tr('Recent Personal Entries', 'সাম্প্রতিক ব্যক্তিগত লেনদেন'),
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        for (final tx in provider.transactions.take(5)) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tx.title,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tx.isTransfer
                        ? provider.formatMoney(tx.amount)
                        : provider.formatMoney(
                      tx.isExpense ? -tx.amount : tx.amount,
                      showPlusSign: !tx.isExpense,
                    ),
                    style: TextStyle(
                      color: tx.isTransfer
                          ? const Color(0xFF38BDF8)
                          : (tx.isExpense
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981)),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    if (_exportScope != 'Personal Only') {
      if (provider.businessTxs.isNotEmpty) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              provider.tr('Recent Business POS Vouchers', 'সাম্প্রতিক পিওএস ভাউচার'),
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        for (final b in provider.businessTxs.take(5)) {
          final Color c = b.type == 'Sale'
              ? const Color(0xFF10B981)
              : (b.type == 'Purchase'
              ? const Color(0xFFF59E0B)
              : (b.type == 'Expense'
              ? const Color(0xFFEF4444)
              : const Color(0xFF38BDF8)));
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${b.title} (${b.type})',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    provider.formatMoney(b.amount),
                    style: TextStyle(
                      color: c,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    if (rows.isEmpty) {
      rows.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              _exportScope == 'Business POS Only'
                  ? provider.tr(
                'No Business POS entries recorded yet.',
                'এখনো কোনো বিজনেস পিওএস এন্ট্রি নেই।',
              )
                  : provider.tr(
                'No matching entries recorded yet.',
                'এখনো কোনো লেনদেন রেকর্ড করা হয়নি।',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ),
        ),
      );
    }

    return rows;
  }

  Widget _buildMinimalPill(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF38BDF8), size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}