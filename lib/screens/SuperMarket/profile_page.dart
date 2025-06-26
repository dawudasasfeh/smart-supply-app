import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<Map<String, String>> getProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'role': prefs.getString('role') ?? 'Unknown',
      'token': prefs.getString('token') ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile"), backgroundColor: Colors.deepPurple),
      body: FutureBuilder(
        future: getProfileData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.account_circle, size: 72, color: Colors.deepPurple),
              const SizedBox(height: 20),
              ListTile(title: const Text("Role"), subtitle: Text(data['role']!)),
              const SizedBox(height: 10),
              ListTile(title: const Text("JWT Token"), subtitle: Text('${data['token']!.substring(0, 30)}...')),
            ],
          );
        },
      ),
    );
  }
}
