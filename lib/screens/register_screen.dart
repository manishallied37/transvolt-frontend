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
  final confirmPasswordController = TextEditingController();
  final roleController = TextEditingController();
  final regionController = TextEditingController();
  final depotController = TextEditingController();
  final emailController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;
  bool hideConfirmPassword = true;

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> register() async {
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    if (!isValidEmail(emailController.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter a valid email")));
      return;
    }

    setState(() {
      loading = true;
    });

    String deviceId = await DeviceService.getDeviceId();

    bool success = await AuthService.register(
      usernameController.text.trim(),
      emailController.text.trim(),
      passwordController.text.trim(),
      roleController.text.trim(),
      regionController.text.trim(),
      depotController.text.trim(),
      deviceId,
    );

    setState(() {
      loading = false;
    });

    if (!mounted) return;

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

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: "Username"),
              ),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email"),
              ),

              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        hidePassword = !hidePassword;
                      });
                    },
                  ),
                ),
              ),

              TextField(
                controller: confirmPasswordController,
                obscureText: hideConfirmPassword,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      hideConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        hideConfirmPassword = !hideConfirmPassword;
                      });
                    },
                  ),
                ),
              ),

              DropdownButtonFormField<String>(
                initialValue: roleController.text.isEmpty
                    ? null
                    : roleController.text,
                decoration: const InputDecoration(labelText: "Role"),
                items: const [
                  DropdownMenuItem(
                    value: "Authority",
                    child: Text("Authority"),
                  ),
                  DropdownMenuItem(
                    value: "Command Center",
                    child: Text("Command Center"),
                  ),
                  DropdownMenuItem(
                    value: "Organization",
                    child: Text("Organization"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    roleController.text = value!;
                  });
                },
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
      ),
    );
  }
}
