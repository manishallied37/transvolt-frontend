import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      bool loggedIn = await AuthState.isLoggedIn();

      if (!mounted) return;

      if (loggedIn) {
        Navigator.of(context).pushReplacementNamed("/dashboard");
      } else {
        Navigator.of(context).pushReplacementNamed("/login");
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed("/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    return const _SplashView();
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8EAEC), Color(0xFFE8EAEC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset("images/transvolt_logo.svg", height: 120),

                const SizedBox(height: 20),

                Text(
                  "NetraDyne FMS",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Fleet Management System",
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),

                const SizedBox(height: 40),

                const CircularProgressIndicator(color: Colors.blue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
