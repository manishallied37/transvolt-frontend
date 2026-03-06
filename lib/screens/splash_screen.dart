import 'package:flutter/material.dart';
import '../services/token_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(seconds: 3));

    final token = await TokenStorage.getAccessToken();

    if (!mounted) return;

    if (token != null) {
      Navigator.pushReplacementNamed(context, "/dashboard");
    } else {
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset("images/transvolt_logo.svg", height: 100),
 
            const SizedBox(height: 20),
 
            const Text(
              "Transvolt Fleet",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
 
            const SizedBox(height: 40),
 
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
