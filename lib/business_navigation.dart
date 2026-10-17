import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'business_dashboard.dart';
import 'main_navigation.dart';
import 'providers/transaction_provider.dart';

class BusinessNavigationScreen extends StatefulWidget {
  const BusinessNavigationScreen({super.key});

  @override
  State<BusinessNavigationScreen> createState() => _BusinessNavigationScreenState();
}

class _BusinessNavigationScreenState extends State<BusinessNavigationScreen> {
  int _currentIndex = 0;

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return BusinessDashboardScreen(onNavigateTab: (i) => setState(() => _currentIndex = i));
      case 1:
        return const BusinessReportsTab();
      case 2:
        return const BusinessProductsTab();
      case 3:
        return const BusinessPartiesTab();
      default:
        return BusinessDashboardScreen(onNavigateTab: (i) => setState(() => _currentIndex = i));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A15),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1A15),
        elevation: 0,
        title: GestureDetector(
          onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()), (route) => false),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('My Business', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
                  SizedBox(width: 4),
                  Icon(Icons.swap_horiz, color: Colors.tealAccent, size: 18),
                ],
              ),
              Text('Tap to Switch Personal Mode', style: TextStyle(fontSize: 11, color: Colors.tealAccent)),
            ],
          ),
        ),
      ),
      body: _buildPage(_currentIndex),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        shape: const CircleBorder(),
        onPressed: () => _showQuickAddModal(context),
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF16221C),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0),
            _buildNavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Report', 1),
            const SizedBox(width: 48),
            _buildNavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'Product', 2),
            _buildNavItem(Icons.people_alt_outlined, Icons.people_alt, 'Parties', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData unselected, IconData selected, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSelected ? selected : unselected, color: isSelected ? Colors.tealAccent : Colors.grey),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.grey, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _showQuickAddModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2A24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Quick Add', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(sheetCtx)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(Icons.shopping_bag_outlined, 'New Sale', Colors.tealAccent, () {
                    Navigator.pop(sheetCtx);
                    BusinessDashboardScreen.showBizTxSheet(context, 'Sale');
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(Icons.shopping_cart_outlined, 'New Purchase', Colors.orangeAccent, () {
                    Navigator.pop(sheetCtx);
                    BusinessDashboardScreen.showBizTxSheet(context, 'Purchase');
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(Icons.receipt_long_outlined, 'New Expense', Colors.redAccent, () {
                    Navigator.pop(sheetCtx);
                    BusinessDashboardScreen.showBizTxSheet(context, 'Expense');
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(Icons.inventory_outlined, 'New Product', Colors.blueAccent, () {
                    Navigator.pop(sheetCtx);
                    BusinessDashboardScreen.showProductSheet(context);
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: const Color(0xFF16221C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 1: BUSINESS REPORTS & PROFIT/LOSS
// =============================================================================
class BusinessReportsTab extends StatelessWidget {
  const BusinessReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final biz = context.watch<TransactionProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF134E5E), Color(0xFF71B280)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Net Profit / Loss', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text('৳ ${biz.netProfit.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sales: ৳ ${biz.totalSales.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text('Out: ৳ ${(biz.totalPurchases + biz.totalBizExpenses).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('All Transactions (Tap to Edit/Delete)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...biz.businessTxs.map((tx) => ListTile(
          onTap: () => BusinessDashboardScreen.showBizTxSheet(context, tx.type, existing: tx),
          tileColor: const Color(0xFF16221C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(tx.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('${tx.type} • ${tx.date}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          trailing: Text('৳ ${tx.amount.toStringAsFixed(0)}', style: TextStyle(color: tx.type == 'Sale' ? Colors.tealAccent : Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 15)),
        )),
      ],
    );
  }
}

// =============================================================================
// TAB 2: PRODUCT & STOCK MANAGEMENT
// =============================================================================
class BusinessProductsTab extends StatefulWidget {
  const BusinessProductsTab({super.key});

  @override
  State<BusinessProductsTab> createState() => _BusinessProductsTabState();
}

class _BusinessProductsTabState extends State<BusinessProductsTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final biz = context.watch<TransactionProvider>();
    final filtered = biz.products.where((p) => p.name.toLowerCase().contains(_search.toLowerCase())).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search product...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                    filled: true,
                    fillColor: const Color(0xFF16221C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => BusinessDashboardScreen.showProductSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No products in stock. Tap + Add!', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final p = filtered[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: const Color(0xFF16221C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                  child: ListTile(
                    onTap: () => BusinessDashboardScreen.showProductSheet(context, existing: p),
                    title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Stock: ${p.stock} units', style: TextStyle(color: p.stock <= 5 ? Colors.redAccent : Colors.grey)),
                    trailing: Text('৳ ${p.price.toStringAsFixed(0)}', style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 3: PARTIES (CUSTOMERS & SUPPLIERS LEDGER)
// =============================================================================
class BusinessPartiesTab extends StatelessWidget {
  const BusinessPartiesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final biz = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customers & Suppliers', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => _showPartySheet(context),
                icon: const Icon(Icons.person_add, color: Colors.tealAccent, size: 18),
                label: const Text('Add Party', style: TextStyle(color: Colors.tealAccent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (biz.parties.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No customers or suppliers added yet.', style: TextStyle(color: Colors.grey)))),
          ...biz.parties.map((party) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: const Color(0xFF16221C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: ListTile(
              onTap: () => _showPartySheet(context, existing: party),
              leading: CircleAvatar(
                backgroundColor: party.isCustomer ? Colors.teal.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                child: Icon(party.isCustomer ? Icons.person : Icons.store, color: party.isCustomer ? Colors.tealAccent : Colors.orangeAccent),
              ),
              title: Text(party.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('${party.isCustomer ? "Customer" : "Supplier"} • ${party.phone}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: Text('Due: ৳ ${party.dueAmount.toStringAsFixed(0)}', style: TextStyle(color: party.dueAmount > 0 ? Colors.orangeAccent : Colors.grey, fontWeight: FontWeight.bold)),
            ),
          )),
        ],
      ),
    );
  }

  void _showPartySheet(BuildContext context, {PartyModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final dueCtrl = TextEditingController(text: existing != null ? existing.dueAmount.toString() : '');
    bool isCustomer = existing?.isCustomer ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16221C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'Add Party' : 'Edit Party', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(label: const Text('Customer'), selected: isCustomer, onSelected: (_) => setSheetState(() => isCustomer = true)),
                  const SizedBox(width: 12),
                  ChoiceChip(label: const Text('Supplier'), selected: !isCustomer, onSelected: (_) => setSheetState(() => isCustomer = false)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Party Name', filled: true, fillColor: const Color(0xFF0F1A15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Phone Number', filled: true, fillColor: const Color(0xFF0F1A15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              TextField(controller: dueCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Due Balance (৳)', filled: true, fillColor: const Color(0xFF0F1A15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (existing != null)
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: () {
                          context.read<TransactionProvider>().deleteParty(existing.id);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Delete'),
                      ),
                    ),
                  if (existing != null) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () {
                        if (nameCtrl.text.trim().isNotEmpty) {
                          context.read<TransactionProvider>().saveParty(
                            id: existing?.id,
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            isCustomer: isCustomer,
                            dueAmount: double.tryParse(dueCtrl.text.trim()) ?? 0,
                          );
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Save Party', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}