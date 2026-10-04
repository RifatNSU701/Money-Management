import 'package:flutter/material.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Total Accounts Balance Card
        Card(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text('Total Net Worth', style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('৳ 1,42,500.00', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Transfer between accounts'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent.withValues(alpha: 0.1),
                    foregroundColor: Colors.tealAccent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('My Wallets & Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            IconButton(icon: const Icon(Icons.add, color: Colors.tealAccent), onPressed: () {}),
          ],
        ),
        const SizedBox(height: 8),
        
        _buildAccountCard('Cash Wallet', '৳ 5,500', Icons.account_balance_wallet, Colors.greenAccent),
        _buildAccountCard('Bkash (Mobile Wallet)', '৳ 12,000', Icons.phone_android, Colors.pinkAccent),
        _buildAccountCard('City Bank (Savings)', '৳ 1,25,000', Icons.account_balance, Colors.blueAccent),
      ],
    );
  }

  Widget _buildAccountCard(String name, String balance, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: const Text('Tap for details', style: TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Text(balance, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
