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
  String _exportScope = 'All';

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
                      'FINBLEND FINANCIAL STATEMENT',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
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
                    pw.Text('Scope: $_exportScope', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Receipts: $attachedReceipts', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
            pw.Divider(height: 22),

            pw.Text('1. Portfolio Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'Net Worth',
                'Income',
                'Expense',
                'Wallets',
                'POS Sales',
                'POS Profit',
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
                '2. Personal Transactions (${provider.transactions.length})',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              if (provider.transactions.isEmpty)
                pw.Text('No personal transactions recorded.', style: const pw.TextStyle(fontSize: 10))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Category', 'Description', 'Date', 'Receipt', 'Amount'],
                  data: provider.transactions.take(35).map((tx) {
                    return [
                      tx.title,
                      tx.subtitle,
                      tx.date,
                      tx.hasAttachment ? 'Attached' : '-',
                      '${tx.isExpense ? "-" : "+"}BDT ${tx.amount.toStringAsFixed(0)}',
                    ];
                  }).toList(),
                ),
              pw.SizedBox(height: 18),
            ],

            if (_exportScope != 'Personal Only') ...[
              pw.Text(
                '3. Business POS Vouchers (${provider.businessTxs.length})',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              if (provider.businessTxs.isEmpty)
                pw.Text('No POS transactions recorded.', style: const pw.TextStyle(fontSize: 10))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Title', 'Type', 'Date', 'Memo', 'Amount'],
                  data: provider.businessTxs.take(35).map((b) {
                    return [
                      b.title,
                      b.type,
                      b.date,
                      b.hasAttachment ? 'Attached' : '-',
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
        filename: 'FinBlend_Statement_${DateTime.now().millisecondsSinceEpoch}.$ext',
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

  void _showMinimalRestoreSheet(BuildContext context, TransactionProvider provider) {
    final driveEmailCtrl = TextEditingController(text: provider.connectedGoogleEmail);
    final jsonBackupCtrl = TextEditingController();
    bool preserveCurrentLogin = true;
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
                    Text(
                      provider.tr('Restore Account Data', 'অ্যাকাউন্ট ব্যাকআপ রিস্টোর'),
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
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
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                  ),
                  value: preserveCurrentLogin,
                  onChanged: (v) => setSheetState(() => preserveCurrentLogin = v),
                ),
                const SizedBox(height: 10),

                // 1. GOOGLE DRIVE RESTORE
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: driveEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: provider.tr('Google Drive Account', 'গুগল ড্রাইভ ইমেইল'),
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          prefixIcon: const Icon(Icons.add_to_drive_rounded, color: Color(0xFF38BDF8), size: 18),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isWorking
                          ? null
                          : () async {
                        setSheetState(() => isWorking = true);
                        final res = await provider.restoreFullAccountFromGoogleDrive(
                          googleEmail: driveEmailCtrl.text.trim(),
                          preserveCurrentAccountEmail: preserveCurrentLogin,
                        );
                        setSheetState(() => isWorking = false);
                        if (ctx.mounted && res['success'] == true) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              content: Text(res['message']?.toString() ?? ''),
                            ),
                          );
                        }
                      },
                      child: Text(provider.tr('Pull Drive', 'ড্রাইভ রিস্টোর'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. RECENT SAVED SNAPSHOTS ON DEVICE
                if (provider.localBackupHistory.isNotEmpty) ...[
                  Text(
                    provider.tr('Recent Backups on Device', 'ডিভাইসে সংরক্ষিত ব্যাকআপ'),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...provider.localBackupHistory.take(2).map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        '${item['userName']} • ${item['txCount']} Tx',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${item['exportedAt']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      trailing: TextButton(
                        onPressed: () async {
                          final res = await provider.restoreAccountFromBackupPayload(
                            item['payload'].toString(),
                            preserveCurrentAccountEmail: preserveCurrentLogin,
                          );
                          if (ctx.mounted && res['success'] == true) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(backgroundColor: const Color(0xFF10B981), content: Text(res['message']?.toString() ?? '')),
                            );
                          }
                        },
                        child: Text(provider.tr('Restore', 'রিস্টোর'), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )),
                  const SizedBox(height: 8),
                ],

                // 3. PASTE JSON BACKUP
                TextField(
                  controller: jsonBackupCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: provider.tr('Or paste exported .json backup content here...', 'অথবা এক্সপোর্ট করা .json ফাইল এখানে পেস্ট করুন...'),
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste_rounded, color: Color(0xFF38BDF8), size: 18),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          setSheetState(() => jsonBackupCtrl.text = data!.text!);
                        }
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isWorking
                      ? null
                      : () async {
                    setSheetState(() => isWorking = true);
                    final res = await provider.restoreAccountFromBackupPayload(
                      jsonBackupCtrl.text,
                      preserveCurrentAccountEmail: preserveCurrentLogin,
                    );
                    setSheetState(() => isWorking = false);
                    if (ctx.mounted && res['success'] == true) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          content: Text(res['message']?.toString() ?? ''),
                        ),
                      );
                    }
                  },
                  child: Text(provider.tr('Import JSON Backup', 'ব্যাকআপ ইমপোর্ট করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final int totalTxCount = provider.transactions.length + provider.businessTxs.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          provider.tr('Backup & Statement Export', 'ব্যাকআপ ও স্টেটমেন্ট এক্সপোর্ট'),
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
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // ===============================================================
              // 1. MINIMAL EXECUTIVE ACCOUNT BACKUP & GOOGLE DRIVE CARD
              // ===============================================================
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
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_to_drive_rounded, color: Color(0xFF38BDF8), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.tr('Full Account Backup', 'সম্পূর্ণ অ্যাকাউন্ট ব্যাকআপ'),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${provider.connectedGoogleEmail} • ${provider.lastGoogleDriveBackupAt}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: provider.tr('Copy Backup JSON', 'ব্যাকআপ কপি করুন'),
                          icon: const Icon(Icons.copy_all_rounded, color: Color(0xFF38BDF8), size: 20),
                          onPressed: () {
                            final jsonStr = provider.generateFullAccountBackupString();
                            Clipboard.setData(ClipboardData(text: jsonStr));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF10B981),
                                content: Text(provider.tr('Backup JSON copied to clipboard!', 'ব্যাকআপ ক্লিপবোর্ডে কপি হয়েছে!')),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3 COMPACT SUMMARY PILLS (INSTEAD OF WALL OF TEXT)
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
                            provider.tr('Records', 'লেনদেন'),
                            '$totalTxCount Tx',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMinimalPill(
                            Icons.account_balance_wallet_outlined,
                            provider.tr('Accounts', 'অ্যাকাউন্ট'),
                            '${provider.wallets.length} Wallets • ${provider.groups.length} Groups',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3 CLEAN ACTION BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: provider.isSyncing
                                ? null
                                : () async {
                              final res = await provider.backupFullAccountToGoogleDrive(
                                overrideGoogleEmail: provider.connectedGoogleEmail,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF10B981),
                                    content: Text(res['message']?.toString() ?? 'Backed up!'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                            label: Text(
                              provider.tr('Drive Backup', 'ড্রাইভ ব্যাকআপ'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => provider.downloadFullAccountBackupFile(),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: Text(
                              provider.tr('Export .JSON', 'ফাইল (.json)'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _showMinimalRestoreSheet(context, provider),
                            icon: const Icon(Icons.restore_rounded, size: 16),
                            label: Text(
                              provider.tr('Restore', 'রিস্টোর'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ===============================================================
              // 2. STATEMENT EXPORT TOOLBAR
              // ===============================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    provider.tr('Financial Statement', 'আর্থিক বিবরণী'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 6,
                    children: ['All', 'Personal Only', 'Business POS Only'].map((scope) {
                      final isSel = _exportScope == scope;
                      final shortLabel = scope == 'All' ? 'All' : (scope == 'Personal Only' ? 'Personal' : 'POS');
                      return ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          shortLabel,
                          style: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        selected: isSel,
                        selectedColor: const Color(0xFF0EA5E9),
                        backgroundColor: const Color(0xFF1E293B),
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _exportScope = scope),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _isExporting ? null : () => _exportPdfStatement(provider),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                      label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isExporting ? null : () => _exportImageStatement(asJpg: false),
                      icon: const Icon(Icons.image_outlined, size: 17),
                      label: const Text('PNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isExporting ? null : () => _exportImageStatement(asJpg: true),
                      icon: const Icon(Icons.photo_camera_back_outlined, size: 17),
                      label: const Text('JPG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ===============================================================
              // 3. CLEAN STATEMENT PREVIEW CARD
              // ===============================================================
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.userName,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  provider.cloudEmail,
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Text(
                              '$receiptCount ${provider.tr("Receipts", "রসিদ")}',
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.0),
                        child: Divider(color: Color(0xFF334155), height: 1),
                      ),
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
                          '${provider.tr("Income", "আয়")} (৳${provider.totalIncome.toStringAsFixed(0)})',
                          '${provider.tr("Expense", "ব্যয়")} (৳${provider.totalExpense.toStringAsFixed(0)})',
                          '${provider.tr("Wallets", "ওয়ালেট")} (৳${provider.totalWalletsBalance.toStringAsFixed(0)})',
                          '${provider.tr("POS Sales", "পিওএস")} (৳${provider.totalSales.toStringAsFixed(0)})',
                        ],
                        centerTitle: provider.tr('Net Worth', 'মোট সম্পদ'),
                        centerValue: '৳${netWorth.toStringAsFixed(0)}',
                      ),
                      if (provider.transactions.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14.0),
                          child: Divider(color: Color(0xFF334155), height: 1),
                        ),
                        ...provider.transactions.take(5).map((tx) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  tx.title,
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
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}