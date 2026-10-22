import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'providers/transaction_provider.dart';

class ExportScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const ExportScreen({super.key, required this.userName, required this.userEmail});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final GlobalKey _snapshotKey = GlobalKey();
  bool _isExporting = false;

  // ===========================================================================
  // 1. EXPORT AS MULTI-PAGE PROFESSIONAL PDF
  // ===========================================================================
  Future<void> _exportPdf(TransactionProvider provider) async {
    if (!provider.permissionsGranted) {
      _showPermissionRequired();
      return;
    }

    setState(() => _isExporting = true);
    try {
      final doc = pw.Document();
      final nowStr = DateTime.now().toString().split('.').first;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FinBlend Financial Statement', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Account: ${widget.userName} (${widget.userEmail})', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                  pw.Text('Generated: $nowStr', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // EXECUTIVE SUMMARY TABLE
            pw.Text('1. Executive Balance Summary', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Amount (BDT)'],
              data: [
                ['Total Personal Income', 'BDT ${provider.totalIncome.toStringAsFixed(2)}'],
                ['Total Personal Expense', 'BDT ${provider.totalExpense.toStringAsFixed(2)}'],
                ['Net Personal Balance', 'BDT ${provider.totalBalance.toStringAsFixed(2)}'],
                ['Total Wallets & Bank Net Worth', 'BDT ${provider.totalWalletsBalance.toStringAsFixed(2)}'],
                ['Business POS Total Sales', 'BDT ${provider.totalSales.toStringAsFixed(2)}'],
                ['Business POS Net Profit', 'BDT ${provider.netProfit.toStringAsFixed(2)}'],
              ],
            ),
            pw.SizedBox(height: 20),

            // WALLETS & ACCOUNTS
            pw.Text('2. Wallets & Banking Accounts', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Account Name', 'Category', 'Provider', 'Balance (BDT)'],
              data: provider.wallets
                  .map((w) => [w.name, w.type, w.providerName, 'BDT ${w.balance.toStringAsFixed(0)}'])
                  .toList(),
            ),
            pw.SizedBox(height: 20),

            // GROUP & TRIP SPLIT SUMMARY
            if (provider.groups.isNotEmpty) ...[
              pw.Text('3. Group & Trip Split Plans', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Plan Name', 'Members', 'Budget', 'Given', 'Spent', 'Budget Left'],
                data: provider.groups
                    .map((g) => [
                  g.name,
                  '${g.memberCount}',
                  'BDT ${g.totalBudget.toStringAsFixed(0)}',
                  'BDT ${g.totalCollected.toStringAsFixed(0)}',
                  'BDT ${g.totalSpent.toStringAsFixed(0)}',
                  'BDT ${g.budgetRemaining.toStringAsFixed(0)}',
                ])
                    .toList(),
              ),
              pw.SizedBox(height: 20),
            ],

            // PERSONAL TRANSACTION HISTORY
            pw.Text('4. Personal Transaction History (${provider.transactions.length} Entries)', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            if (provider.transactions.isEmpty)
              pw.Text('No personal transactions recorded.')
            else
              pw.TableHelper.fromTextArray(
                headers: ['Date & Time', 'Title', 'Type', 'Amount (BDT)'],
                data: provider.transactions
                    .map((tx) => [
                  tx.date,
                  tx.title,
                  tx.isExpense ? 'Expense' : 'Income',
                  '${tx.isExpense ? "-" : "+"} BDT ${tx.amount.toStringAsFixed(0)}',
                ])
                    .toList(),
              ),
          ],
        ),
      );

      final Uint8List pdfBytes = await doc.save();
      await Printing.sharePdf(bytes: pdfBytes, filename: 'FinBlend_Statement.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Export Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ===========================================================================
  // 2. EXPORT AS HIGH-RES PNG OR JPG IMAGE
  // ===========================================================================
  Future<void> _exportImage({required bool asJpg, required TransactionProvider provider}) async {
    if (!provider.permissionsGranted) {
      _showPermissionRequired();
      return;
    }

    setState(() => _isExporting = true);
    try {
      final boundary = _snapshotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image capturedImage = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? pngByteData = await capturedImage.toByteData(format: ui.ImageByteFormat.png);
      if (pngByteData == null) return;

      final Uint8List pngBytes = pngByteData.buffer.asUint8List();

      if (!asJpg) {
        await Printing.sharePdf(bytes: pngBytes, filename: 'FinBlend_Report.png');
      } else {
        final decoded = img.decodePng(pngBytes);
        if (decoded != null) {
          final Uint8List jpgBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
          await Printing.sharePdf(bytes: jpgBytes, filename: 'FinBlend_Report.jpg');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image Export Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showPermissionRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text('Storage & Export permission is restricted! Enable it in Account -> Permissions.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Export Financial Data', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: RepaintBoundary(
                key: _snapshotKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181C20),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('FinBlend Official Statement', style: TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${widget.userName} • ${widget.userEmail}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          const Icon(Icons.verified_rounded, color: Colors.tealAccent, size: 32),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(color: Colors.white12),
                      ),

                      // CORE BALANCES
                      const Text('BALANCE & NET WORTH OVERVIEW', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildSummaryBox('Net Balance', '৳ ${provider.totalBalance.toStringAsFixed(0)}', Colors.tealAccent)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildSummaryBox('Wallets Total', '৳ ${provider.totalWalletsBalance.toStringAsFixed(0)}', Colors.blueAccent)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildSummaryBox('Total Income', '+৳ ${provider.totalIncome.toStringAsFixed(0)}', Colors.greenAccent)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildSummaryBox('Total Expense', '-৳ ${provider.totalExpense.toStringAsFixed(0)}', Colors.redAccent)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // WALLETS BREAKDOWN
                      const Text('ACCOUNTS & WALLETS', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      ...provider.wallets.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${w.name} (${w.providerName})', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            Text('৳ ${w.balance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      )),
                      const SizedBox(height: 16),

                      // GROUP PLANS SUMMARY
                      if (provider.groups.isNotEmpty) ...[
                        const Text('GROUP & TRIP PLANS', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        ...provider.groups.map((g) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text('${g.name} (${g.memberCount} members)', style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                              Text('Spent: ৳${g.totalSpent.toStringAsFixed(0)} / ৳${g.totalBudget.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],

                      // RECENT TRANSACTIONS
                      const Text('RECENT TRANSACTIONS', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      if (provider.transactions.isEmpty)
                        const Text('No transactions recorded yet.', style: TextStyle(color: Colors.white54, fontSize: 12))
                      else
                        ...provider.transactions.take(8).map((tx) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('${tx.title} • ${tx.date}', style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                              ),
                              Text(
                                '${tx.isExpense ? "-" : "+"}৳ ${tx.amount.toStringAsFixed(0)}',
                                style: TextStyle(color: tx.isExpense ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        )),
                      const SizedBox(height: 16),

                      // BUSINESS POS METRICS
                      const Text('BUSINESS POS SUMMARY', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sales: ৳ ${provider.totalSales.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          Text('Net Profit: ৳ ${provider.netProfit.toStringAsFixed(0)}', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('Customer Due: ৳ ${provider.totalCustomerDue.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // EXPORT FORMAT ACTION BAR (PDF, PNG, JPG)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose Export Format (Works on Phone & Web):',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (_isExporting)
                  const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                else
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _exportPdf(provider),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _exportImage(asJpg: false, provider: provider),
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: const Text('PNG', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _exportImage(asJpg: true, provider: provider),
                          icon: const Icon(Icons.photo_camera_back_outlined, size: 18),
                          label: const Text('JPG', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121518),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}