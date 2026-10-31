import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'main_navigation.dart';
import 'providers/transaction_provider.dart';

class BusinessNavigationScreen extends StatefulWidget {
  const BusinessNavigationScreen({super.key});

  @override
  State<BusinessNavigationScreen> createState() => _BusinessNavigationScreenState();
}

class _BusinessNavigationScreenState extends State<BusinessNavigationScreen> {
  int _selectedIndex = 0;

  // Search & Filter states across all 4 tabs
  String _txFilter = 'All'; // 'All', 'Sale', 'Purchase', 'Expense', 'With Memo'
  String _stockFilter = 'All'; // 'All', 'Low Stock', 'Out of Stock'
  String _partyFilter = 'All'; // 'All', 'Customers', 'Suppliers', 'With Due'
  String _searchQuery = '';

  // ===========================================================================
  // 1-TAP OFFICIAL PDF POS INVOICE / RECEIPT GENERATOR
  // ===========================================================================
  Future<void> _generatePosInvoicePdf(BusinessTxModel tx, TransactionProvider provider) async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FINBLEND ENTERPRISE POS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        provider.userOrganization.isNotEmpty ? provider.userOrganization : 'Official POS Invoice & Voucher',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Text(
                    'INVOICE #${tx.id.substring(math.max(0, tx.id.length - 6))}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Divider(height: 18),
              pw.Text('Date & Time: ${tx.date}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Voucher Type: ${tx.type.toUpperCase()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Issued By: ${provider.userName} (${provider.cloudEmail})', style: const pw.TextStyle(fontSize: 10)),
              if (tx.hasAttachment)
                pw.Text('Attached Document: ${tx.attachmentName}', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 14),
              pw.TableHelper.fromTextArray(
                headers: ['Item / Memo Description', 'Category', 'Amount (BDT)'],
                data: [
                  [tx.title, tx.type, 'BDT ${tx.amount.toStringAsFixed(2)}'],
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'GRAND TOTAL: BDT ${tx.amount.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text('Thank you for your business! • FinBlend Cloud POS Suite', style: const pw.TextStyle(fontSize: 8)),
              ),
            ],
          ),
        ),
      );
      final Uint8List bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: 'FinBlend_POS_Invoice_${tx.id}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Invoice Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final bool isWideWeb = MediaQuery.of(context).size.width >= 800;

    final appBarActions = [
      // 1-TAP BENGALI / ENGLISH SWITCHER
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
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
      IconButton(
        tooltip: provider.tr('Cloud Sync', 'ক্লাউড সিঙ্ক'),
        icon: provider.isSyncing
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)))
            : const Icon(Icons.cloud_done_outlined, color: Color(0xFF38BDF8)),
        onPressed: () => ProfileScreen.showCloudSyncSheet(context),
      ),
      IconButton(
        tooltip: provider.tr('Notifications & Stock Alerts', 'নোটিফিকেশন ও স্টক এলার্ট'),
        icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
        onPressed: () => ProfileScreen.showNotificationsSheet(context),
      ),
      IconButton(
        tooltip: provider.tr('Switch Theme', 'থিম পরিবর্তন'),
        icon: Icon(provider.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: const Color(0xFF38BDF8)),
        onPressed: () => provider.toggleDarkMode(!provider.isDarkMode),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
            foregroundColor: const Color(0xFF38BDF8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                  (route) => false,
            );
          },
          icon: const Icon(Icons.person_outline, size: 16),
          label: Text(provider.tr('Personal Mode', 'ব্যক্তিগত মোড'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
              Text(provider.tr('FinBlend Enterprise POS & ERP', 'ফিনব্লেন্ড বিজনেস পিওএস ও ইনভেন্টরি'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          actions: appBarActions,
        ),
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.of(context).size.width >= 1050,
              backgroundColor: const Color(0xFF1E293B),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              indicatorColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
              selectedIconTheme: const IconThemeData(color: Color(0xFF38BDF8)),
              unselectedIconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
              selectedLabelTextStyle: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: Color(0xFF94A3B8)),
              destinations: [
                NavigationRailDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: Text(provider.tr('POS Overview', 'পিওএস হোম'))),
                NavigationRailDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: Text(provider.tr('Inventory ERP', 'স্টক ইনভেন্টরি'))),
                NavigationRailDestination(icon: const Icon(Icons.people_alt_outlined), selectedIcon: const Icon(Icons.people_alt), label: Text(provider.tr('Parties & Dues', 'কাস্টমার ও বাকি'))),
                NavigationRailDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: Text(provider.tr('Invoices & Memos', 'ভাউচার ও রসিদ'))),
              ],
            ),
            const VerticalDivider(width: 1, color: Color(0xFF334155)),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
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
        title: Text(provider.tr('FinBlend POS', 'বিজনেস পিওএস'), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: appBarActions,
      ),
      body: _buildCurrentTab(context, provider),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard, color: Color(0xFF38BDF8)), label: provider.tr('POS Home', 'হোম')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2, color: Color(0xFF38BDF8)), label: provider.tr('Inventory', 'স্টক')),
          NavigationDestination(icon: const Icon(Icons.people_alt_outlined), selectedIcon: const Icon(Icons.people_alt, color: Color(0xFF38BDF8)), label: provider.tr('Parties', 'কাস্টমার')),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long, color: Color(0xFF38BDF8)), label: provider.tr('Invoices', 'ভাউচার')),
        ],
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
  // TAB 1: EXECUTIVE POS OVERVIEW, PROFITABILITY CHART & SMART CHECKOUT
  // ===========================================================================
  Widget _buildPosOverviewTab(BuildContext context, TransactionProvider provider) {
    final double sales = provider.totalSales;
    final double purchases = provider.totalPurchases;
    final double expenses = provider.totalBizExpenses;
    final double profit = provider.netProfit;
    final double marginPct = sales > 0 ? ((profit / sales) * 100).clamp(-100.0, 100.0) : 0.0;
    final double stockValuation = provider.products.fold(0.0, (sum, p) => sum + (p.price * p.stock));
    final double supplierPayables = provider.parties.where((p) => !p.isCustomer).fold(0.0, (s, p) => s + p.dueAmount);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
        children: [
          // 1. 6-METRIC ENTERPRISE KPI SUMMARY CARD
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      provider.tr('ENTERPRISE POS PROFITABILITY', 'ব্যবসায়িক লাভ-ক্ষতির সারসংক্ষেপ'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (profit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${provider.tr("Margin", "মার্জিন")}: ${marginPct.toStringAsFixed(1)}%',
                        style: TextStyle(color: profit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '৳ ${profit.toStringAsFixed(0)} ${provider.tr("Net Profit", "নিট লাভ")}',
                  style: TextStyle(
                    color: profit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
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
                          Expanded(child: _buildStatCell(provider.tr('Total Sales', 'মোট বিক্রয়'), '৳${sales.toStringAsFixed(0)}', const Color(0xFF10B981))),
                          Container(width: 1, height: 30, color: const Color(0xFF334155)),
                          Expanded(child: _buildStatCell(provider.tr('Purchases', 'মাল ক্রয়'), '৳${purchases.toStringAsFixed(0)}', const Color(0xFFF59E0B))),
                          Container(width: 1, height: 30, color: const Color(0xFF334155)),
                          Expanded(child: _buildStatCell(provider.tr('Expenses', 'খরচ'), '৳${expenses.toStringAsFixed(0)}', const Color(0xFFEF4444))),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Divider(color: Color(0xFF334155), height: 1),
                      ),
                      Row(
                        children: [
                          Expanded(child: _buildStatCell(provider.tr('Stock Value', 'স্টক মূল্য'), '৳${stockValuation.toStringAsFixed(0)}', const Color(0xFF38BDF8))),
                          Container(width: 1, height: 30, color: const Color(0xFF334155)),
                          Expanded(child: _buildStatCell(provider.tr('Customer Due', 'কাস্টমার পাওনা'), '৳${provider.totalCustomerDue.toStringAsFixed(0)}', const Color(0xFFF59E0B))),
                          Container(width: 1, height: 30, color: const Color(0xFF334155)),
                          Expanded(child: _buildStatCell(provider.tr('Supplier Due', 'সাপ্লায়ার দেনা'), '৳${supplierPayables.toStringAsFixed(0)}', const Color(0xFFEC4899))),
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
                  subtitle: provider.tr('Auto-deduct stock', 'অটো স্টক সমন্বয়'),
                  color: const Color(0xFF10B981),
                  onTap: () => _showSmartPosCheckoutSheet(context, initialType: 'Sale'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPosActionCard(
                  icon: Icons.shopping_bag_outlined,
                  title: provider.tr('Purchase', 'মাল ক্রয়'),
                  subtitle: provider.tr('Restock inventory', 'স্টক বৃদ্ধি করুন'),
                  color: const Color(0xFFF59E0B),
                  onTap: () => _showSmartPosCheckoutSheet(context, initialType: 'Purchase'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPosActionCard(
                  icon: Icons.money_off_csred_rounded,
                  title: provider.tr('Biz Expense', 'ব্যবসায়িক ব্যয়'),
                  subtitle: provider.tr('Rent, bills & memos', 'ভাড়া, বিল ও মেমো'),
                  color: const Color(0xFFEF4444),
                  onTap: () => _showSmartPosCheckoutSheet(context, initialType: 'Expense'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3. POS REVENUE VS COST DONUT CHART
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
                  provider.tr('POS Revenue, Purchase & Expense Chart', 'বিক্রয়, ক্রয় এবং খরচের তুলনামূলক চার্ট'),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [
                    sales > 0 ? sales : 1,
                    purchases > 0 ? purchases : 0,
                    expenses > 0 ? expenses : 0,
                  ],
                  colors: const [Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444)],
                  labels: [
                    '${provider.tr("Sales", "মোট বিক্রয়")} (৳${sales.toStringAsFixed(0)})',
                    '${provider.tr("Purchases", "মাল ক্রয়")} (৳${purchases.toStringAsFixed(0)})',
                    '${provider.tr("Expenses", "ব্যয়")} (৳${expenses.toStringAsFixed(0)})',
                  ],
                  centerTitle: provider.tr('Entries', 'মোট ভাউচার'),
                  centerValue: '${provider.businessTxs.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // LOW STOCK ALERT BANNER
          if (provider.lowStockCount > 0) ...[
            GestureDetector(
              onTap: () => setState(() {
                _selectedIndex = 1;
                _stockFilter = 'Low Stock';
              }),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        provider.tr(
                          'Low Stock Alert: ${provider.lowStockCount} product(s) have 5 or fewer units left! Tap to restock.',
                          'স্টক সতর্কতা: ${provider.lowStockCount} টি পণ্যের স্টক ৫ বা তার কম রয়েছে! স্টক বাড়াতে ট্যাপ করুন।',
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
              Text(provider.tr('Recent POS Vouchers & Memos', 'সাম্প্রতিক পিওএস ভাউচার ও রসিদ'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 3),
                child: Text(provider.tr('View All', 'সব দেখুন'), style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (provider.businessTxs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
              child: Text(
                provider.tr(
                  'No POS entries yet. Tap "New POS Sale" below to record a sale, attach a receipt, and generate a PDF invoice.',
                  'এখনো কোনো পিওএস লেনদেন নেই। নিচে "+ নতুন পিওএস বিক্রয়" বাটনে ট্যাপ করে ভাউচার তৈরি করুন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...provider.businessTxs.take(8).map((tx) => _buildBizTxTile(context, tx, provider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showSmartPosCheckoutSheet(context, initialType: 'Sale'),
        icon: const Icon(Icons.point_of_sale_rounded),
        label: Text(provider.tr('New POS Sale', 'নতুন পিওএস বিক্রয়'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: INVENTORY ERP WITH VALUATION CHART & 1-TAP STOCK CONTROLS
  // ===========================================================================
  Widget _buildInventoryErpTab(BuildContext context, TransactionProvider provider) {
    final double healthyCount = provider.products.where((p) => p.stock > 5).length.toDouble();
    final double lowCount = provider.lowStockCount.toDouble();
    final double totalValuation = provider.products.fold(0.0, (s, p) => s + (p.price * p.stock));

    final filteredProducts = provider.products.where((p) {
      if (_stockFilter == 'Low Stock' && p.stock > 5) return false;
      if (_stockFilter == 'Out of Stock' && p.stock > 0) return false;
      if (_searchQuery.isNotEmpty && !p.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
        children: [
          // 1. INVENTORY STOCK HEALTH & VALUATION CHART
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
                  provider.tr('Inventory Stock Health & Valuation Chart', 'স্টক ইনভেন্টরি ও মূল্যায়ন চার্ট'),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [
                    healthyCount > 0 ? healthyCount : (provider.products.isEmpty ? 1 : 0),
                    lowCount > 0 ? lowCount : 0,
                  ],
                  colors: const [Color(0xFF10B981), Color(0xFFEF4444)],
                  labels: [
                    '${provider.tr("Healthy Stock (>5)", "পর্যাপ্ত স্টক")} (${healthyCount.toInt()})',
                    '${provider.tr("Low Stock (<=5)", "কম স্টক")} (${lowCount.toInt()})',
                  ],
                  centerTitle: provider.tr('Total Value', 'স্টক মূল্য'),
                  centerValue: '৳${totalValuation.toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. SEARCH & STOCK FILTERS
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: provider.tr('Search inventory products...', 'পণ্যের নাম দিয়ে খুঁজুন...'),
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8)),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['All', 'Low Stock', 'Out of Stock'].map((f) {
              final isSel = _stockFilter == f;
              return ChoiceChip(
                label: Text(f, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                selected: isSel,
                selectedColor: const Color(0xFF0EA5E9),
                backgroundColor: const Color(0xFF1E293B),
                showCheckmark: false,
                onSelected: (_) => setState(() => _stockFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 3. PRODUCT CARDS WITH +1 / -1 / +10 QUICK BUTTONS
          if (filteredProducts.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
              child: Text(
                provider.tr('No matching products. Tap "+ Add Product" below!', 'কোনো পণ্য পাওয়া যায়নি। নিচে "+ পণ্য যোগ করুন" বাটনে ট্যাপ করুন!'),
                style: const TextStyle(color: Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...filteredProducts.map((p) {
              final bool isLow = p.stock <= 5;
              final double valShare = totalValuation > 0 ? ((p.price * p.stock) / totalValuation).clamp(0.0, 1.0) : 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isLow ? const Color(0xFFEF4444).withValues(alpha: 0.6) : const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isLow ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.inventory_2_outlined, color: isLow ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                              Text(
                                '${provider.tr("Unit Price", "একক মূল্য")}: ৳${p.price.toStringAsFixed(0)} • ${provider.tr("Stock Value", "মোট মূল্য")}: ৳${(p.price * p.stock).toStringAsFixed(0)}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isLow ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${p.stock} ${provider.tr("in stock", "টি স্টকে")}',
                            style: TextStyle(color: isLow ? const Color(0xFFEF4444) : const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
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
                        color: isLow ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9),
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
                                provider.saveProduct(id: p.id, name: p.name, price: p.price, stock: p.stock - 1);
                              }
                            }),
                            const SizedBox(width: 6),
                            _buildStockQuickBtn('+1', () {
                              provider.saveProduct(id: p.id, name: p.name, price: p.price, stock: p.stock + 1);
                            }),
                            const SizedBox(width: 6),
                            _buildStockQuickBtn('+10', () {
                              provider.saveProduct(id: p.id, name: p.name, price: p.price, stock: p.stock + 10);
                            }),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 19),
                              onPressed: () => _showProductSheet(context, existing: p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 19),
                              onPressed: () => provider.deleteProduct(p.id),
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
        label: Text(provider.tr('Add Product', 'পণ্য যোগ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
        child: Text(label, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: CUSTOMERS & SUPPLIERS CRM DUE LEDGER (WITH CHART & 1-TAP SETTLE)
  // ===========================================================================
  Widget _buildPartiesCrmTab(BuildContext context, TransactionProvider provider) {
    final double custDue = provider.totalCustomerDue;
    final double suppDue = provider.parties.where((p) => !p.isCustomer).fold(0.0, (s, p) => s + p.dueAmount);

    final filteredParties = provider.parties.where((p) {
      if (_partyFilter == 'Customers' && !p.isCustomer) return false;
      if (_partyFilter == 'Suppliers' && p.isCustomer) return false;
      if (_partyFilter == 'With Due' && p.dueAmount <= 0) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return p.name.toLowerCase().contains(q) || p.phone.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
        children: [
          // 1. RECEIVABLE VS PAYABLE CHART
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
                  provider.tr('Customer Receivable vs Supplier Payable Chart', 'কাস্টমার পাওনা বনাম সাপ্লায়ার দেনার চার্ট'),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [
                    custDue > 0 ? custDue : (suppDue == 0 ? 1 : 0),
                    suppDue > 0 ? suppDue : 0,
                  ],
                  colors: const [Color(0xFF0EA5E9), Color(0xFFF59E0B)],
                  labels: [
                    '${provider.tr("Customer Receivable", "কাস্টমার পাওনা")} (৳${custDue.toStringAsFixed(0)})',
                    '${provider.tr("Supplier Payable", "সাপ্লায়ার দেনা")} (৳${suppDue.toStringAsFixed(0)})',
                  ],
                  centerTitle: provider.tr('Total Parties', 'মোট পার্টি'),
                  centerValue: '${provider.parties.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. SEARCH & PARTY FILTERS
          Wrap(
            spacing: 8,
            children: ['All', 'Customers', 'Suppliers', 'With Due'].map((f) {
              final isSel = _partyFilter == f;
              return ChoiceChip(
                label: Text(f, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
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
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
              child: Text(
                provider.tr('No matching parties. Tap "+ Add Party" below!', 'কোনো কাস্টমার বা সাপ্লায়ার পাওয়া যায়নি।'),
                style: const TextStyle(color: Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...filteredParties.map((party) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (party.isCustomer ? const Color(0xFF0EA5E9) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                    child: Text(
                      party.name.isNotEmpty ? party.name[0].toUpperCase() : '?',
                      style: TextStyle(color: party.isCustomer ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(party.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          '${party.isCustomer ? provider.tr("Customer", "কাস্টমার") : provider.tr("Supplier", "সাপ্লায়ার")} • ${party.phone.isEmpty ? "No phone" : party.phone}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          party.dueAmount > 0
                              ? '${party.isCustomer ? provider.tr("Receivable Due", "পাওনা বাকি") : provider.tr("Payable Due", "দেনা বাকি")}: ৳${party.dueAmount.toStringAsFixed(0)}'
                              : provider.tr('Settled Up ✓', 'পরিশোধিত ✓'),
                          style: TextStyle(
                            color: party.dueAmount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (party.dueAmount > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF10B981),
                      ),
                      onPressed: () {
                        provider.saveBusinessTx(
                          title: '${party.isCustomer ? "Due Collected" : "Supplier Paid"} - ${party.name}',
                          type: party.isCustomer ? 'Sale' : 'Purchase',
                          amount: party.dueAmount,
                        );
                        provider.saveParty(
                          id: party.id,
                          name: party.name,
                          phone: party.phone,
                          isCustomer: party.isCustomer,
                          dueAmount: 0,
                        );
                      },
                      child: Text(provider.tr('Settle', 'নিষ্পত্তি'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 18),
                    onPressed: () => _showPartySheet(context, existing: party),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                    onPressed: () => provider.deleteParty(party.id),
                  ),
                ],
              ),
            )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showPartySheet(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(provider.tr('Add Party', 'নতুন পার্টি যোগ'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ===========================================================================
  // TAB 4: FULL INVOICES, VOUCHERS & MEMOS AUDIT TRAIL (WITH CHART)
  // ===========================================================================
  Widget _buildInvoicesAuditTab(BuildContext context, TransactionProvider provider) {
    final int saleCount = provider.businessTxs.where((t) => t.type == 'Sale').length;
    final int purchCount = provider.businessTxs.where((t) => t.type == 'Purchase').length;
    final int expCount = provider.businessTxs.where((t) => t.type == 'Expense').length;

    final filteredTxs = provider.businessTxs.where((t) {
      if (_txFilter == 'With Memo' && !t.hasAttachment) return false;
      if (_txFilter != 'All' && _txFilter != 'With Memo' && t.type != _txFilter) return false;
      if (_searchQuery.isNotEmpty && !t.title.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
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
                saleCount > 0 ? saleCount.toDouble() : 1,
                purchCount.toDouble(),
                expCount.toDouble(),
              ],
              colors: const [Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444)],
              labels: [
                '${provider.tr("Sales Vouchers", "বিক্রয় ভাউচার")} ($saleCount)',
                '${provider.tr("Purchase Vouchers", "ক্রয় ভাউচার")} ($purchCount)',
                '${provider.tr("Expense Vouchers", "ব্যয় ভাউচার")} ($expCount)',
              ],
              centerTitle: provider.tr('Total', 'মোট'),
              centerValue: '${provider.businessTxs.length}',
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'Sale', 'Purchase', 'Expense', 'With Memo'].map((f) {
              final isSel = _txFilter == f;
              return ChoiceChip(
                label: Text(f, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                selected: isSel,
                selectedColor: const Color(0xFF0EA5E9),
                backgroundColor: const Color(0xFF1E293B),
                showCheckmark: false,
                onSelected: (_) => setState(() => _txFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          ...filteredTxs.map((tx) => _buildBizTxTile(context, tx, provider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showSmartPosCheckoutSheet(context, initialType: 'Sale'),
        icon: const Icon(Icons.add_shopping_cart),
        label: Text(provider.tr('Record POS Entry', 'নতুন ভাউচার যোগ')),
      ),
    );
  }

  Widget _buildBizTxTile(BuildContext context, BusinessTxModel tx, TransactionProvider provider) {
    Color c = const Color(0xFF10B981);
    IconData icon = Icons.point_of_sale_rounded;
    if (tx.type == 'Purchase') {
      c = const Color(0xFFF59E0B);
      icon = Icons.shopping_bag_outlined;
    } else if (tx.type == 'Expense') {
      c = const Color(0xFFEF4444);
      icon = Icons.money_off_csred_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: ListTile(
        onTap: () => _showSmartPosCheckoutSheet(context, initialType: tx.type, existing: tx),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: c, size: 20),
        ),
        title: Row(
          children: [
            Expanded(child: Text(tx.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
            if (tx.hasAttachment)
              InkWell(
                onTap: () => AttachmentHelper.viewAttachment(context, tx.attachmentBase64, tx.attachmentName),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text(provider.tr('Memo', 'মেমো'), style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        subtitle: Text('${tx.type} • ${tx.date}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('৳${tx.amount.toStringAsFixed(0)}', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)),
            IconButton(
              tooltip: 'PDF Invoice',
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF38BDF8), size: 19),
              onPressed: () => _generatePosInvoicePdf(tx, provider),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFF64748B), size: 18),
              onPressed: () => provider.deleteBusinessTx(tx.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCell(String label, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(val, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
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
        padding: const EdgeInsets.all(14),
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
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SMART POS CHECKOUT SHEET (PRODUCT LINKER + AUTO STOCK + RECEIPT UPLOAD)
  // ===========================================================================
  void _showSmartPosCheckoutSheet(BuildContext context, {required String initialType, BusinessTxModel? existing}) {
    final provider = context.read<TransactionProvider>();
    String selectedType = existing?.type ?? initialType;
    String selectedProductId = 'custom';
    int quantity = 1;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    String attBase64 = existing?.attachmentBase64 ?? '';
    String attName = existing?.attachmentName ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          ProductModel? chosenProduct;
          if (selectedProductId != 'custom') {
            final idx = provider.products.indexWhere((p) => p.id == selectedProductId);
            if (idx != -1) chosenProduct = provider.products[idx];
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? provider.tr('Smart POS Checkout & Memo Upload', 'স্মার্ট পিওএস এন্ট্রি ও ভাউচার আপলোড')
                        : provider.tr('Edit POS Voucher', 'ভাউচার সম্পাদনা করুন'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: ['Sale', 'Purchase', 'Expense'].map((t) {
                      final isSel = selectedType == t;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Center(child: Text(t, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
                            selected: isSel,
                            selectedColor: const Color(0xFF0EA5E9),
                            backgroundColor: const Color(0xFF0F172A),
                            showCheckmark: false,
                            onSelected: (_) => setSheetState(() => selectedType = t),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  if (existing == null && selectedType != 'Expense' && provider.products.isNotEmpty) ...[
                    Text(
                      provider.tr('Select Inventory Product (Auto-Updates Stock):', 'ইনভেন্টরি পণ্য নির্বাচন করুন (অটো স্টক সমন্বয়):'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(provider.tr('Custom Item', 'কাস্টম আইটেম'), style: const TextStyle(fontSize: 11)),
                          selected: selectedProductId == 'custom',
                          selectedColor: const Color(0xFF0EA5E9),
                          labelStyle: TextStyle(color: selectedProductId == 'custom' ? Colors.white : const Color(0xFF94A3B8)),
                          backgroundColor: const Color(0xFF0F172A),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => selectedProductId = 'custom'),
                        ),
                        ...provider.products.map((p) {
                          final isSel = selectedProductId == p.id;
                          return ChoiceChip(
                            label: Text('${p.name} (Stock: ${p.stock} • ৳${p.price.toStringAsFixed(0)})', style: const TextStyle(fontSize: 11)),
                            selected: isSel,
                            selectedColor: const Color(0xFF0EA5E9),
                            labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8)),
                            backgroundColor: const Color(0xFF0F172A),
                            showCheckmark: false,
                            onSelected: (_) => setSheetState(() {
                              selectedProductId = p.id;
                              titleCtrl.text = '${p.name} (x$quantity)';
                              amountCtrl.text = (p.price * quantity).toStringAsFixed(0);
                            }),
                          );
                        }),
                      ],
                    ),
                    if (chosenProduct != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF38BDF8)),
                            onPressed: () {
                              if (quantity > 1) {
                                setSheetState(() {
                                  quantity--;
                                  titleCtrl.text = '${chosenProduct!.name} (x$quantity)';
                                  amountCtrl.text = (chosenProduct.price * quantity).toStringAsFixed(0);
                                });
                              }
                            },
                          ),
                          Text('Qty: $quantity', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF38BDF8)),
                            onPressed: () {
                              setSheetState(() {
                                quantity++;
                                titleCtrl.text = '${chosenProduct!.name} (x$quantity)';
                                amountCtrl.text = (chosenProduct.price * quantity).toStringAsFixed(0);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],

                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Item / Invoice Memo *', 'পণ্যের নাম বা বিবরণ *'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: provider.tr('Total Amount (BDT ৳) *', 'মোট টাকা (৳) *'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // UPLOAD POS RECEIPT / MEMO
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            attName.isEmpty
                                ? provider.tr('Attach POS Memo / Invoice (PDF, JPG, PNG)', 'ভাউচার বা রসিদ যুক্ত করুন')
                                : attName,
                            style: TextStyle(color: attName.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF10B981), fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await AttachmentHelper.pickReceiptOrMemo(context);
                            if (picked != null) {
                              setSheetState(() {
                                attBase64 = picked['base64']?.toString() ?? '';
                                attName = picked['name']?.toString() ?? '';
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 16, color: Color(0xFF38BDF8)),
                          label: Text(provider.tr('Upload', 'আপলোড'), style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (title.isEmpty || amt <= 0) return;

                      if (existing == null && chosenProduct != null) {
                        if (selectedType == 'Sale' && chosenProduct.stock < quantity) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Only ${chosenProduct.stock} units available in stock!')),
                          );
                          return;
                        }
                        final int newStock = selectedType == 'Sale'
                            ? math.max(0, chosenProduct.stock - quantity)
                            : (chosenProduct.stock + quantity);
                        provider.saveProduct(
                          id: chosenProduct.id,
                          name: chosenProduct.name,
                          price: chosenProduct.price,
                          stock: newStock,
                        );
                      }

                      provider.saveBusinessTx(
                        id: existing?.id,
                        title: title,
                        type: selectedType,
                        amount: amt,
                        attachmentBase64: attBase64,
                        attachmentName: attName,
                      );
                      Navigator.pop(ctx);
                    },
                    child: Text(provider.tr('Save POS Record & Sync Cloud', 'পিওএস ভাউচার সেভ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showProductSheet(BuildContext context, {ProductModel? existing}) {
    final provider = context.read<TransactionProvider>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toStringAsFixed(0) : '');
    final stockCtrl = TextEditingController(text: existing != null ? existing.stock.toString() : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? provider.tr('Add Inventory Product', 'নতুন পণ্য যোগ করুন') : provider.tr('Edit Product', 'পণ্য সম্পাদনা করুন'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: provider.tr('Product Name *', 'পণ্যের নাম *'), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: provider.tr('Unit Price (৳) *', 'একক মূল্য (৳) *'), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            TextField(controller: stockCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: provider.tr('Stock Quantity *', 'স্টক সংখ্যা *'), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                provider.saveProduct(
                  id: existing?.id,
                  name: nameCtrl.text.trim(),
                  price: double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                  stock: int.tryParse(stockCtrl.text.trim()) ?? 0,
                );
                Navigator.pop(ctx);
              },
              child: Text(provider.tr('Save Product', 'পণ্য সেভ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPartySheet(BuildContext context, {PartyModel? existing}) {
    final provider = context.read<TransactionProvider>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final dueCtrl = TextEditingController(text: existing != null ? existing.dueAmount.toStringAsFixed(0) : '');
    bool isCust = existing?.isCustomer ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? provider.tr('Add Customer / Supplier', 'কাস্টমার বা সাপ্লায়ার যোগ করুন') : provider.tr('Edit Party', 'পার্টি সম্পাদনা করুন'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text(provider.tr('Customer', 'কাস্টমার'))),
                      selected: isCust,
                      selectedColor: const Color(0xFF0EA5E9),
                      labelStyle: TextStyle(color: isCust ? Colors.white : const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                      backgroundColor: const Color(0xFF0F172A),
                      showCheckmark: false,
                      onSelected: (_) => setSheetState(() => isCust = true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text(provider.tr('Supplier', 'সাপ্লায়ার'))),
                      selected: !isCust,
                      selectedColor: const Color(0xFFF59E0B),
                      labelStyle: TextStyle(color: !isCust ? Colors.white : const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                      backgroundColor: const Color(0xFF0F172A),
                      showCheckmark: false,
                      onSelected: (_) => setSheetState(() => isCust = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: provider.tr('Party Name *', 'নাম *'), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: provider.tr('Phone Number', 'ফোন নম্বর'), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              TextField(controller: dueCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: provider.tr('Pending Due Amount (৳)', 'বাকি টাকা (৳)'), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  provider.saveParty(
                    id: existing?.id,
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    isCustomer: isCust,
                    dueAmount: double.tryParse(dueCtrl.text.trim()) ?? 0.0,
                  );
                  Navigator.pop(ctx);
                },
                child: Text(provider.tr('Save Party', 'সেভ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}