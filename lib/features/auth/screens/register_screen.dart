import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _regionController = TextEditingController();
  final _depotController = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  String? _selectedRole;
  String _fullMobileNumber = "";

  final RegExp _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    if (_selectedRole == null) {
      _showError("Please select role");
      setState(() => _loading = false);
      return;
    }

    try {
      if (_fullMobileNumber.isEmpty) {
        _showError("Enter valid phone number");
        setState(() => _loading = false);
        return;
      }

      final deviceId = await DeviceService.getDeviceId();

      final success = await AuthService.register(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _selectedRole!,
        _regionController.text.trim(),
        _depotController.text.trim(),
        deviceId,
        _fullMobileNumber,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacementNamed(context, "/dashboard");
      } else {
        _showError("Registration failed");
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

  InputDecoration _inputDecoration({
    required String label,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: suffixIcon,
      errorMaxLines: 6,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _regionController.dispose();
    _depotController.dispose();
    super.dispose();
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
                const SizedBox(height: 30),

                Center(
                  child: Image.asset("images/transvolt_logo.png", height: 120),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Create Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),

                TextFormField(
                  controller: _usernameController,
                  decoration: _inputDecoration(label: "Username"),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter username";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(label: "Email"),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter email";
                    }
                    if (!_emailRegex.hasMatch(value)) {
                      return "Enter valid email";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                IntlPhoneField(
                  controller: _mobileController,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    border: OutlineInputBorder(),
                  ),
                  initialCountryCode: 'IN',
                  onChanged: (phone) {
                    _fullMobileNumber = phone.completeNumber;
                  },
                  validator: (phone) {
                    if (phone == null || phone.number.isEmpty) {
                      return "Enter phone number";
                    }
                    if (phone.number.length < 10) {
                      return "Enter valid phone number";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  decoration: _inputDecoration(
                    label: "Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hidePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _hidePassword = !_hidePassword;
                        });
                      },
                    ),
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

                    if (!RegExp(r'[@\$!%*?&]').hasMatch(pwd)) {
                      errors.add("• Special character");
                    }

                    if (pwd.length < 8) {
                      errors.add("• Minimum 8 characters");
                    }

                    if (errors.isEmpty) return null;

                    return "Password must contain:\n${errors.join("\n")}";
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _hideConfirmPassword,
                  decoration: _inputDecoration(
                    label: "Confirm Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hideConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _hideConfirmPassword = !_hideConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Confirm your password";
                    }

                    if (value.trim() != _passwordController.text.trim()) {
                      return "Passwords do not match";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: _inputDecoration(label: "Role"),
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
                      _selectedRole = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Select role";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _regionController,
                  decoration: _inputDecoration(label: "Region"),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _depotController,
                  decoration: _inputDecoration(label: "Depot"),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Register"),
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
