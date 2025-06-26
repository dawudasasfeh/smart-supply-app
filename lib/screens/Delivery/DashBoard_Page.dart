import 'package:flutter/material.dart';

class DeliveryDashboard extends StatelessWidget {
  const DeliveryDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Delivery Dashboard'),
        backgroundColor: Colors.deepPurple,
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text(
                'Smart Supply Chain',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in),
              title: const Text('Assigned Orders'),
              onTap: () {
                Navigator.pushNamed(context, '/assignedOrders');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Delivered Orders'),
              onTap: () {
                Navigator.pushNamed(context, '/deliveredOrders');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
            
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, Delivery Partner 👋',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple[800],
                  ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _dashboardButton(
                  context,
                  icon: Icons.assignment_turned_in,
                  label: 'My Orders',
                  onTap: () => Navigator.pushNamed(context, '/assignedOrders'),
                ),
                _dashboardButton(
                  context,
                  icon: Icons.check_circle,
                  label: 'Delivered Orders',
                  onTap: () => Navigator.pushNamed(context, '/deliveredOrders'),
                ),
              ],
            ),

            const SizedBox(height: 30),
            const Text(
              "Recent Activity",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            // Static list — later can be real
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.check_circle_outline, color: Colors.green),
                    title: Text("Order #ORD0012 delivered"),
                  ),
                  ListTile(
                    leading: Icon(Icons.delivery_dining_outlined, color: Colors.deepPurple),
                    title: Text("Assigned to Order #ORD0011"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardButton(BuildContext context,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return Column(
      children: [
        Ink(
          decoration: ShapeDecoration(
            color: Colors.deepPurple[100],
            shape: const CircleBorder(),
          ),
          child: IconButton(
            icon: Icon(icon),
            iconSize: 32,
            color: Colors.deepPurple,
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
