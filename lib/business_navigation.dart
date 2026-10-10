import 'package:flutter/material.dart';
import 'business_dashboard.dart';
import 'main_navigation.dart';

class BusinessNavigationScreen extends StatefulWidget {
  const BusinessNavigationScreen({super.key});

  @override
  State<BusinessNavigationScreen> createState() => _BusinessNavigationScreenState();
}

class _BusinessNavigationScreenState extends State<BusinessNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const BusinessDashboardScreen(),
    const Center(child: Text('Reports (Sales, Profit/Loss, Stock)', style: TextStyle(color: Colors.white))),
    const Center(child: Text('Products & Stock', style: TextStyle(color: Colors.white))),
    const Center(child: Text('Parties (Customers & Suppliers)', style: TextStyle(color: Colors.white))),
  ];

  @override
  Widget build(BuildContext context) {
    // Using a subtle dark green tint to visually distinguish Business Mode from Personal Mode
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A15),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1A15),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Business', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Tap to Switch Personal', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.tealAccent),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                  (route) => false,
            ),
          ),
        ],
      ),
      body: _pages[_currentIndex],
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
            const SizedBox(width: 48), // Space for FAB
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
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Quick Add', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildQuickActionCard(Icons.shopping_bag_outlined, 'New Sale', Colors.tealAccent)),
                const SizedBox(width: 16),
                Expanded(child: _buildQuickActionCard(Icons.shopping_cart_outlined, 'New Purchase', Colors.orangeAccent)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildQuickActionCard(Icons.receipt_long_outlined, 'New Expense', Colors.redAccent)),
                const SizedBox(width: 16),
                Expanded(child: _buildQuickActionCard(Icons.inventory_outlined, 'New Product', Colors.blueAccent)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(IconData icon, String label, Color color) {
    return Container(
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
    );
  }
}