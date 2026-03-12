import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import 'reset_password_screen.dart';
import 'dashboard_screen.dart';

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
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String _otp = "";
  final TextEditingController _otpController = TextEditingController();

  int _seconds = 120;
  Timer? _timer;

  bool _loading = false;
  bool _resendLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    if (mounted) {
      setState(() {
        _seconds = 120;
      });
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 0) {
        timer.cancel();
      } else {
        if (mounted) {
          setState(() {
            _seconds--;
          });
        }
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resendOtp() async {
    if (_seconds > 0 || _resendLoading) return;

    setState(() => _resendLoading = true);

    try {
      final success = await AuthService.sendOtp(
        widget.identifier,
        widget.method,
      );

      if (!mounted) return;

      setState(() => _resendLoading = false);

      if (success) {
        _otpController.clear();
        _otp = "";
        _startTimer();
        _showMessage("OTP resent successfully");
      } else {
        _showMessage("Failed to resend OTP");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resendLoading = false);
      }
      _showMessage("Something went wrong");
    }
  }

  Future<void> _verifyOtp() async {
    if (_loading) return;
    if (_otp.length != 6) {
      _showMessage("Enter 6 digit OTP");
      return;
    }

    setState(() => _loading = true);

    try {
      final deviceId = await DeviceService.getDeviceId();

      bool success;

      if (widget.flow == "login") {
        success = await AuthService.verifyLoginOtp(
          widget.identifier,
          _otp,
          deviceId,
        );
      } else {
        success = await AuthService.verifyOtp(
          widget.identifier,
          _otp,
          widget.method,
        );
      }

      if (!mounted) return;

      setState(() => _loading = false);

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
        _showMessage("Invalid OTP");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      _showMessage(e.toString().replaceAll("Exception:", "").trim());
    }
  }

  String _maskIdentifier() {
    final id = widget.identifier;

    if (id.isEmpty) return "";

    if (widget.method == "phone") {
      return id.length >= 4 ? "******${id.substring(id.length - 4)}" : id;
    }

    if (widget.method == "email" && id.contains("@")) {
      final index = id.indexOf("@");
      final prefix = id.substring(0, index);

      final visible = prefix.length > 2 ? prefix.substring(0, 2) : prefix;

      return "$visible****${id.substring(index)}";
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
                child: Image.asset("images/transvolt_logo.png", height: 120),
              ),

              const SizedBox(height: 20),

              const Text(
                "OTP Verification",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Text(
                "Enter the 6-digit code sent to ${_maskIdentifier()}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 40),

              PinCodeTextField(
                length: 6,
                appContext: context,
                controller: _otpController,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                onChanged: (value) {
                  _otp = value;
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
                  onPressed: _loading ? null : _verifyOtp,
                  child: _loading
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
                child: _seconds == 0
                    ? _resendLoading
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: _resendOtp,
                              child: const Text("Resend OTP"),
                            )
                    : Text(
                        "Resend OTP in $_seconds sec",
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
