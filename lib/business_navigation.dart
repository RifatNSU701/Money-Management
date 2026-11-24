import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/utils/app_currency.dart';
import 'core/utils/app_validators.dart';
import 'core/widgets/app_feedback.dart';
import 'main_navigation.dart';
import 'providers/transaction_provider.dart';

class BusinessNavigationScreen extends StatefulWidget {
  final int? initialIndex;
  const BusinessNavigationScreen({super.key, this.initialIndex});

  @override
  State<BusinessNavigationScreen> createState() =>
      _BusinessNavigationScreenState();
}

class _BusinessNavigationScreenState extends State<BusinessNavigationScreen> {
  int _selectedIndex = 0;

  // Separate search & filter states across tabs
  String _txFilter = 'All';
  String _stockFilter = 'All';
  String _partyFilter = 'All';
  String _invSearchQuery = '';
  String _partySearchQuery = '';
  String _voucherSearchQuery = '';

  final _invSearchCtrl = TextEditingController();
  final _partySearchCtrl = TextEditingController();
  final _voucherSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreBusinessTab();
  }

  @override
  void dispose() {
    _invSearchCtrl.dispose();
    _partySearchCtrl.dispose();
    _voucherSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreBusinessTab() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTab =
    (widget.initialIndex ?? prefs.getInt('nav_business_tab') ?? 0)
        .clamp(0, 3);
    if (!mounted) return;
    setState(() => _selectedIndex = savedTab);
    context.read<TransactionProvider>().saveNavigationState(
      businessTabIndex: savedTab,
      isBusinessMode: true,
    );
  }

  void _selectTab(int idx) {
    final clamped = idx.clamp(0, 3);
    if (_selectedIndex != clamped) {
      setState(() => _selectedIndex = clamped);
    }
    context.read<TransactionProvider>().saveNavigationState(
      businessTabIndex: clamped,
      isBusinessMode: true,
    );
  }

  Future<void> _switchToPersonalMode() async {
    await context.read<TransactionProvider>().saveNavigationState(
      isBusinessMode: false,
    );
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
    );
  }

  // ===========================================================================
  // OFFICIAL PDF POS INVOICE & 80MM THERMAL RECEIPT GENERATOR
  // ===========================================================================
  void _showInvoicePrintPicker(
      BuildContext context,
      BusinessTxModel tx,
      TransactionProvider provider,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              provider.tr('Export POS Voucher PDF', 'পিওএস ভাউচার পিডিএফ'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _generatePosInvoicePdf(tx, provider, thermal: false);
              },
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(
                provider.tr(
                  'Standard Invoice (A5 PDF)',
                  'স্ট্যান্ডার্ড ইনভয়েস (A5 PDF)',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10B981),
                side: const BorderSide(color: Color(0xFF10B981)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _generatePosInvoicePdf(tx, provider, thermal: true);
              },
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(
                provider.tr(
                  'Thermal Receipt (80mm Roll PDF)',
                  'থার্মাল রসিদ (80mm রোল PDF)',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePosInvoicePdf(
      BusinessTxModel tx,
      TransactionProvider provider, {
        required bool thermal,
      }) async {
    try {
      final doc = pw.Document();
      final String code = provider.currencyCode;
      final String invNo = tx.id.substring(math.max(0, tx.id.length - 6));
      final String orgTitle = provider.userOrganization.isNotEmpty
          ? provider.userOrganization
          : 'FinBlend Business POS';

      if (thermal) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.roll80,
            margin: const pw.EdgeInsets.all(10),
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  orgTitle.toUpperCase(),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Voucher #$invNo  |  ${tx.type}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  tx.date,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
                pw.Divider(height: 10),
                if (tx.partyName.isNotEmpty)
                  pw.Text(
                    'Party: ${tx.partyName}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${tx.title}${tx.quantity > 1 ? " x${tx.quantity}" : ""}',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    ),
                    pw.Text(
                      '$code ${tx.amount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (tx.discountAmount > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Discount:',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        '-$code ${tx.discountAmount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                if (tx.vatAmount > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('VAT:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                        '+$code ${tx.vatAmount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                pw.Divider(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '$code ${tx.amount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (tx.paidAmount > 0 || tx.dueAmount > 0) ...[
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Paid:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                        '$code ${tx.paidAmount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Due:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                        '$code ${tx.dueAmount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ],
                pw.SizedBox(height: 8),
                pw.Text(
                  'Thank you! • FinBlend POS',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
              ],
            ),
          ),
        );
      } else {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a5,
            margin: const pw.EdgeInsets.all(24),
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          orgTitle.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Official POS Invoice & Voucher',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Text(
                      'INVOICE #$invNo',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Divider(height: 18),
                pw.Text(
                  'Date & Time: ${tx.date}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Voucher Type: ${tx.type.toUpperCase()}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (tx.partyName.isNotEmpty)
                  pw.Text(
                    'Party: ${tx.partyName}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                pw.Text(
                  'Issued By: ${provider.userName} (${provider.cloudEmail})',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 14),
                pw.TableHelper.fromTextArray(
                  headers: [
                    'Item / Description',
                    'Qty',
                    'Type',
                    'Amount ($code)',
                  ],
                  data: [
                    [
                      tx.title,
                      '${tx.quantity}',
                      tx.type,
                      '$code ${tx.amount.toStringAsFixed(2)}',
                    ],
                  ],
                ),
                pw.SizedBox(height: 12),
                if (tx.discountAmount > 0)
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Discount: -$code ${tx.discountAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                if (tx.vatAmount > 0)
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'VAT: +$code ${tx.vatAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                pw.SizedBox(height: 4),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'GRAND TOTAL: $code ${tx.amount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (tx.paidAmount > 0 || tx.dueAmount > 0)
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Paid: $code ${tx.paidAmount.toStringAsFixed(2)}  |  Due: $code ${tx.dueAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                pw.Spacer(),
                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'Thank you for your business! • FinBlend POS Suite',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final Uint8List bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: thermal
            ? 'FinBlend_Thermal_Receipt_$invNo.pdf'
            : 'FinBlend_POS_Invoice_$invNo.pdf',
      );
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'PDF Invoice Error: $e');
      }
    }
  }

  Future<void> _callParty(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _whatsAppReminder(
      PartyModel party,
      TransactionProvider provider,
      ) async {
    String digits = party.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    if (digits.startsWith('0') && digits.length == 11) {
      digits = '88$digits';
    }
    final amtText = AppCurrency.format(party.dueAmount, respectPrivacy: false);
    final msg = party.isCustomer
        ? 'Hello ${party.name}, friendly reminder regarding your pending balance of $amtText. Thank you!'
        : 'Hello ${party.name}, checking in regarding our supplier balance of $amtText.';
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(msg)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final double screenW = MediaQuery.of(context).size.width;
    final bool isWideWeb = screenW >= 820;
    final bool isCompactMobile = screenW < 420;

    final appBarActions = <Widget>[
      // 1. LANGUAGE SWITCHER
      Tooltip(
        message: provider.tr('Switch Language', 'ভাষা পরিবর্তন'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => provider.toggleLanguage(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),

      // 2. GLOBAL PRIVACY EYE
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: provider.hideBalances
            ? provider.tr('Show Balances', 'ব্যালেন্স দেখান')
            : provider.tr('Hide Balances', 'ব্যালেন্স লুকান'),
        icon: Icon(
          provider.hideBalances
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: provider.hideBalances
              ? const Color(0xFFF59E0B)
              : const Color(0xFF94A3B8),
          size: 20,
        ),
        onPressed: () => provider.toggleHideBalances(),
      ),

      // 3. DRIVE BACKUP
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: provider.tr('Google Drive Backup', 'গুগল ড্রাইভ ব্যাকআপ'),
        icon: provider.isSyncing
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF38BDF8),
          ),
        )
            : const Icon(
          Icons.add_to_drive_rounded,
          color: Color(0xFF38BDF8),
          size: 20,
        ),
        onPressed: () => ProfileScreen.showCloudSyncSheet(context),
      ),

      // 4. THEME TOGGLE
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: provider.tr('Switch Theme', 'থিম পরিবর্তন'),
        icon: Icon(
          provider.isDarkMode
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          color: const Color(0xFF38BDF8),
          size: 20,
        ),
        onPressed: () => provider.toggleDarkMode(!provider.isDarkMode),
      ),

      // 5. COMPACT PERSONAL MODE SWITCHER (NEVER CRUSHES "FinBlend POS" TITLE)
      Padding(
        padding: const EdgeInsets.only(right: 10.0, left: 2.0),
        child: Tooltip(
          message: provider.tr('Switch to Personal Mode', 'ব্যক্তিগত মোডে যান'),
          child: isCompactMobile
              ? IconButton(
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor:
              const Color(0xFF0EA5E9).withValues(alpha: 0.16),
              foregroundColor: const Color(0xFF38BDF8),
            ),
            onPressed: _switchToPersonalMode,
            icon: const Icon(Icons.person_outline, size: 19),
          )
              : TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor:
              const Color(0xFF0EA5E9).withValues(alpha: 0.15),
              foregroundColor: const Color(0xFF38BDF8),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _switchToPersonalMode,
            icon: const Icon(Icons.person_outline, size: 15),
            label: Text(
              provider.tr('Personal', 'ব্যক্তিগত'),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    ];

    if (isWideWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.storefront_rounded, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  provider.tr(
                    'FinBlend Business POS & ERP',
                    'ফিনব্লেন্ড বিজনেস পিওএস ও ইনভেন্টরি',
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          actions: appBarActions,
        ),
        body: Row(
          children: [
            NavigationRail(
              extended: screenW >= 1060,
              backgroundColor: const Color(0xFF1E293B),
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectTab,
              indicatorColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
              selectedIconTheme: const IconThemeData(color: Color(0xFF38BDF8)),
              unselectedIconTheme:
              const IconThemeData(color: Color(0xFF94A3B8)),
              selectedLabelTextStyle: const TextStyle(
                color: Color(0xFF38BDF8),
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle:
              const TextStyle(color: Color(0xFF94A3B8)),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard),
                  label: Text(provider.tr('POS Overview', 'পিওএস হোম')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  selectedIcon: const Icon(Icons.inventory_2),
                  label: Text(provider.tr('Inventory ERP', 'স্টক ইনভেন্টরি')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.people_alt_outlined),
                  selectedIcon: const Icon(Icons.people_alt),
                  label: Text(provider.tr('Parties & Dues', 'কাস্টমার ও বাকি')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long),
                  label: Text(provider.tr('Invoices & Memos', 'ভাউচার ও রসিদ')),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: Color(0xFF334155)),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: _buildCurrentTab(context, provider),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleSpacing: 14,
        title: Text(
          provider.tr('FinBlend POS', 'বিজনেস পিওএস'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17.5,
          ),
        ),
        actions: appBarActions,
      ),
      body: _buildCurrentTab(context, provider),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1E293B),
          indicatorColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF38BDF8));
            }
            return const IconThemeData(color: Color(0xFF94A3B8));
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              );
            }
            return const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: provider.tr('POS Home', 'হোম'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: provider.tr('Inventory', 'স্টক'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_alt_outlined),
              selectedIcon: const Icon(Icons.people_alt),
              label: provider.tr('Parties', 'কাস্টমার'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: provider.tr('Invoices', 'ভাউচার'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab(BuildContext context, TransactionProvider provider) {
    switch (_selectedIndex) {
      case 0:
        return _buildPosOverviewTab(context, provider);
      case 1:
        return _buildInventoryErpTab(context, provider);
      case 2:
        return _buildPartiesCrmTab(context, provider);
      case 3:
        return _buildInvoicesAuditTab(context, provider);
      default:
        return _buildPosOverviewTab(context, provider);
    }
  }

  // ===========================================================================
  // TAB 1: POS OVERVIEW (TRUE COGS PROFITABILITY & ZERO-SAFE CHART)
  // ===========================================================================
  Widget _buildPosOverviewTab(
      BuildContext context,
      TransactionProvider provider,
      ) {
    final double sales = provider.totalSales;
    final double cogs = provider.totalCOGS;
    final double expenses = provider.totalBizExpenses;
    final double profit = provider.netProfit;
    final double marginPct = provider.profitMarginPercent;
    final double stockCostVal = provider.totalInventoryCostValue;
    final double stockRetailVal = provider.totalInventoryRetailValue;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 118),
        children: [
          // 1. TRUE COGS PROFITABILITY KPI CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider.tr(
                          'POS COGS PROFITABILITY',
                          'ব্যবসায়িক প্রকৃত লাভ-ক্ষতি (COGS)',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (profit >= 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${provider.tr("Margin", "মার্জিন")}: ${marginPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: profit >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${provider.formatMoney(profit)} ${provider.tr("Net Profit", "নিট লাভ")}',
                    style: TextStyle(
                      color: profit >= 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.tr(
                    'Formula: Gross Profit (Sales − Cost of Goods) − Business Expenses',
                    'সূত্র: মোট লাভ (বিক্রয় − ক্রয়মূল্য) − ব্যবসায়িক খরচ',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCell(
                              provider.tr('Total Sales', 'মোট বিক্রয়'),
                              provider.formatMoney(sales),
                              const Color(0xFF10B981),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: const Color(0xFF334155),
                          ),
                          Expanded(
                            child: _buildStatCell(
                              provider.tr('Cost (COGS)', 'ক্রয়মূল্য'),
                              provider.formatMoney(cogs),
                              const Color(0xFFF59E0B),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: const Color(0xFF334155),
                          ),
                          Expanded(
                            child: _buildStatCell(
                              provider.tr('Expenses', 'ব্যবসায়িক ব্যয়'),
                              provider.formatMoney(expenses),
                              const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Divider(color: Color(0xFF334155), height: 1),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCell(
                              provider.tr('Stock Value', 'স্টক মূল্য'),
                              provider.formatMoney(
                                stockCostVal > 0 ? stockCostVal : stockRetailVal,
                              ),
                              const Color(0xFF38BDF8),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: const Color(0xFF334155),
                          ),
                          Expanded(
                            child: _buildStatCell(
                              provider.tr('Customer Due', 'কাস্টমার পাওনা'),
                              provider.formatMoney(provider.totalCustomerDue),
                              const Color(0xFFF59E0B),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: const Color(0xFF334155),
                          ),
                          Expanded(
                            child: _buildStatCell(
                              provider.tr('Supplier Due', 'সাপ্লায়ার দেনা'),
                              provider.formatMoney(provider.totalSupplierDue),
                              const Color(0xFFEC4899),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. QUICK POS OPERATIONS ROW
          Row(
            children: [
              Expanded(
                child: _buildPosActionCard(
                  icon: Icons.point_of_sale_rounded,
                  title: provider.tr('Smart Sale', 'স্মার্ট বিক্রয়'),
                  subtitle: provider.tr('COGS & Stock', 'লাভ ও স্টক'),
                  color: const Color(0xFF10B981),
                  onTap: () =>
                      _showSmartPosCheckoutSheet(context, initialType: 'Sale'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPosActionCard(
                  icon: Icons.shopping_bag_outlined,
                  title: provider.tr('Purchase', 'মাল ক্রয়'),
                  subtitle: provider.tr('Restock items', 'স্টক বৃদ্ধি'),
                  color: const Color(0xFFF59E0B),
                  onTap: () => _showSmartPosCheckoutSheet(
                    context,
                    initialType: 'Purchase',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPosActionCard(
                  icon: Icons.money_off_csred_rounded,
                  title: provider.tr('Biz Expense', 'ব্যবসায়িক ব্যয়'),
                  subtitle: provider.tr('Rent & bills', 'ভাড়া ও বিল'),
                  color: const Color(0xFFEF4444),
                  onTap: () => _showSmartPosCheckoutSheet(
                    context,
                    initialType: 'Expense',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3. ZERO-SAFE POS REVENUE VS COST DONUT CHART
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
                Text(
                  provider.tr(
                    'Sales, COGS & Expenses Breakdown',
                    'বিক্রয়, ক্রয়মূল্য এবং খরচের চার্ট',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [sales, cogs, expenses],
                  colors: const [
                    Color(0xFF10B981),
                    Color(0xFFF59E0B),
                    Color(0xFFEF4444),
                  ],
                  labels: [
                    '${provider.tr("Sales", "বিক্রয়")} (${provider.formatMoney(sales)})',
                    '${provider.tr("COGS", "ক্রয়মূল্য")} (${provider.formatMoney(cogs)})',
                    '${provider.tr("Expenses", "ব্যয়")} (${provider.formatMoney(expenses)})',
                  ],
                  centerTitle: provider.tr('Vouchers', 'মোট ভাউচার'),
                  centerValue: '${provider.businessTxs.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // LOW STOCK ALERT BANNER
          if (provider.lowStockCount > 0) ...[
            GestureDetector(
              onTap: () {
                setState(() => _stockFilter = 'Low Stock');
                _selectTab(1);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        provider.tr(
                          'Low Stock Alert: ${provider.lowStockCount} ${provider.lowStockCount == 1 ? "product has" : "products have"} 5 or fewer units left! Tap to restock.',
                          'স্টক সতর্কতা: ${provider.lowStockCount} টি পণ্যের স্টক ৫ বা তার কম রয়েছে! স্টক বাড়াতে ট্যাপ করুন।',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFFEF4444)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 4. RECENT POS VOUCHERS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  provider.tr(
                    'Recent POS Vouchers & Due Logs',
                    'সাম্প্রতিক পিওএস ভাউচার ও বকেয়া',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _selectTab(3),
                child: Text(
                  provider.tr('View All', 'সব দেখুন'),
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (provider.businessTxs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                provider.tr(
                  'No POS entries yet. Tap "New POS Sale" below to record a sale and generate an invoice.',
                  'এখনো কোনো পিওএস লেনদেন নেই। নিচে "+ নতুন পিওএস বিক্রয়" বাটনে ট্যাপ করুন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...provider.businessTxs
                .take(8)
                .map((tx) => _buildBizTxTile(context, tx, provider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () =>
            _showSmartPosCheckoutSheet(context, initialType: 'Sale'),
        icon: const Icon(Icons.point_of_sale_rounded),
        label: Text(
          provider.tr('New POS Sale', 'নতুন পিওএস বিক্রয়'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: INVENTORY ERP (WITH COST PRICE, SELLING PRICE & ZERO-SAFE CHART)
  // ===========================================================================
  Widget _buildInventoryErpTab(
      BuildContext context,
      TransactionProvider provider,
      ) {
    final double healthyCount =
    provider.products.where((p) => p.stock > 5).length.toDouble();
    final double lowCount = provider.lowStockCount.toDouble();
    final double totalValuation = provider.totalInventoryRetailValue;

    final filteredProducts = provider.products.where((p) {
      if (_stockFilter == 'Low Stock' && p.stock > 5) return false;
      if (_stockFilter == 'Out of Stock' && p.stock > 0) return false;
      if (_invSearchQuery.isNotEmpty &&
          !p.name.toLowerCase().contains(_invSearchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 118),
        children: [
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
                Text(
                  provider.tr(
                    'Inventory Stock Health & Valuation',
                    'স্টক ইনভেন্টরি ও মূল্যায়ন চার্ট',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [healthyCount, lowCount],
                  colors: const [Color(0xFF10B981), Color(0xFFEF4444)],
                  labels: [
                    '${provider.tr("Healthy (>5)", "পর্যাপ্ত স্টক")} (${healthyCount.toInt()})',
                    '${provider.tr("Low (<=5)", "কম স্টক")} (${lowCount.toInt()})',
                  ],
                  centerTitle: provider.tr('Retail Value', 'স্টক মূল্য'),
                  centerValue: provider.formatMoney(totalValuation),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _invSearchCtrl,
            onChanged: (v) => setState(() => _invSearchQuery = v.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: provider.tr(
                'Search inventory products...',
                'পণ্যের নাম দিয়ে খুঁজুন...',
              ),
              hintStyle:
              const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8)),
              suffixIcon: _invSearchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(
                  Icons.clear,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
                onPressed: () {
                  _invSearchCtrl.clear();
                  setState(() => _invSearchQuery = '');
                },
              )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['All', 'Low Stock', 'Out of Stock'].map((f) {
              final isSel = _stockFilter == f;
              return ChoiceChip(
                label: Text(
                  f,
                  style: TextStyle(
                    color: isSel ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: isSel,
                selectedColor: const Color(0xFF0EA5E9),
                backgroundColor: const Color(0xFF1E293B),
                showCheckmark: false,
                onSelected: (_) => setState(() => _stockFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          if (filteredProducts.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                provider.tr(
                  'No matching products. Tap "+ Add Product" below to add stock with Cost & Selling prices.',
                  'কোনো পণ্য পাওয়া যায়নি। নিচে "+ পণ্য যোগ করুন" বাটনে ট্যাপ করুন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...filteredProducts.map((p) {
              final bool isLow = p.stock <= 5;
              final double valShare = totalValuation > 0
                  ? (p.inventoryRetailValue / totalValuation).clamp(0.0, 1.0)
                  : 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLow
                        ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                        : const Color(0xFF334155),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isLow
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF0EA5E9))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: isLow
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${provider.tr("Sell", "বিক্রয়")}: ${provider.formatMoney(p.price)} • ${provider.tr("Cost", "ক্রয়")}: ${provider.formatMoney(p.costPrice)} • ${provider.tr("Profit/u", "লাভ")}: ${provider.formatMoney(p.unitProfit)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: (isLow
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${p.stock} ${provider.tr(p.stock == 1 ? "unit" : "units", "টি")}',
                            style: TextStyle(
                              color: isLow
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: valShare,
                        minHeight: 5,
                        backgroundColor: const Color(0xFF0F172A),
                        color: isLow
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF0EA5E9),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildStockQuickBtn('-1', () {
                              if (p.stock > 0) {
                                provider.saveProduct(
                                  id: p.id,
                                  name: p.name,
                                  price: p.price,
                                  costPrice: p.costPrice,
                                  stock: p.stock - 1,
                                );
                              }
                            }),
                            const SizedBox(width: 6),
                            _buildStockQuickBtn('+1', () {
                              provider.saveProduct(
                                id: p.id,
                                name: p.name,
                                price: p.price,
                                costPrice: p.costPrice,
                                stock: p.stock + 1,
                              );
                            }),
                            const SizedBox(width: 6),
                            _buildStockQuickBtn('+10', () {
                              provider.saveProduct(
                                id: p.id,
                                name: p.name,
                                price: p.price,
                                costPrice: p.costPrice,
                                stock: p.stock + 10,
                              );
                            }),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: provider.tr('Edit Product', 'এডিট'),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF38BDF8),
                                size: 19,
                              ),
                              onPressed: () =>
                                  _showProductSheet(context, existing: p),
                            ),
                            IconButton(
                              tooltip: provider.tr('Delete Product', 'মুছুন'),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFEF4444),
                                size: 19,
                              ),
                              onPressed: () async {
                                final ok = await AppFeedback.confirmDelete(
                                  context,
                                  title: provider.tr(
                                    'Delete "${p.name}"?',
                                    '"${p.name}" মুছবেন?',
                                  ),
                                  message: provider.tr(
                                    'Remove this product from inventory?',
                                    'ইনভেন্টরি থেকে এই পণ্যটি মুছে ফেলবেন?',
                                  ),
                                );
                                if (ok) provider.deleteProduct(p.id);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showProductSheet(context),
        icon: const Icon(Icons.add_box_outlined),
        label: Text(
          provider.tr('Add Product', 'পণ্য যোগ করুন'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStockQuickBtn(String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF38BDF8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: PARTIES CRM (SEARCH BOX + PARTIAL DUE COLLECTION + HISTORY + REMINDER)
  // ===========================================================================
  Widget _buildPartiesCrmTab(
      BuildContext context,
      TransactionProvider provider,
      ) {
    final double custDue = provider.totalCustomerDue;
    final double suppDue = provider.totalSupplierDue;

    final filteredParties = provider.parties.where((p) {
      if (_partyFilter == 'Customers' && !p.isCustomer) return false;
      if (_partyFilter == 'Suppliers' && p.isCustomer) return false;
      if (_partyFilter == 'With Due' && p.dueAmount <= 0) return false;
      if (_partySearchQuery.isNotEmpty) {
        final q = _partySearchQuery.toLowerCase();
        return p.name.toLowerCase().contains(q) ||
            p.phone.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 118),
        children: [
          // 1. ZERO-SAFE RECEIVABLE VS PAYABLE CHART
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
                Text(
                  provider.tr(
                    'Customer Receivable vs Supplier Payable',
                    'কাস্টমার পাওনা বনাম সাপ্লায়ার দেনা',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [custDue, suppDue],
                  colors: const [Color(0xFF0EA5E9), Color(0xFFF59E0B)],
                  labels: [
                    '${provider.tr("Receivable", "পাওনা")} (${provider.formatMoney(custDue)})',
                    '${provider.tr("Payable", "দেনা")} (${provider.formatMoney(suppDue)})',
                  ],
                  centerTitle: provider.tr('Parties', 'মোট পার্টি'),
                  centerValue: '${provider.parties.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. PARTIES SEARCH BOX
          TextField(
            controller: _partySearchCtrl,
            onChanged: (v) => setState(() => _partySearchQuery = v.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: provider.tr(
                'Search customer or supplier by name or phone...',
                'নাম বা ফোন নম্বর দিয়ে কাস্টমার/সাপ্লায়ার খুঁজুন...',
              ),
              hintStyle:
              const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              prefixIcon:
              const Icon(Icons.search, color: Color(0xFF38BDF8), size: 18),
              suffixIcon: _partySearchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(
                  Icons.clear,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
                onPressed: () {
                  _partySearchCtrl.clear();
                  setState(() => _partySearchQuery = '');
                },
              )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            children: ['All', 'Customers', 'Suppliers', 'With Due'].map((f) {
              final isSel = _partyFilter == f;
              return ChoiceChip(
                label: Text(
                  f,
                  style: TextStyle(
                    color: isSel ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: isSel,
                selectedColor: const Color(0xFF0EA5E9),
                backgroundColor: const Color(0xFF1E293B),
                showCheckmark: false,
                onSelected: (_) => setState(() => _partyFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          if (filteredParties.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                provider.tr(
                  'No matching parties. Tap "+ Add Party" below to track customer or supplier dues.',
                  'কোনো কাস্টমার বা সাপ্লায়ার পাওয়া যায়নি। নিচে "+ নতুন পার্টি" বাটনে ট্যাপ করুন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...filteredParties.map(
                  (party) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: (party.isCustomer
                              ? const Color(0xFF0EA5E9)
                              : const Color(0xFFF59E0B))
                              .withValues(alpha: 0.15),
                          child: Text(
                            party.name.isNotEmpty
                                ? party.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: party.isCustomer
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFFF59E0B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                party.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${party.isCustomer ? provider.tr("Customer", "কাস্টমার") : provider.tr("Supplier", "সাপ্লায়ার")} • ${party.phone.isEmpty ? provider.tr("No phone", "ফোন নেই") : party.phone}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                party.dueAmount > 0
                                    ? '${party.isCustomer ? provider.tr("Receivable Due", "পাওনা বাকি") : provider.tr("Payable Due", "দেনা বাকি")}: ${provider.formatMoney(party.dueAmount)}'
                                    : provider.tr('Settled Up ✓', 'পরিশোধিত ✓'),
                                style: TextStyle(
                                  color: party.dueAmount > 0
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF10B981),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: provider.tr('Edit Party', 'এডিট'),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF38BDF8),
                            size: 18,
                          ),
                          onPressed: () =>
                              _showPartySheet(context, existing: party),
                        ),
                        IconButton(
                          tooltip: provider.tr('Delete Party', 'মুছুন'),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          onPressed: () async {
                            final ok = await AppFeedback.confirmDelete(
                              context,
                              title: provider.tr(
                                'Delete "${party.name}"?',
                                '"${party.name}" মুছবেন?',
                              ),
                              message: provider.tr(
                                'Remove this party and their payment history?',
                                'এই পার্টি ও তার পরিশোধের ইতিহাস মুছে ফেলবেন?',
                              ),
                            );
                            if (ok) provider.deleteParty(party.id);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (party.dueAmount > 0)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () =>
                                _showPartyPaymentSheet(context, party),
                            icon: const Icon(Icons.payments_outlined, size: 14),
                            label: Text(
                              party.isCustomer
                                  ? provider.tr('Collect Due', 'বাকি আদায়')
                                  : provider.tr('Pay Supplier', 'বাকি পরিশোধ'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (party.paymentHistory.isNotEmpty)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () =>
                                _showPartyHistorySheet(context, party),
                            icon: const Icon(Icons.history_rounded, size: 14),
                            label: Text(
                              '${provider.tr("History", "ইতিহাস")} (${party.paymentHistory.length})',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        if (party.phone.isNotEmpty)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFCBD5E1),
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _callParty(party.phone),
                            icon: const Icon(Icons.call_outlined, size: 14),
                            label: Text(
                              provider.tr('Call', 'কল'),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        if (party.phone.isNotEmpty && party.dueAmount > 0)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () =>
                                _whatsAppReminder(party, provider),
                            icon: const Icon(Icons.chat_outlined, size: 14),
                            label: Text(
                              provider.tr('Remind', 'রিমাইন্ডার'),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showPartySheet(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(
          provider.tr('Add Party', 'নতুন পার্টি যোগ'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 4: INVOICES & VOUCHERS AUDIT TRAIL (EMPTY STATE + ZERO-SAFE CHART)
  // ===========================================================================
  Widget _buildInvoicesAuditTab(
      BuildContext context,
      TransactionProvider provider,
      ) {
    final int saleCount =
        provider.businessTxs.where((t) => t.type == 'Sale').length;
    final int purchCount =
        provider.businessTxs.where((t) => t.type == 'Purchase').length;
    final int expCount =
        provider.businessTxs.where((t) => t.type == 'Expense').length;
    final int dueCount = provider.businessTxs
        .where(
          (t) => t.type == 'Due Collection' || t.type == 'Supplier Payment',
    )
        .length;

    final filteredTxs = provider.businessTxs.where((t) {
      if (_txFilter == 'With Memo' && !t.hasAttachment) return false;
      if (_txFilter == 'Due Settled' &&
          t.type != 'Due Collection' &&
          t.type != 'Supplier Payment') {
        return false;
      }
      if (_txFilter != 'All' &&
          _txFilter != 'With Memo' &&
          _txFilter != 'Due Settled' &&
          t.type != _txFilter) {
        return false;
      }
      if (_voucherSearchQuery.isNotEmpty) {
        final q = _voucherSearchQuery.toLowerCase();
        return t.title.toLowerCase().contains(q) ||
            t.partyName.toLowerCase().contains(q) ||
            t.type.toLowerCase().contains(q) ||
            t.amount.toString().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 118),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: RealisticDonutChart(
              values: [
                saleCount.toDouble(),
                purchCount.toDouble(),
                expCount.toDouble(),
                dueCount.toDouble(),
              ],
              colors: const [
                Color(0xFF10B981),
                Color(0xFFF59E0B),
                Color(0xFFEF4444),
                Color(0xFF38BDF8),
              ],
              labels: [
                '${provider.tr("Sales", "বিক্রয়")} ($saleCount)',
                '${provider.tr("Purchases", "ক্রয়")} ($purchCount)',
                '${provider.tr("Expenses", "ব্যয়")} ($expCount)',
                '${provider.tr("Due Logs", "বকেয়া")} ($dueCount)',
              ],
              centerTitle: provider.tr('Total', 'মোট'),
              centerValue: '${provider.businessTxs.length}',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _voucherSearchCtrl,
            onChanged: (v) => setState(() => _voucherSearchQuery = v.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: provider.tr(
                'Search vouchers by item, party, or amount...',
                'পণ্য, পার্টি বা টাকা দিয়ে ভাউচার খুঁজুন...',
              ),
              hintStyle:
              const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              prefixIcon:
              const Icon(Icons.search, color: Color(0xFF38BDF8), size: 18),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'All',
              'Sale',
              'Purchase',
              'Expense',
              'Due Settled',
              'With Memo',
            ].map((f) {
              final isSel = _txFilter == f;
              return ChoiceChip(
                label: Text(
                  f,
                  style: TextStyle(
                    color: isSel ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: isSel,
                selectedColor: const Color(0xFF0EA5E9),
                backgroundColor: const Color(0xFF1E293B),
                showCheckmark: false,
                onSelected: (_) => setState(() => _txFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          if (filteredTxs.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: Color(0xFF38BDF8),
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    provider.tr(
                      'No POS vouchers yet.',
                      'এখনো কোনো পিওএস ভাউচার নেই।',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.tr(
                      'Tap "+ Record POS Entry" below to create sales, purchases, expenses, and printable invoices.',
                      'বিক্রয়, ক্রয় বা ব্যয়ের ভাউচার তৈরি করতে নিচে "+ নতুন ভাউচার যোগ" বাটনে ট্যাপ করুন।',
                    ),
                    style:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...filteredTxs.map((tx) => _buildBizTxTile(context, tx, provider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () =>
            _showSmartPosCheckoutSheet(context, initialType: 'Sale'),
        icon: const Icon(Icons.add_shopping_cart),
        label: Text(
          provider.tr('Record POS Entry', 'নতুন ভাউচার যোগ'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBizTxTile(
      BuildContext context,
      BusinessTxModel tx,
      TransactionProvider provider,
      ) {
    Color c = const Color(0xFF10B981);
    IconData icon = Icons.point_of_sale_rounded;
    if (tx.type == 'Purchase') {
      c = const Color(0xFFF59E0B);
      icon = Icons.shopping_bag_outlined;
    } else if (tx.type == 'Expense') {
      c = const Color(0xFFEF4444);
      icon = Icons.money_off_csred_rounded;
    } else if (tx.type == 'Due Collection' || tx.type == 'Supplier Payment') {
      c = const Color(0xFF38BDF8);
      icon = Icons.payments_outlined;
    }

    final bool canEdit =
        tx.type == 'Sale' || tx.type == 'Purchase' || tx.type == 'Expense';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${tx.type}${tx.partyName.isNotEmpty ? " • ${tx.partyName}" : ""} • ${tx.date}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
                if (tx.type == 'Sale' && tx.costTotal > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${provider.tr("Cost", "ক্রয়")}: ${provider.formatMoney(tx.costTotal)} • ${provider.tr("Profit", "লাভ")}: ${provider.formatMoney(tx.saleProfit)}',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (tx.dueAmount > 0 && tx.type == 'Sale') ...[
                  const SizedBox(height: 2),
                  Text(
                    '${provider.tr("Paid", "জমা")}: ${provider.formatMoney(tx.paidAmount)} • ${provider.tr("Due", "বাকি")}: ${provider.formatMoney(tx.dueAmount)}',
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (tx.hasAttachment) ...[
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: () => AttachmentHelper.viewAttachment(
                      context,
                      tx.attachmentBase64,
                      tx.attachmentName,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tx.attachmentName.isNotEmpty
                            ? tx.attachmentName
                            : provider.tr('View Memo', 'মেমো দেখুন'),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                provider.formatMoney(tx.amount),
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _showInvoicePrintPicker(context, tx, provider),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: Color(0xFF38BDF8),
                        size: 18,
                      ),
                    ),
                  ),
                  if (canEdit)
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _showSmartPosCheckoutSheet(
                        context,
                        initialType: tx.type,
                        existing: tx,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF94A3B8),
                          size: 18,
                        ),
                      ),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () async {
                      final ok = await AppFeedback.confirmDelete(
                        context,
                        title: provider.tr(
                          'Delete Voucher?',
                          'ভাউচার ডিলিট করবেন?',
                        ),
                        message: provider.tr(
                          'Remove "${tx.title}" (${provider.formatMoney(tx.amount)})?',
                          '"${tx.title}" (${provider.formatMoney(tx.amount)}) মুছে ফেলবেন?',
                        ),
                      );
                      if (ok) provider.deleteBusinessTx(tx.id);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.delete_outline,
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell(String label, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              val,
              style: TextStyle(
                color: color,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SMART POS CHECKOUT SHEET (CLAMPED STOCK, COGS, PARTY, DISCOUNT, VAT, PAID/DUE)
  // ===========================================================================
  void _showSmartPosCheckoutSheet(
      BuildContext context, {
        required String initialType,
        BusinessTxModel? existing,
      }) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();

    String selectedType = existing?.type ?? initialType;
    String selectedProductId = existing?.productId.isNotEmpty == true
        ? existing!.productId
        : 'custom';
    String selectedPartyId = existing?.partyId ?? '';
    int quantity = existing?.quantity ?? 1;

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final subtotalCtrl = TextEditingController(
      text: existing != null
          ? (existing.amount + existing.discountAmount - existing.vatAmount)
          .toStringAsFixed(2)
          : '',
    );
    final discountCtrl = TextEditingController(
      text: existing != null && existing.discountAmount > 0
          ? existing.discountAmount.toStringAsFixed(2)
          : '',
    );
    final vatPctCtrl = TextEditingController();
    final paidCtrl = TextEditingController(
      text: existing != null && existing.paidAmount > 0
          ? existing.paidAmount.toStringAsFixed(2)
          : '',
    );

    bool discountIsPercent = false;
    String attBase64 = existing?.attachmentBase64 ?? '';
    String attName = existing?.attachmentName ?? '';
    String? stockErrorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final int prodIdx = selectedProductId != 'custom'
              ? provider.products.indexWhere((p) => p.id == selectedProductId)
              : -1;
          final ProductModel? activeProduct =
          prodIdx != -1 ? provider.products[prodIdx] : null;

          final double subtotal =
              AppCurrency.parseAmount(subtotalCtrl.text) ?? 0.0;
          final double rawDiscount =
              AppCurrency.parseAmount(discountCtrl.text) ?? 0.0;
          final double discountAmt = discountIsPercent
              ? (subtotal * (rawDiscount.clamp(0.0, 100.0) / 100.0))
              : rawDiscount.clamp(0.0, subtotal);
          final double afterDiscount = math.max(0.0, subtotal - discountAmt);
          final double vatPct =
          (double.tryParse(vatPctCtrl.text.trim()) ?? 0.0).clamp(0.0, 100.0);
          final double vatAmt = afterDiscount * (vatPct / 100.0);
          final double grandTotal = double.parse(
            (afterDiscount + vatAmt).toStringAsFixed(2),
          );

          final double paidAmt = paidCtrl.text.trim().isEmpty
              ? grandTotal
              : (AppCurrency.parseAmount(paidCtrl.text) ?? 0.0)
              .clamp(0.0, grandTotal);
          final double dueAmt = math.max(0.0, grandTotal - paidAmt);

          final double estCostTotal =
          (selectedType == 'Sale' && activeProduct != null)
              ? (activeProduct.costPrice * quantity)
              : (existing?.costTotal ?? 0.0);
          final double estProfit =
          selectedType == 'Sale' ? (grandTotal - estCostTotal) : 0.0;

          final bool isSaleWithProduct =
              existing == null && selectedType == 'Sale' && activeProduct != null;
          final bool outOfStock =
              activeProduct != null && isSaleWithProduct && activeProduct.stock <= 0;
          final bool atStockLimit = activeProduct != null &&
              isSaleWithProduct &&
              quantity >= activeProduct.stock;

          final relevantParties = provider.parties.where((p) {
            if (selectedType == 'Sale') return p.isCustomer;
            if (selectedType == 'Purchase') return !p.isCustomer;
            return true;
          }).toList();

          if (selectedPartyId.isNotEmpty &&
              !relevantParties.any((p) => p.id == selectedPartyId)) {
            selectedPartyId = '';
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Form(
              key: formKey,
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
                            existing == null
                                ? provider.tr(
                              'Smart POS Checkout',
                              'স্মার্ট পিওএস চেকআউট',
                            )
                                : provider.tr(
                              'Edit POS Voucher',
                              'ভাউচার সম্পাদনা করুন',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // TYPE SELECTOR
                    Row(
                      children: ['Sale', 'Purchase', 'Expense'].map((t) {
                        final isSel = selectedType == t;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    color: isSel
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              selected: isSel,
                              selectedColor: const Color(0xFF0EA5E9),
                              backgroundColor: const Color(0xFF0F172A),
                              showCheckmark: false,
                              onSelected: (_) => setSheetState(() {
                                selectedType = t;
                                stockErrorText = null;
                                if (t == 'Expense') {
                                  selectedProductId = 'custom';
                                } else if (activeProduct != null &&
                                    t == 'Sale' &&
                                    quantity > activeProduct.stock) {
                                  quantity = math.max(1, activeProduct.stock);
                                  subtotalCtrl.text =
                                      (activeProduct.price * quantity)
                                          .toStringAsFixed(2);
                                }
                              }),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // PRODUCT PICKER + STOCK-CLAMPED QUANTITY STEPPER
                    if (existing == null &&
                        selectedType != 'Expense' &&
                        provider.products.isNotEmpty) ...[
                      Text(
                        provider.tr(
                          'Select Inventory Product (Auto-Updates Stock):',
                          'ইনভেন্টরি পণ্য নির্বাচন করুন (অটো স্টক সমন্বয়):',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: Text(
                              provider.tr('Custom Item', 'কাস্টম আইটেম'),
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: selectedProductId == 'custom',
                            selectedColor: const Color(0xFF0EA5E9),
                            labelStyle: TextStyle(
                              color: selectedProductId == 'custom'
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                            backgroundColor: const Color(0xFF0F172A),
                            showCheckmark: false,
                            onSelected: (_) => setSheetState(() {
                              selectedProductId = 'custom';
                              stockErrorText = null;
                            }),
                          ),
                          ...provider.products.map((p) {
                            final isSel = selectedProductId == p.id;
                            return ChoiceChip(
                              label: Text(
                                '${p.name} (Stock: ${p.stock} • ${provider.formatMoney(selectedType == 'Purchase' && p.costPrice > 0 ? p.costPrice : p.price)})',
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: isSel,
                              selectedColor: const Color(0xFF0EA5E9),
                              labelStyle: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                              ),
                              backgroundColor: const Color(0xFF0F172A),
                              showCheckmark: false,
                              onSelected: (_) => setSheetState(() {
                                selectedProductId = p.id;
                                stockErrorText = null;
                                quantity = selectedType == 'Sale'
                                    ? (p.stock > 0 ? 1 : 0)
                                    : 1;
                                final double unitRate =
                                selectedType == 'Purchase' && p.costPrice > 0
                                    ? p.costPrice
                                    : p.price;
                                titleCtrl.text =
                                '${p.name} (x${math.max(1, quantity)})';
                                subtotalCtrl.text =
                                    (unitRate * math.max(1, quantity))
                                        .toStringAsFixed(2);
                              }),
                            );
                          }),
                        ],
                      ),
                      if (activeProduct != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: outOfStock
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF334155),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Color(0xFF38BDF8),
                                    ),
                                    onPressed: quantity > 1
                                        ? () {
                                      setSheetState(() {
                                        quantity--;
                                        stockErrorText = null;
                                        final unitRate =
                                        selectedType == 'Purchase' &&
                                            activeProduct
                                                .costPrice >
                                                0
                                            ? activeProduct.costPrice
                                            : activeProduct.price;
                                        titleCtrl.text =
                                        '${activeProduct.name} (x$quantity)';
                                        subtotalCtrl.text =
                                            (unitRate * quantity)
                                                .toStringAsFixed(2);
                                      });
                                    }
                                        : null,
                                  ),
                                  Text(
                                    'Qty: $quantity',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle_outline,
                                      color: atStockLimit
                                          ? const Color(0xFF475569)
                                          : const Color(0xFF38BDF8),
                                    ),
                                    onPressed: (outOfStock || atStockLimit)
                                        ? null
                                        : () {
                                      setSheetState(() {
                                        quantity++;
                                        stockErrorText = null;
                                        final unitRate =
                                        selectedType == 'Purchase' &&
                                            activeProduct
                                                .costPrice >
                                                0
                                            ? activeProduct.costPrice
                                            : activeProduct.price;
                                        titleCtrl.text =
                                        '${activeProduct.name} (x$quantity)';
                                        subtotalCtrl.text =
                                            (unitRate * quantity)
                                                .toStringAsFixed(2);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (isSaleWithProduct)
                                Text(
                                  outOfStock
                                      ? provider.tr(
                                    'Out of stock (0 available). Restock in Inventory first.',
                                    'স্টক শেষ (০ টি)। প্রথমে ইনভেন্টরিতে স্টক যোগ করুন।',
                                  )
                                      : (atStockLimit
                                      ? provider.tr(
                                    'Max in stock reached: ${activeProduct.stock} units',
                                    'সর্বোচ্চ স্টক সীমা: ${activeProduct.stock} টি',
                                  )
                                      : provider.tr(
                                    'Available in stock: ${activeProduct.stock} units',
                                    'স্টকে রয়েছে: ${activeProduct.stock} টি',
                                  )),
                                  style: TextStyle(
                                    color: outOfStock
                                        ? const Color(0xFFFCA5A5)
                                        : (atStockLimit
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFF94A3B8)),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                    ],

                    if (stockErrorText != null) ...[
                      Text(
                        stockErrorText!,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    TextFormField(
                      controller: titleCtrl,
                      validator: (v) => AppValidators.requiredText(
                        v,
                        provider.tr('Item / Memo', 'বিবরণ'),
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Item / Invoice Memo *',
                          'পণ্যের নাম বা বিবরণ *',
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        errorStyle: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: subtotalCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: AppValidators.amountFormatters,
                      validator: (v) => AppValidators.positiveAmount(
                        v,
                        label: provider.tr('Amount', 'পরিমাণ'),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Subtotal Amount (${provider.currencySymbol}) *',
                          'মোট মূল্য (${provider.currencySymbol}) *',
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        errorStyle: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // DISCOUNT & VAT ROW (FOR SALE / PURCHASE)
                    if (selectedType != 'Expense') ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: discountCtrl,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: AppValidators.amountFormatters,
                              onChanged: (_) => setSheetState(() {}),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: discountIsPercent
                                    ? provider.tr('Discount (%)', 'ডিসকাউন্ট (%)')
                                    : provider.tr(
                                  'Discount (${provider.currencySymbol})',
                                  'ডিসকাউন্ট (${provider.currencySymbol})',
                                ),
                                labelStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                                suffixIcon: TextButton(
                                  onPressed: () => setSheetState(
                                        () => discountIsPercent = !discountIsPercent,
                                  ),
                                  child: Text(
                                    discountIsPercent
                                        ? '%'
                                        : provider.currencySymbol,
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: vatPctCtrl,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: AppValidators.amountFormatters,
                              onChanged: (_) => setSheetState(() {}),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: provider.tr('VAT / Tax (%)', 'ভ্যাট (%)'),
                                labelStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // PARTY SELECTOR + PAID VS DUE SPLIT
                      if (relevantParties.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedPartyId,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: '',
                                  child: Text(
                                    selectedType == 'Sale'
                                        ? provider.tr(
                                      'Walk-in Customer (Optional)',
                                      'সাধারণ কাস্টমার (ঐচ্ছিক)',
                                    )
                                        : provider.tr(
                                      'Select Supplier (Optional)',
                                      'সাপ্লায়ার নির্বাচন (ঐচ্ছিক)',
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                                ...relevantParties.map(
                                      (p) => DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                      '${p.name} (Due: ${provider.formatMoney(p.dueAmount)})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setSheetState(() => selectedPartyId = v ?? ''),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      TextFormField(
                        controller: paidCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: AppValidators.amountFormatters,
                        onChanged: (_) => setSheetState(() {}),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: provider.tr(
                            'Paid Now (Blank = Full ${provider.formatMoney(grandTotal)})',
                            'নগদ পরিশোধ (খালি রাখলে সম্পূর্ণ ${provider.formatMoney(grandTotal)})',
                          ),
                          labelStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // LIVE GRAND TOTAL / PROFIT / DUE SUMMARY BAR
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  provider.tr('Grand Total', 'সর্বমোট বিল'),
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  provider.formatMoney(grandTotal),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            if (selectedType == 'Sale' && estCostTotal > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    provider.tr(
                                      'Estimated Profit (after COGS)',
                                      'আনুমানিক লাভ (ক্রয়মূল্য বাদে)',
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  Text(
                                    provider.formatMoney(estProfit),
                                    style: TextStyle(
                                      color: estProfit >= 0
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (dueAmt > 0.009) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    provider.tr(
                                      'Remaining Due',
                                      'বকেয়া পরিমাণ',
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  Text(
                                    provider.formatMoney(dueAmt),
                                    style: const TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // MEMO ATTACHMENT WITH THUMBNAIL
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: attBase64.isNotEmpty
                              ? const Color(0xFF10B981)
                              : const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (attBase64.isNotEmpty)
                            GestureDetector(
                              onTap: () => AttachmentHelper.viewAttachment(
                                context,
                                attBase64,
                                attName,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: buildTrueColorWrapper(
                                  isDarkMode: provider.isDarkMode,
                                  child: Image.memory(
                                    base64Decode(attBase64),
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.attach_file,
                              color: Color(0xFF38BDF8),
                              size: 18,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              attName.isEmpty
                                  ? provider.tr(
                                'Attach POS Memo / Invoice Photo',
                                'ভাউচার বা রসিদ যুক্ত করুন',
                              )
                                  : attName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: attName.isEmpty
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF10B981),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked =
                              await AttachmentHelper.pickReceiptOrMemo(
                                context,
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  attBase64 = picked['base64'] ?? '';
                                  attName = picked['name'] ?? '';
                                });
                              }
                            },
                            icon: const Icon(
                              Icons.upload_file,
                              size: 16,
                              color: Color(0xFF38BDF8),
                            ),
                            label: Text(
                              attBase64.isEmpty
                                  ? provider.tr('Upload', 'আপলোড')
                                  : provider.tr('Change', 'বদলান'),
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        if (outOfStock) {
                          setSheetState(() {
                            stockErrorText = provider.tr(
                              'Cannot sell out-of-stock item.',
                              'স্টক শূন্য থাকায় বিক্রয় করা যাবে না।',
                            );
                          });
                          return;
                        }
                        if (existing == null &&
                            selectedType == 'Sale' &&
                            activeProduct != null &&
                            quantity > activeProduct.stock) {
                          setSheetState(() {
                            stockErrorText = provider.tr(
                              'Only ${activeProduct.stock} units available in stock.',
                              'স্টকে মাত্র ${activeProduct.stock} টি রয়েছে।',
                            );
                          });
                          return;
                        }
                        if (grandTotal <= 0) return;

                        final String partyName = selectedPartyId.isNotEmpty
                            ? relevantParties
                            .firstWhere((p) => p.id == selectedPartyId)
                            .name
                            : '';

                        provider.saveBusinessTx(
                          id: existing?.id,
                          title: titleCtrl.text.trim(),
                          type: selectedType,
                          amount: grandTotal,
                          attachmentBase64: attBase64,
                          attachmentName: attName,
                          productId: activeProduct?.id ?? '',
                          productName: activeProduct?.name ?? '',
                          quantity: math.max(1, quantity),
                          costTotal: estCostTotal,
                          discountAmount: discountAmt,
                          vatAmount: vatAmt,
                          partyId: selectedPartyId,
                          partyName: partyName,
                          paidAmount: paidAmt,
                          dueAmount: dueAmt,
                          autoAdjustStock:
                          existing == null && activeProduct != null,
                          autoUpdatePartyDue:
                          existing == null && selectedPartyId.isNotEmpty,
                        );
                        Navigator.pop(ctx);
                        AppFeedback.showInfo(
                          context,
                          provider.tr(
                            'POS record saved.',
                            'পিওএস ভাউচার সেভ হয়েছে।',
                          ),
                        );
                      },
                      child: Text(
                        provider.tr('Save POS Record', 'পিওএস ভাউচার সেভ করুন'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // PRODUCT SHEET (WITH COST PRICE + SELLING PRICE + INLINE VALIDATION)
  // ===========================================================================
  void _showProductSheet(BuildContext context, {ProductModel? existing}) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final costCtrl = TextEditingController(
      text: existing != null && existing.costPrice > 0
          ? existing.costPrice.toStringAsFixed(2)
          : '',
    );
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );
    final stockCtrl = TextEditingController(
      text: existing != null ? existing.stock.toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final double costVal = AppCurrency.parseAmount(costCtrl.text) ?? 0.0;
          final double sellVal = AppCurrency.parseAmount(priceCtrl.text) ?? 0.0;
          final double unitProfit = sellVal - costVal;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null
                          ? provider.tr(
                        'Add Inventory Product',
                        'নতুন পণ্য যোগ করুন',
                      )
                          : provider.tr('Edit Product', 'পণ্য সম্পাদনা করুন'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameCtrl,
                      validator: (v) => AppValidators.requiredText(
                        v,
                        provider.tr('Product name', 'পণ্যের নাম'),
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr('Product Name *', 'পণ্যের নাম *'),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        errorStyle: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: costCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: AppValidators.amountFormatters,
                            validator: (v) => AppValidators.nonNegativeAmount(
                              v,
                              label: provider.tr('Cost price', 'ক্রয়মূল্য'),
                            ),
                            onChanged: (_) => setSheetState(() {}),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: provider.tr(
                                'Cost Price (${provider.currencySymbol}) *',
                                'ক্রয়মূল্য (${provider.currencySymbol}) *',
                              ),
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              errorStyle: const TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontSize: 11,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: AppValidators.amountFormatters,
                            validator: (v) => AppValidators.positiveAmount(
                              v,
                              label: provider.tr('Selling price', 'বিক্রয়মূল্য'),
                            ),
                            onChanged: (_) => setSheetState(() {}),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: provider.tr(
                                'Selling Price (${provider.currencySymbol}) *',
                                'বিক্রয়মূল্য (${provider.currencySymbol}) *',
                              ),
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              errorStyle: const TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontSize: 11,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (sellVal > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${provider.tr("Unit Profit", "প্রতি ইউনিট লাভ")}: ${provider.formatMoney(unitProfit)} (${((unitProfit / sellVal) * 100).toStringAsFixed(1)}% margin)',
                        style: TextStyle(
                          color: unitProfit >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFFCA5A5),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final parsed = int.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed < 0) {
                          return provider.tr(
                            'Enter a valid stock quantity (0 or more)',
                            'সঠিক স্টক সংখ্যা লিখুন',
                          );
                        }
                        return null;
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText:
                        provider.tr('Stock Quantity *', 'স্টক সংখ্যা *'),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        errorStyle: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        final sell = AppCurrency.parseAmount(priceCtrl.text);
                        final cost = AppCurrency.parseAmount(costCtrl.text) ?? 0;
                        final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                        if (sell == null || sell <= 0) return;

                        provider.saveProduct(
                          id: existing?.id,
                          name: nameCtrl.text.trim(),
                          price: sell,
                          costPrice: cost,
                          stock: stock,
                        );
                        Navigator.pop(ctx);
                        AppFeedback.showInfo(
                          context,
                          provider.tr('Product saved.', 'পণ্য সেভ হয়েছে।'),
                        );
                      },
                      child: Text(
                        provider.tr('Save Product', 'পণ্য সেভ করুন'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // PARTY SHEET (STRICT PHONE VALIDATION) + PARTIAL DUE PAYMENT + HISTORY
  // ===========================================================================
  void _showPartySheet(BuildContext context, {PartyModel? existing}) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final dueCtrl = TextEditingController(
      text: existing != null && existing.dueAmount > 0
          ? existing.dueAmount.toStringAsFixed(2)
          : '',
    );
    bool isCust = existing?.isCustomer ?? true;

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
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? provider.tr(
                      'Add Customer / Supplier',
                      'কাস্টমার বা সাপ্লায়ার যোগ করুন',
                    )
                        : provider.tr('Edit Party', 'পার্টি সম্পাদনা করুন'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(provider.tr('Customer', 'কাস্টমার')),
                          ),
                          selected: isCust,
                          selectedColor: const Color(0xFF0EA5E9),
                          labelStyle: TextStyle(
                            color: isCust
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: const Color(0xFF0F172A),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => isCust = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(provider.tr('Supplier', 'সাপ্লায়ার')),
                          ),
                          selected: !isCust,
                          selectedColor: const Color(0xFFF59E0B),
                          labelStyle: TextStyle(
                            color: !isCust
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: const Color(0xFF0F172A),
                          showCheckmark: false,
                          onSelected: (_) =>
                              setSheetState(() => isCust = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    validator: (v) => AppValidators.requiredText(
                      v,
                      provider.tr('Party name', 'পার্টির নাম'),
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Party Name *', 'নাম *'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      errorStyle: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 11.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: AppValidators.digitsAndPlusOnly,
                    validator: (v) =>
                        AppValidators.phoneNumber(v, required: false),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr(
                        'Phone Number (Digits only, Optional)',
                        'ফোন নম্বর (শুধু সংখ্যা, ঐচ্ছিক)',
                      ),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      errorStyle: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 11.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dueCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: AppValidators.amountFormatters,
                    validator: (v) => AppValidators.nonNegativeAmount(
                      v,
                      label: provider.tr('Pending due', 'বাকি টাকা'),
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr(
                        'Pending Due Amount (${provider.currencySymbol})',
                        'বাকি টাকা (${provider.currencySymbol})',
                      ),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      errorStyle: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 11.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      provider.saveParty(
                        id: existing?.id,
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        isCustomer: isCust,
                        dueAmount: AppCurrency.parseAmount(dueCtrl.text) ?? 0.0,
                      );
                      Navigator.pop(ctx);
                      AppFeedback.showInfo(
                        context,
                        provider.tr('Party saved.', 'পার্টি সেভ হয়েছে।'),
                      );
                    },
                    child: Text(
                      provider.tr('Save Party', 'সেভ করুন'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Partial or full due settlement WITHOUT inflating Total Sales or Net Profit.
  void _showPartyPaymentSheet(BuildContext context, PartyModel party) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(
      text: party.dueAmount.toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  party.isCustomer
                      ? provider.tr(
                    'Collect Due from ${party.name}',
                    '${party.name} থেকে বাকি আদায়',
                  )
                      : provider.tr(
                    'Pay Supplier ${party.name}',
                    '${party.name}-কে বাকি পরিশোধ',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17.5,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '${provider.tr("Current Pending Due", "বর্তমান বাকি")}: ${provider.formatMoney(party.dueAmount)} • ${provider.tr("Logged as Due Collection (does not inflate Sales)", "বকেয়া আদায় হিসেবে যুক্ত হবে")}',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: AppValidators.amountFormatters,
                        validator: (v) {
                          final base = AppValidators.positiveAmount(
                            v,
                            label: provider.tr('Payment', 'পরিশোধ'),
                          );
                          if (base != null) return base;
                          final val = AppCurrency.parseAmount(v!) ?? 0.0;
                          if (val > party.dueAmount + 0.009) {
                            return provider.tr(
                              'Cannot exceed current due (${provider.formatMoney(party.dueAmount)})',
                              'বর্তমান বাকির চেয়ে বেশি হতে পারবে না',
                            );
                          }
                          return null;
                        },
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: provider.tr(
                            'Payment Amount (Partial or Full) *',
                            'পরিশোধের পরিমাণ (আংশিক বা সম্পূর্ণ) *',
                          ),
                          labelStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          errorStyle: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 11.5,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF10B981).withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () => amountCtrl.text =
                          party.dueAmount.toStringAsFixed(2),
                      child: Text(
                        provider.tr('Full Due', 'সম্পূর্ণ'),
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: provider.tr(
                      'Note / Payment Method (Optional)',
                      'নোট / মাধ্যম (ঐচ্ছিক)',
                    ),
                    hintText: provider.tr('e.g., Cash / bKash', 'যেমন: ক্যাশ / বিকাশ'),
                    hintStyle: const TextStyle(color: Color(0xFF475569)),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final amt = AppCurrency.parseAmount(amountCtrl.text);
                    if (amt == null || amt <= 0) return;

                    final ok = provider.recordPartyPayment(
                      partyId: party.id,
                      amount: amt,
                      note: noteCtrl.text.trim(),
                    );
                    if (ok) {
                      Navigator.pop(ctx);
                      AppFeedback.showInfo(
                        context,
                        provider.tr(
                          'Recorded ${provider.formatMoney(amt)} payment for ${party.name}.',
                          '${party.name}-এর ${provider.formatMoney(amt)} পরিশোধ যুক্ত হয়েছে।',
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    provider.tr('Record Payment', 'পরিশোধ সেভ করুন'),
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

  void _showPartyHistorySheet(BuildContext context, PartyModel party) {
    final provider = context.read<TransactionProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${party.name} — ${provider.tr("Payment History", "পরিশোধের ইতিহাস")}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: Color(0xFF334155)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: party.paymentHistory.length,
                itemBuilder: (_, i) {
                  final p = party.paymentHistory[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                    title: Text(
                      provider.formatMoney(p.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${p.date}${p.note.isNotEmpty ? " • ${p.note}" : ""}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}