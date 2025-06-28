import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SupermarketDashboard extends StatefulWidget {
  const SupermarketDashboard({super.key});

  @override
  State<SupermarketDashboard> createState() => _SupermarketDashboardState();
}

class _SupermarketDashboardState extends State<SupermarketDashboard> {
  List<Map<String, dynamic>> restockSuggestions = [];
  bool isLoadingSuggestions = true;

  @override
  void initState() {
    super.initState();
    fetchRestockSuggestions();
  }

  Future<void> fetchRestockSuggestions() async {
    try {
      // You may need to pass token or user_id here if your backend requires it
      final response = await http.get(Uri.parse('http://10.0.2.2:5000/api/ai/restock_suggestions'));
      if (response.statusCode == 200) {
        final List<dynamic> suggestions = jsonDecode(response.body);
        setState(() {
          restockSuggestions = suggestions.cast<Map<String, dynamic>>();
          isLoadingSuggestions = false;
        });
      } else {
        setState(() {
          isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingSuggestions = false;
      });
    }
  }

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
                children: [
                  const ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text("Order #1234 delivered"),
                  ),
                  const ListTile(
                    leading: Icon(Icons.discount, color: Colors.orange),
                    title: Text("New offer added"),
                  ),
                  const SizedBox(height: 20),
                  const Text("AI Restock Suggestions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  if (isLoadingSuggestions)
                    const Center(child: CircularProgressIndicator())
                  else if (restockSuggestions.isEmpty)
                    const Center(child: Text("You're stocked up. No suggestions at the moment."))
                  else
                    ...restockSuggestions.map((s) => Card(
                          elevation: 3,
                          child: ListTile(
                            title: Text(s['product_name']),
                            subtitle: Text("Suggested Restock: ${s['quantity']} units"),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                              onPressed: () {
                                // TODO: Implement actual restock flow
                              },
                              child: const Text("Restock"),
                            ),
                          ),
                        )),
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
                  arguments: {'role': 'supermarket'},
                );
              },
            ),
            ListTile(leading: const Icon(Icons.person), title: const Text("Profile"), onTap: () => Navigator.pushNamed(context, '/profile')),
            ListTile(leading: const Icon(Icons.settings), title: const Text("Settings"), onTap: () => Navigator.pushNamed(context, '/settings')),
          ],
        ),
      );
}
