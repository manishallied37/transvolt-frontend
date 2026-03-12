import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String identifier;
  final String method;

  const ResetPasswordScreen({
    super.key,
    required this.identifier,
    required this.method,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final success = await AuthService.resetPassword(
        widget.identifier.trim(),
        _passwordController.text.trim(),
        widget.method,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset successfully")),
        );

        _passwordController.clear();
        _confirmController.clear();

        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        _showError("Password reset failed");
      }
    } catch (e) {
      _showError(e.toString().replaceAll("Exception:", "").trim());
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      errorMaxLines: 6,
      suffixIcon: IconButton(
        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
        onPressed: toggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                Center(
                  child: Image.asset("images/transvolt_logo.png", height: 120),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Reset Password",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Enter a new password for your account",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 40),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(
                    label: "New Password",
                    obscure: _obscurePassword,
                    toggle: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter password";
                    }

                    final pwd = value.trim();

                    List<String> errors = [];

                    if (!RegExp(r'[A-Z]').hasMatch(pwd)) {
                      errors.add("• Uppercase letter");
                    }

                    if (!RegExp(r'[a-z]').hasMatch(pwd)) {
                      errors.add("• Lowercase letter");
                    }

                    if (!RegExp(r'\d').hasMatch(pwd)) {
                      errors.add("• Number");
                    }

                    if (!RegExp(r'[@$!%*?&]').hasMatch(pwd)) {
                      errors.add("• Special character");
                    }

                    if (pwd.length < 8) {
                      errors.add("• Minimum 8 characters");
                    }

                    if (errors.isEmpty) return null;

                    return "Password must contain:\n${errors.join("\n")}";
                  },
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: _inputDecoration(
                    label: "Confirm Password",
                    obscure: _obscureConfirm,
                    toggle: () {
                      setState(() => _obscureConfirm = !_obscureConfirm);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Confirm password";
                    }

                    if (value.trim() != _passwordController.text.trim()) {
                      return "Passwords do not match";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 30),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _resetPassword,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Reset Password",
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
