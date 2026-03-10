import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/token_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    initApp();
  }

  Future<void> initApp() async {
    /// simulate loading / API checks
    await Future.delayed(const Duration(seconds: 2));

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
      body: Container(
        /// optional gradient background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 232, 234, 236),
              Color.fromARGB(255, 232, 234, 236),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// LOGO
                SvgPicture.asset("images/transvolt_logo.svg", height: 120),

                const SizedBox(height: 20),

                /// APP NAME
                const Text(
                  "NetraDyne FMS",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Fleet Management System",
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),

                const SizedBox(height: 40),

                const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
