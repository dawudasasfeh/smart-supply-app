import 'package:flutter/material.dart';

class SupermarketDashboard extends StatelessWidget {
  const SupermarketDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildSupermarketDrawer(context),
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Supermarket Dashboard'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, Supermarket Owner 👋',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple[800],
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _actionButton(context, Icons.shopping_cart, 'Order', '/browseProducts'),
                _actionButton(context, Icons.history, 'Orders', '/orderHistory'),
                _actionButton(context, Icons.local_offer, 'Offers', '/offers'),
              ],
            ),
            const SizedBox(height: 30),
            const Text("Recent Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text("Order #1234 delivered"),
                  ),
                  ListTile(
                    leading: Icon(Icons.discount, color: Colors.orange),
                    title: Text("New offer added"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, IconData icon, String label, String route) {
    return Column(
      children: [
        Ink(
          decoration: ShapeDecoration(color: Colors.deepPurple[100], shape: const CircleBorder()),
          child: IconButton(icon: Icon(icon), onPressed: () => Navigator.pushNamed(context, route), iconSize: 32, color: Colors.deepPurple),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Drawer _buildSupermarketDrawer(BuildContext context) => Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text("Supermarket", style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(leading: const Icon(Icons.dashboard), title: const Text("Dashboard"), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.add_shopping_cart), title: const Text("Place Order"), onTap: () => Navigator.pushNamed(context, '/browseProducts')),
            ListTile(leading: const Icon(Icons.shopping_cart), title: const Text("Cart"), onTap: () => Navigator.pushNamed(context, '/cart')),
            ListTile(leading: const Icon(Icons.history), title: const Text("Order History"), onTap: () => Navigator.pushNamed(context, '/orderHistory')),
            ListTile(leading: const Icon(Icons.inventory), title: const Text("Inventory"), onTap: () => Navigator.pushNamed(context, '/inventory')),
            ListTile(leading: const Icon(Icons.local_offer), title: const Text("Offers"), onTap: () => Navigator.pushNamed(context, '/offers')),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text("Chats"),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/chatList',
                  arguments: {
                    'role': 'supermarket', // ✅ Pass only the role
                  },
                );
              },
            ),
            ListTile(leading: const Icon(Icons.person), title: const Text("Profile"),  onTap: () => Navigator.pushNamed(context, '/profile')),
            ListTile(leading: const Icon(Icons.settings), title: const Text("Settings"), onTap: () => Navigator.pushNamed(context, '/settings')),
          ],
        ),
      );
}
