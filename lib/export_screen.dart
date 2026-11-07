import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
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
  String _exportScope = 'All'; // 'All', 'Personal Only', 'Business POS Only'

  // ===========================================================================
  // 1. MULTI-PAGE A4 PDF OFFICIAL AUDIT STATEMENT GENERATOR
  // ===========================================================================
  Future<void> _exportPdfStatement(TransactionProvider provider) async {
    setState(() => _isExporting = true);
    try {
      final doc = pw.Document();
      final double netWorth = provider.totalBalance + provider.totalWalletsBalance;
      final int attachedReceipts = provider.transactions.where((t) => t.hasAttachment).length +
          provider.businessTxs.where((t) => t.hasAttachment).length;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pw.Context ctx) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FINBLEND OFFICIAL FINANCIAL STATEMENT',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Account Holder: ${provider.userName} (${provider.cloudEmail})',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (provider.userPhone.isNotEmpty || provider.userAddress.isNotEmpty)
                      pw.Text(
                        'Phone: ${provider.userPhone}  |  Occupation: ${provider.userOccupation}  |  Address: ${provider.userAddress}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Report Scope: $_exportScope', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Verified Receipts: $attachedReceipts', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
            pw.Divider(height: 22),

            pw.Text('1. Executive Portfolio Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'Total Net Worth',
                'Personal Income',
                'Personal Expense',
                'Wallets Balance',
                'Business Sales',
                'Business Net Profit',
              ],
              data: [
                [
                  'BDT ${netWorth.toStringAsFixed(0)}',
                  'BDT ${provider.totalIncome.toStringAsFixed(0)}',
                  'BDT ${provider.totalExpense.toStringAsFixed(0)}',
                  'BDT ${provider.totalWalletsBalance.toStringAsFixed(0)}',
                  'BDT ${provider.totalSales.toStringAsFixed(0)}',
                  'BDT ${provider.netProfit.toStringAsFixed(0)}',
                ],
              ],
            ),
            pw.SizedBox(height: 18),

            if (_exportScope != 'Business POS Only') ...[
              pw.Text(
                '2. Personal Transactions & Attached Memos (${provider.transactions.length} entries)',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              if (provider.transactions.isEmpty)
                pw.Text('No personal transactions recorded.', style: const pw.TextStyle(fontSize: 10))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Category', 'Memo / Description', 'Date', 'Receipt Attached', 'Amount (BDT)'],
                  data: provider.transactions.take(35).map((tx) {
                    return [
                      tx.title,
                      tx.subtitle,
                      tx.date,
                      tx.hasAttachment ? 'Yes (${tx.attachmentName})' : 'No',
                      '${tx.isExpense ? "-" : "+"}BDT ${tx.amount.toStringAsFixed(0)}',
                    ];
                  }).toList(),
                ),
              pw.SizedBox(height: 18),
            ],

            if (_exportScope != 'Personal Only') ...[
              pw.Text(
                '3. Business POS Vouchers & Inventory Summary (${provider.businessTxs.length} entries)',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              if (provider.businessTxs.isEmpty)
                pw.Text('No business POS transactions recorded.', style: const pw.TextStyle(fontSize: 10))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Item / Voucher Title', 'Type', 'Date', 'Memo Attached', 'Amount (BDT)'],
                  data: provider.businessTxs.take(35).map((b) {
                    return [
                      b.title,
                      b.type,
                      b.date,
                      b.hasAttachment ? 'Yes (${b.attachmentName})' : 'No',
                      'BDT ${b.amount.toStringAsFixed(0)}',
                    ];
                  }).toList(),
                ),
            ],
          ],
        ),
      );

      final Uint8List pdfBytes = await doc.save();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'FinBlend_Statement_${provider.userName.replaceAll(" ", "_")}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('PDF Export Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ===========================================================================
  // 2. HIGH-RESOLUTION PNG / JPG SNAPSHOT GENERATOR
  // ===========================================================================
  Future<void> _exportImageStatement({required bool asJpg}) async {
    setState(() => _isExporting = true);
    try {
      final RenderRepaintBoundary? boundary =
      _statementBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isExporting = false);
        return;
      }

      final ui.Image capturedImage = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData = await capturedImage.toByteData(format: ui.ImageByteFormat.png);
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

      await Printing.sharePdf(
        bytes: outputBytes,
        filename: 'FinBlend_Snapshot_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Image Export Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ===========================================================================
  // 3. IMPORT / RESTORE BACKUP INTO NEW OR EXISTING ACCOUNT MODAL
  // ===========================================================================
  void _showImportRestoreSheet(BuildContext context, TransactionProvider provider) {
    final String activeEmail = provider.cloudEmail == 'Not signed in' ? '' : provider.cloudEmail;
    final driveEmailCtrl = TextEditingController(
      text: provider.connectedGoogleEmail.isNotEmpty
          ? provider.connectedGoogleEmail
          : (provider.deviceGoogleAccounts.isNotEmpty ? provider.deviceGoogleAccounts.first : activeEmail),
    );
    final jsonBackupCtrl = TextEditingController();
    bool keepCurrentAccountEmail = true;
    bool isWorking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        provider.tr(
                          'Import Backup into This or New Account',
                          'এই অ্যাকাউন্টে বা নতুন অ্যাকাউন্টে ব্যাকআপ ইমপোর্ট করুন',
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text(
                  provider.tr(
                    'Restore 100% of your Personal Info, Transactions, Receipts, Wallets, Groups, and Business POS data from Google Drive or a downloaded backup file.',
                    'গুগল ড্রাইভ বা ডাউনলোড করা ব্যাকআপ ফাইল থেকে আপনার ব্যক্তিগত তথ্য, সকল লেনদেন, রসিদ, ওয়ালেট, গ্রুপ এবং বিজনেস পিওএস ডাটা ইমপোর্ট করুন।',
                  ),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 12),

                if (activeEmail.isNotEmpty)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFF10B981),
                    title: Text(
                      provider.tr(
                        'Keep current account login ($activeEmail) & import all data into this account',
                        'বর্তমান অ্যাকাউন্টে ($activeEmail) সকল ব্যাকআপ ডাটা ইমপোর্ট করে চালিয়ে যান',
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    value: keepCurrentAccountEmail,
                    onChanged: (v) => setSheetState(() => keepCurrentAccountEmail = v),
                  ),
                const SizedBox(height: 10),

                // OPTION 1: RESTORE DIRECTLY FROM GOOGLE DRIVE
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        provider.tr('Option 1: Pull Backup Directly from Google Drive', 'বিকল্প ১: সরাসরি গুগল ড্রাইভ থেকে ইমপোর্ট করুন'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: driveEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: provider.tr('Google Account Email used for backup', 'ব্যাকআপ রাখা গুগল ইমেইল'),
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          prefixIcon: const Icon(Icons.add_to_drive_rounded, color: Color(0xFF38BDF8), size: 18),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isWorking
                            ? null
                            : () async {
                          setSheetState(() => isWorking = true);
                          final res = await provider.restoreFullAccountFromGoogleDrive(
                            googleEmail: driveEmailCtrl.text.trim(),
                          );
                          if (res['success'] == true && keepCurrentAccountEmail && activeEmail.isNotEmpty) {
                            await provider.updateUserProfile(
                              name: provider.userName,
                              email: activeEmail,
                              phone: provider.userPhone,
                              dob: provider.userDob,
                              gender: provider.userGender,
                              occupation: provider.userOccupation,
                              organization: provider.userOrganization,
                              address: provider.userAddress,
                              photoBase64: provider.userPhotoBase64,
                            );
                          }
                          setSheetState(() => isWorking = false);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                content: Text(res['message']?.toString() ?? ''),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.cloud_download_outlined, size: 18),
                        label: Text(
                          provider.tr('Restore from Google Drive Now', 'গুগল ড্রাইভ থেকে রিস্টোর করুন'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // OPTION 2: PASTE DOWNLOADED BACKUP FILE (.JSON) OR BACKUP KEY
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              provider.tr('Option 2: Import Downloaded Backup (.json / Key)', 'বিকল্প ২: ডাউনলোড করা ব্যাকআপ (.json / কোড) ইমপোর্ট'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final data = await Clipboard.getData('text/plain');
                              if (data?.text != null) {
                                setSheetState(() => jsonBackupCtrl.text = data!.text!);
                              }
                            },
                            icon: const Icon(Icons.paste_rounded, size: 14, color: Color(0xFF38BDF8)),
                            label: Text(provider.tr('Paste', 'পেস্ট'), style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                          ),
                        ],
                      ),
                      TextField(
                        controller: jsonBackupCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: provider.tr(
                            'Paste contents of FinBlend_Full_Account_Backup.json or Backup Key here...',
                            'ব্যাকআপ ফাইল (.json) বা ব্যাকআপ কোড এখানে পেস্ট করুন...',
                          ),
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isWorking
                            ? null
                            : () async {
                          setSheetState(() => isWorking = true);
                          final res = await provider.restoreAccountFromBackupPayload(jsonBackupCtrl.text);
                          if (res['success'] == true && keepCurrentAccountEmail && activeEmail.isNotEmpty) {
                            await provider.updateUserProfile(
                              name: provider.userName,
                              email: activeEmail,
                              phone: provider.userPhone,
                              dob: provider.userDob,
                              gender: provider.userGender,
                              occupation: provider.userOccupation,
                              organization: provider.userOrganization,
                              address: provider.userAddress,
                              photoBase64: provider.userPhotoBase64,
                            );
                          }
                          setSheetState(() => isWorking = false);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                content: Text(res['message']?.toString() ?? ''),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: Text(
                          provider.tr('Import Backup & Continue', 'ব্যাকআপ ইমপোর্ট করে চালিয়ে যান'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
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
    final double netWorth = provider.totalBalance + provider.totalWalletsBalance;
    final int receiptCount = provider.transactions.where((t) => t.hasAttachment).length +
        provider.businessTxs.where((t) => t.hasAttachment).length;
    final String driveTargetEmail = provider.connectedGoogleEmail.isNotEmpty
        ? provider.connectedGoogleEmail
        : provider.cloudEmail;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          provider.tr('Backup, Google Drive & Export', 'ফুল ব্যাকআপ, গুগল ড্রাইভ ও এক্সপোর্ট'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => provider.toggleLanguage(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                alignment: Alignment.center,
                child: Text(
                  provider.isBengali ? 'EN' : 'বাংলা',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // ===============================================================
              // 1. FULL ACCOUNT BACKUP, GOOGLE DRIVE DIRECT SYNC & IMPORT HUB
              // ===============================================================
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.5), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_to_drive_rounded, color: Color(0xFF38BDF8), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.tr(
                                  'Full Account Backup & Direct Google Drive Vault',
                                  'সম্পূর্ণ অ্যাকাউন্ট ব্যাকআপ ও সরাসরি গুগল ড্রাইভ ভল্ট',
                                ),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${provider.tr("Google Account", "গুগল অ্যাকাউন্ট")}: $driveTargetEmail • ${provider.lastGoogleDriveBackupAt}',
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // WHAT IS INCLUDED IN THE BACKUP (3 PILLARS)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.tr('What This Full Backup Exports & Restores:', 'এই ব্যাকআপে যা যা সংরক্ষিত থাকবে:'),
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            provider.tr(
                              '✓ 1. All Personal Info: ${provider.userName}, Phone, DOB, Gender, Occupation, Address & Photo\n'
                                  '✓ 2. All Transactions: ${provider.transactions.length} Personal + ${provider.businessTxs.length} Business POS + $receiptCount Receipts\n'
                                  '✓ 3. All Other Data: ${provider.wallets.length} Wallets, ${provider.budgets.length} Budgets, ${provider.groups.length} Groups, ${provider.products.length} Products & ${provider.parties.length} Parties',
                              '✓ ১. সকল ব্যক্তিগত তথ্য: নাম (${provider.userName}), ফোন, জন্ম তারিখ, পেশা, ঠিকানা ও ছবি\n'
                                  '✓ ২. সকল লেনদেন: ${provider.transactions.length} টি ব্যক্তিগত + ${provider.businessTxs.length} টি পিওএস + $receiptCount টি রসিদ\n'
                                  '✓ ৩. অন্যান্য সকল ডাটা: ${provider.wallets.length} টি ওয়ালেট, ${provider.budgets.length} টি বাজেট, ${provider.groups.length} টি গ্রুপ ও ${provider.products.length} টি পণ্য',
                            ),
                            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // BUTTON ROW 1: DIRECT GOOGLE DRIVE SAVE + DOWNLOAD .JSON FILE
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: provider.isSyncing
                                ? null
                                : () async {
                              final res = await provider.backupFullAccountToGoogleDrive();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF10B981),
                                    content: Text(res['message']?.toString() ?? 'Saved to Google Drive!'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.add_to_drive_rounded, size: 18),
                            label: Text(
                              provider.tr('Save to Google Drive', 'গুগল ড্রাইভে সেভ'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              await provider.downloadFullAccountBackupFile();
                            },
                            icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                            label: Text(
                              provider.tr('Download Backup (.json)', 'ব্যাকআপ ডাউনলোড (.json)'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // BUTTON ROW 2: IMPORT INTO NEW/EXISTING ACCOUNT + COPY KEY
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF59E0B),
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _showImportRestoreSheet(context, provider),
                            icon: const Icon(Icons.restore_page_outlined, size: 18),
                            label: Text(
                              provider.tr('Import / Restore Backup', 'ব্যাকআপ ইমপোর্ট / রিস্টোর'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              final jsonStr = provider.generateFullAccountBackupString();
                              Clipboard.setData(ClipboardData(text: jsonStr));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF10B981),
                                  content: Text(
                                    provider.tr(
                                      'Full Account Backup JSON copied to clipboard! You can paste it into any new or existing account.',
                                      'সম্পূর্ণ অ্যাকাউন্ট ব্যাকআপ কপি করা হয়েছে! যেকোনো নতুন বা বিদ্যমান অ্যাকাউন্টে পেস্ট করতে পারবেন।',
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_all_rounded, size: 18),
                            label: Text(
                              provider.tr('Copy Backup JSON', 'ব্যাকআপ কোড কপি'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ===============================================================
              // 2. PRINTABLE STATEMENT EXPORT (PDF, PNG, JPG)
              // ===============================================================
              Text(
                provider.tr('Printable Statement Export (PDF / PNG / JPG)', 'প্রিন্টেবল স্টেটমেন্ট এক্সপোর্ট (PDF / PNG / JPG)'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All', 'Personal Only', 'Business POS Only'].map((scope) {
                  final isSel = _exportScope == scope;
                  return ChoiceChip(
                    label: Text(
                      scope,
                      style: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    selected: isSel,
                    selectedColor: const Color(0xFF0EA5E9),
                    backgroundColor: const Color(0xFF1E293B),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _exportScope = scope),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isExporting ? null : () => _exportPdfStatement(provider),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(provider.tr('Export PDF', 'পিডিএফ (PDF)'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isExporting ? null : () => _exportImageStatement(asJpg: false),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(provider.tr('Save PNG', 'পিএনজি (PNG)'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isExporting ? null : () => _exportImageStatement(asJpg: true),
                      icon: const Icon(Icons.photo_camera_back_outlined, size: 18),
                      label: Text(provider.tr('Save JPG', 'জেপিজি (JPG)'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. LIVE INTERACTIVE STATEMENT CARD (CAPTURED FOR PNG/JPG)
              RepaintBoundary(
                key: _statementBoundaryKey,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.tr('FINBLEND OFFICIAL AUDIT STATEMENT', 'ফিনব্লেন্ড অফিসিয়াল আর্থিক বিবরণী'),
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.userName,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  provider.cloudEmail,
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Text(
                              '$receiptCount ${provider.tr("Receipts", "টি রসিদ")}',
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(color: Color(0xFF334155), height: 1),
                      ),

                      Text(
                        provider.tr('Portfolio & Cashflow Breakdown Chart', 'পোর্টফোলিও এবং ক্যাশফ্লো চার্ট'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      RealisticDonutChart(
                        values: [
                          provider.totalIncome > 0 ? provider.totalIncome : 1,
                          provider.totalExpense > 0 ? provider.totalExpense : 0,
                          provider.totalWalletsBalance > 0 ? provider.totalWalletsBalance : 0,
                          provider.totalSales > 0 ? provider.totalSales : 0,
                        ],
                        colors: const [
                          Color(0xFF10B981),
                          Color(0xFFEF4444),
                          Color(0xFF0EA5E9),
                          Color(0xFFF59E0B),
                        ],
                        labels: [
                          '${provider.tr("Income", "মোট আয়")} (৳${provider.totalIncome.toStringAsFixed(0)})',
                          '${provider.tr("Expense", "মোট ব্যয়")} (৳${provider.totalExpense.toStringAsFixed(0)})',
                          '${provider.tr("Wallets", "ওয়ালেট জমা")} (৳${provider.totalWalletsBalance.toStringAsFixed(0)})',
                          '${provider.tr("POS Sales", "পিওএস বিক্রয়")} (৳${provider.totalSales.toStringAsFixed(0)})',
                        ],
                        centerTitle: provider.tr('Net Worth', 'মোট সম্পদ'),
                        centerValue: '৳${netWorth.toStringAsFixed(0)}',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(color: Color(0xFF334155), height: 1),
                      ),

                      Text(
                        provider.tr('Recent Verified Entries', 'সাম্প্রতিক যাচাইকৃত লেনদেন'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ...provider.transactions.take(6).map((tx) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${tx.title} (${tx.subtitle}) ${tx.hasAttachment ? "📎" : ""}',
                                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${tx.isExpense ? "-" : "+"}৳${tx.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: tx.isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )),
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
}