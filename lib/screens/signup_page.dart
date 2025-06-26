import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String selectedRole = 'Supermarket';
  bool isLoading = false;

  void handleSignup() async {
    setState(() => isLoading = true);

    final result = await ApiService.signup(
      nameController.text.trim(),
      emailController.text.trim(),
      passwordController.text.trim(),
      selectedRole,
    );

    setState(() => isLoading = false);

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', result['user']['token'] ?? '');
      await prefs.setString('role', result['user']['role']);

      // Redirect based on role
      if (selectedRole == 'Supermarket') {
        Navigator.pushReplacementNamed(context, '/supermarketDashboard');
      } else if (selectedRole == 'Distributor') {
        Navigator.pushReplacementNamed(context, '/distributorDashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/deliveryDashboard');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup failed")),
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
              const Icon(Icons.person_add_alt, size: 72, color: Colors.deepPurple),
              const SizedBox(height: 20),
              Text("Create an Account",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      )),
              const SizedBox(height: 30),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'Supermarket', child: Text('Supermarket')),
                  DropdownMenuItem(value: 'Distributor', child: Text('Distributor')),
                  DropdownMenuItem(value: 'Delivery', child: Text('Delivery')),
                ],
                onChanged: (val) => setState(() => selectedRole = val!),
                decoration: InputDecoration(
                  labelText: "Select Role",
                  prefixIcon: const Icon(Icons.people),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Sign Up", style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                child: const Text("Already have an account? Log in"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
