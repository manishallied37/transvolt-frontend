import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../services/auth_service.dart';
import 'otp_verify_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = false;
  String _method = "email";
  String _fullPhoneNumber = "";

  final RegExp _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendOtp() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final identifier = _method == "email"
          ? _emailController.text.trim()
          : (_fullPhoneNumber.isNotEmpty
                ? _fullPhoneNumber
                : _phoneController.text.trim());

      if (_method == "phone" && identifier.isEmpty) {
        _showMessage("Enter valid phone number");
        setState(() => _loading = false);
        return;
      }

      final success = await AuthService.sendOtp(identifier, _method);

      if (!mounted) return;

      if (success) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              identifier: identifier,
              method: _method,
              flow: "reset",
            ),
          ),
        );
      } else {
        _showMessage("Failed to send OTP");
      }
    } catch (e) {
      _showMessage(e.toString().replaceAll("Exception:", "").trim());
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  Widget _methodButton(String value, String label) {
    final isSelected = _method == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _method = value;
          });
        },
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Row(
      children: [
        _methodButton("email", "Email"),
        const SizedBox(width: 10),
        _methodButton("phone", "Phone"),
      ],
    );
  }

  Widget _buildInputField() {
    if (_method == "email") {
      return TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: _inputDecoration("Email Address"),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Enter email";
          }
          if (!_emailRegex.hasMatch(value.trim())) {
            return "Enter valid email";
          }
          return null;
        },
      );
    }

    return IntlPhoneField(
      controller: _phoneController,
      initialCountryCode: 'IN',
      keyboardType: TextInputType.phone,
      decoration: _inputDecoration("Phone Number"),
      onChanged: (phone) {
        _fullPhoneNumber = phone.completeNumber;
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
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                /// LOGO
                Center(
                  child: Image.asset("images/transvolt_logo.png", height: 120),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Forgot Password",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Choose a method to receive OTP",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 30),

                _buildMethodSelector(),

                const SizedBox(height: 25),

                _buildInputField(),

                const SizedBox(height: 30),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendOtp,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Send OTP"),
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
