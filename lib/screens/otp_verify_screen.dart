import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'reset_password_screen.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import '../services/device_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String identifier;
  final String method;
  final String flow;

  const OtpVerificationScreen({
    super.key,
    required this.identifier,
    required this.method,
    required this.flow,
  });

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
    debugPrint("IDENTIFIER: ${widget.identifier}");
    debugPrint("METHOD: ${widget.method}");
    debugPrint("FLOW: ${widget.flow}");
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
      bool success = await AuthService.sendOtp(
        widget.identifier,
        widget.method,
      );

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
      setState(() {
        resendLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    }
  }

  Future<void> verifyOtp() async {
    if (otp.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter 6 digit OTP")));
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      String deviceId = await DeviceService.getDeviceId();

      bool success;

      if (widget.flow == "login") {
        success = await AuthService.verifyLoginOtp(
          widget.identifier,
          otp,
          deviceId,
        );
      } else {
        success = await AuthService.verifyOtp(
          widget.identifier,
          otp,
          widget.method,
        );
      }

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      if (success) {
        if (widget.flow == "login") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(
                identifier: widget.identifier,
                method: widget.method,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
      }
    } catch (e) {
      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Verification failed")));
    }
  }

  String maskIdentifier() {
    final id = widget.identifier;

    if (id.isEmpty) return "";

    if (widget.method == "phone") {
      return id.length >= 4 ? "******${id.substring(id.length - 4)}" : id;
    }

    if (widget.method == "email" && id.contains("@")) {
      int index = id.indexOf("@");
      return id.substring(0, 2) + "****" + id.substring(index);
    }

    return id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                "OTP Verification",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Text(
                "Enter the 6-digit code sent to ${maskIdentifier()}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 40),

              PinCodeTextField(
                length: 6,
                appContext: context,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                onChanged: (value) {
                  otp = value;
                },
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(8),
                  fieldHeight: 55,
                  fieldWidth: 45,
                  activeColor: Colors.blue,
                  selectedColor: Colors.blue,
                  inactiveColor: Colors.grey,
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : verifyOtp,
                  child: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Verify OTP"),
                ),
              ),

              const SizedBox(height: 25),

              Center(
                child: seconds == 0
                    ? resendLoading
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: resendOtp,
                              child: const Text("Resend OTP"),
                            )
                    : Text(
                        "Resend OTP in $seconds sec",
                        style: const TextStyle(color: Colors.grey),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
