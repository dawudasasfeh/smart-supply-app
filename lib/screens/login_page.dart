import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String selectedRole = 'Supermarket';
  bool isLoading = false;

  void handleLogin() async {
    setState(() => isLoading = true);

    final response = await ApiService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    setState(() => isLoading = false);

    if (response != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', response['token']);
      await prefs.setString('role', response['user']['role']);
      await prefs.setInt('user_id', response['user']['id']);
      
      final role = response['user']['role'];
      if (role == 'Supermarket') {
        Navigator.pushReplacementNamed(context, '/supermarketDashboard');
      } else if (role == 'Distributor') {
        Navigator.pushReplacementNamed(context, '/distributorDashboard');
      } else if (role == 'Delivery') {
        Navigator.pushReplacementNamed(context, '/deliveryDashboard');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid credentials")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const Icon(Icons.store, size: 72, color: Colors.deepPurple),
              const SizedBox(height: 20),
              Text("Smart Supply Chain",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      )),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Log In", style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                child: const Text("Don't have an account? Sign up"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
