import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false;

  Future<void> login() async {
    setState(() {
      loading = true;
    });

    String deviceId = await DeviceService.getDeviceId();

    bool success = await AuthService.login(
      usernameController.text,
      passwordController.text,
      deviceId,
    );

    setState(() {
      loading = false;
    });

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login Failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: "Username"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),

            const SizedBox(height: 30),

            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: login, child: const Text("Login")),

            const SizedBox(height: 10),

            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, "/register");
              },
              child: const Text("Create account"),
            ),
          ],
        ),
      ),
    );
  }
}
