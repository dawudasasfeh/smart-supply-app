import 'package:flutter/material.dart';

class DistributorDashboard extends StatelessWidget {
  const DistributorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDistributorDrawer(context),
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Distributor Dashboard'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, Distributor 👋',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple[800],
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _actionButton(context, Icons.inventory, 'Products', '/manageProducts'),
                _actionButton(context, Icons.receipt, 'Orders', '/supplierOrders'),
                _actionButton(context, Icons.discount, 'Offers', '/manageOffers'),
              ],
            ),
            const SizedBox(height: 30),
            const Text("Recent Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.check, color: Colors.green),
                    title: Text("Order #5482 accepted"),
                  ),
                  ListTile(
                    leading: Icon(Icons.add_box, color: Colors.blue),
                    title: Text("New product added"),
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

  Drawer _buildDistributorDrawer(BuildContext context) => Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text("Distributor", style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(leading: const Icon(Icons.dashboard), title: const Text("Dashboard"), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.inventory), title: const Text("Manage Products"), onTap: () => Navigator.pushNamed(context, '/manageProducts')),
            ListTile(leading: const Icon(Icons.receipt_long), title: const Text("Incoming Orders"), onTap: () => Navigator.pushNamed(context, '/supplierOrders')),
            ListTile(leading: const Icon(Icons.local_shipping),title: const Text('Delivery Management'),onTap: () {Navigator.pushNamed(context, '/deliveryManagement');},),
            ListTile(leading: const Icon(Icons.discount), title: const Text("Manage Offers"), onTap: () => Navigator.pushNamed(context, '/manageOffers')),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text("Chats"),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/chatList',
                  arguments: {
                    'role': 'distributor',
                  },
                );
              },
            ),
            ListTile(leading: const Icon(Icons.settings), title: const Text("Settings"), onTap: () => Navigator.pushNamed(context, '/settings')),
          ],
        ),
      );
}
