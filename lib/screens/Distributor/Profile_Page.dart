import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupplierProfilePage extends StatelessWidget {
  const SupplierProfilePage({super.key});

  Future<Map<String, String>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'role': prefs.getString('role') ?? '',
      'token': prefs.getString('token') ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile"), backgroundColor: Colors.deepPurple),
      body: FutureBuilder(
        future: getProfile(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.person, size: 72, color: Colors.deepPurple),
                const SizedBox(height: 20),
                ListTile(title: const Text("Role"), subtitle: Text(data['role']!)),
                ListTile(title: const Text("Token (trimmed)"), subtitle: Text("${data['token']!.substring(0, 30)}...")),
              ],
            ),
          );
        },
      ),
    );
  }
}
