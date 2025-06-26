import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './/services/logout_helper.dart'; // optional helper file

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String role = 'Unknown';

  @override
  void initState() {
    super.initState();
    loadRole();
  }

  Future<void> loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => role = prefs.getString('role') ?? 'Unknown');
  }

  void handleLogout() {
  logout(context); // ✅ this uses the helper
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Role"),
            subtitle: Text(role),
          ),
          if (role == 'Supermarket')
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text("Payment Methods"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.pushNamed(context, '/paymentSettings'),
            ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Language"),
            subtitle: const Text("English (default)"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text("Theme"),
            subtitle: const Text("Light mode (default)"),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: handleLogout,
          ),
        ],
      ),
    );
  }
}
