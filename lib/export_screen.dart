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
                        'Contact: ${provider.userPhone}  |  Address: ${provider.userAddress}',
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

            // EXECUTIVE SUMMARY TABLE
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

            // PERSONAL LEDGER SECTION
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

            // BUSINESS POS SECTION
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final double netWorth = provider.totalBalance + provider.totalWalletsBalance;
    final int receiptCount = provider.transactions.where((t) => t.hasAttachment).length +
        provider.businessTxs.where((t) => t.hasAttachment).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          provider.tr('Export Financial Statement', 'আর্থিক স্টেটমেন্ট এক্সপোর্ট'),
          style: const TextStyle(fontWeight: FontWeight.bold),
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
              // 1. SCOPE FILTER CHIPS
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
              const SizedBox(height: 16),

              // 2. EXPORT ACTION BUTTONS (PDF, PNG, JPG)
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

                      // PORTFOLIO DONUT CHART INSIDE STATEMENT
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

                      // RECENT ENTRIES SNAPSHOT
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