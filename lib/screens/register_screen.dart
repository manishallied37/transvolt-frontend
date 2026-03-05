import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final roleController = TextEditingController();
  final regionController = TextEditingController();
  final depotController = TextEditingController();

  bool loading = false;

  Future<void> register() async {
    setState(() {
      loading = true;
    });

    String deviceId = await DeviceService.getDeviceId();

    bool success = await AuthService.register(
      usernameController.text,
      passwordController.text,
      roleController.text,
      regionController.text,
      depotController.text,
      deviceId,
    );

    setState(() {
      loading = false;
    });

    if (success) {
      Navigator.pushReplacementNamed(context, "/dashboard");
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Registration failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: "Username"),
            ),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),

            TextField(
              controller: roleController,
              decoration: const InputDecoration(labelText: "Role"),
            ),

            TextField(
              controller: regionController,
              decoration: const InputDecoration(labelText: "Region"),
            ),

            TextField(
              controller: depotController,
              decoration: const InputDecoration(labelText: "Depot"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : register,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Register"),
            ),
          ],
        ),
      ),
    );
  }
}
