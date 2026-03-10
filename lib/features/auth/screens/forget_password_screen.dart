import 'package:flutter/material.dart';
import 'otp_verify_screen.dart';
import '../services/auth_service.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool loading = false;
  String fullPhoneNumber = "";
  String method = "email";

  Future<void> sendOtp() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    try {
      String identifier = method == "email"
          ? emailController.text.trim()
          : fullPhoneNumber.isNotEmpty
          ? fullPhoneNumber
          : phoneController.text.trim();

      bool success = await AuthService.sendOtp(identifier, method);

      if (!mounted) return;

      if (success) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              identifier: identifier,
              method: method,
              flow: "reset",
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to send OTP")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    }

    setState(() {
      loading = false;
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Widget buildMethodSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                method = "email";
              });
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: method == "email" ? Colors.blue : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  "Email",
                  style: TextStyle(
                    color: method == "email" ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                method = "phone";
              });
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: method == "phone" ? Colors.blue : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  "Phone",
                  style: TextStyle(
                    color: method == "phone" ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildInputField() {
    if (method == "email") {
      return TextFormField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: "Email Address",
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Enter email";
          }
          if (!value.contains("@")) {
            return "Enter valid email";
          }
          return null;
        },
      );
    }

    return IntlPhoneField(
      controller: phoneController,
      initialCountryCode: 'IN',
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        labelText: "Phone Number",
        border: OutlineInputBorder(),
      ),
      onChanged: (phone) {
        fullPhoneNumber = phone.completeNumber;
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                Center(
                  child: Image.asset(
                    "images/transvolt_logo.png",
                    height: 120,
                    fit: BoxFit.contain,
                  ),
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

                buildMethodSelector(),

                const SizedBox(height: 25),

                buildInputField(),

                const SizedBox(height: 30),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : sendOtp,
                    child: loading
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
