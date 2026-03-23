import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_state.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';
import '../services/device_service.dart';
import '../../../core/constants/app_constants.dart';

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
      // Step 1: Check if there are valid session tokens already in storage
      // (normal case — app was not uninstalled).
      final bool sessionActive = await AuthState.isLoggedIn();

      if (!mounted) return;

      if (sessionActive) {
        Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
        return;
      }

      // Step 2: No active session. Check for a saved device token ("Remember Me").
      // This handles the reinstall scenario — tokens are gone but device token
      // may still be in secure storage (survives reinstall on Android/iOS).
      final String? deviceToken = await TokenStorage.getDeviceToken();

      if (deviceToken != null) {
        final String deviceId = await DeviceService.getDeviceId();
        final bool restored = await AuthService.deviceLogin(deviceToken, deviceId);

        if (!mounted) return;

        if (restored) {
          // Silent login succeeded — go straight to home, no OTP needed.
          Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
          return;
        }

        // Device token expired or revoked — clean it up and go to login.
        await TokenStorage.clearDeviceToken();
      }

      if (!mounted) return;

      // Step 3: No valid session and no valid device token → normal login.
      Navigator.of(context).pushReplacementNamed(AppConstants.routeLogin);
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(AppConstants.routeLogin);
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
        color: Theme.of(context).scaffoldBackgroundColor,
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Fleet Management System",
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 40),

                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
