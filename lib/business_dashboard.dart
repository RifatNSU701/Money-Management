import 'package:flutter/material.dart';

class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 1. STATS GRID
        Row(
          children: [
            Expanded(child: _buildStatCard('Today\'s Sales', '৳ 12,500', 'Yesterday: ৳ 8,200', Icons.trending_up, Colors.tealAccent)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Total Products', '142', 'Low Stock: 5', Icons.inventory_2_outlined, Colors.blueAccent)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('Due Amount', '৳ 4,500', 'Payment Due', Icons.access_time, Colors.orangeAccent)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Total Customers', '328', '+12 this week', Icons.people_outline, Colors.purpleAccent)),
          ],
        ),
        const SizedBox(height: 32),

        // 2. QUICK ACTIONS
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildActionTile(Icons.local_shipping_outlined, 'Make a Sale', 'New Sale', Colors.tealAccent)),
            const SizedBox(width: 12),
            Expanded(child: _buildActionTile(Icons.shopping_cart_outlined, 'Make Purchase', 'New Purchase', Colors.orangeAccent)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildActionTile(Icons.add_box_outlined, 'Add Product', 'New Product', Colors.blueAccent)),
            const SizedBox(width: 12),
            Expanded(child: _buildActionTile(Icons.account_balance_wallet_outlined, 'Add Expense', 'Write Expense', Colors.redAccent)),
          ],
        ),
        const SizedBox(height: 32),

        // 3. ALL MODULES
        const Text('All Modules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildModuleIcon(Icons.inventory_2_outlined, 'Product'),
            _buildModuleIcon(Icons.widgets_outlined, 'Stock'),
            _buildModuleIcon(Icons.receipt_long_outlined, 'Sales'),
            _buildModuleIcon(Icons.keyboard_return_outlined, 'Return'),
            _buildModuleIcon(Icons.shopping_bag_outlined, 'Purchase'),
            _buildModuleIcon(Icons.person_outline, 'Customer'),
            _buildModuleIcon(Icons.money_off_outlined, 'Expense'),
            _buildModuleIcon(Icons.local_shipping_outlined, 'Supplier'),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStatCard(String title, String mainValue, String subValue, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF16221C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('+2.5%', style: TextStyle(color: Colors.white70, fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(mainValue, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subValue, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF16221C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF16221C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
          child: Icon(icon, color: Colors.tealAccent, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}