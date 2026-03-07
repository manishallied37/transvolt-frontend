import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'reset_password_screen.dart';
import '../services/auth_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpVerificationScreen> {
  String otp = "";

  int seconds = 60;
  Timer? timer;

  bool loading = false;
  bool resendLoading = false;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    timer?.cancel();

    setState(() {
      seconds = 60;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (seconds == 0) {
        t.cancel();
      } else {
        setState(() {
          seconds--;
        });
      }
    });
  }

  Future<void> resendOtp() async {
    if (seconds > 0 || resendLoading) return;

    setState(() {
      resendLoading = true;
    });

    try {
      bool success = await AuthService.sendOtp(widget.email.trim());

      if (!mounted) return;

      setState(() {
        resendLoading = false;
      });

      if (success) {
        startTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP resent successfully")),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to resend OTP")));
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        resendLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    }
  }

  Future<void> verifyOtp() async {
    if (otp.trim().length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter 6 digit OTP")));
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      bool success = await AuthService.verifyOtp(widget.email.trim(), otp);

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      if (success) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(email: widget.email),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Verification failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "OTP sent to ${widget.email}",
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            PinCodeTextField(
              length: 6,
              appContext: context,
              keyboardType: TextInputType.number,
              animationType: AnimationType.fade,
              onChanged: (value) {
                otp = value.trim();
              },
            ),

            const SizedBox(height: 30),

            loading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: verifyOtp,
                      child: const Text("Verify OTP"),
                    ),
                  ),

            const SizedBox(height: 20),

            seconds == 0
                ? resendLoading
                      ? const CircularProgressIndicator()
                      : TextButton(
                          onPressed: resendOtp,
                          child: const Text("Resend OTP"),
                        )
                : Text(
                    "Resend OTP in $seconds seconds",
                    style: const TextStyle(color: Colors.grey),
                  ),
          ],
        ),
      ),
    );
  }
}
