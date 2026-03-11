import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/auth/services/token_storage.dart';

import 'core/theme/app_theme.dart';   // new theme

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> checkLogin() async {
    String? token = await TokenStorage.getAccessToken();
    return token != null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fleet Monitoring',
      debugShowCheckedModeBanner: false,

      // 👇 use centralized theme
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),

      routes: {
        "/login": (context) => const LoginScreen(),
        "/register": (context) => const RegisterScreen(),
        "/dashboard": (context) => const DashboardScreen(),
      },

      home: FutureBuilder<bool>(
        future: checkLogin(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // if (snapshot.data == true) {
          //   return const DashboardScreen();
          // }

          return const DashboardScreen();
        },
      ),
    );
  }
}