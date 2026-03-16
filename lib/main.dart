import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
// import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forget_password_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/navigation/screens/main_navigation_screen.dart';
import 'features/escalation/screens/escalation_worklist_screen.dart';
import 'features/escalation/screens/escalation_review_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  AuthService.setupInterceptors();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transvolt',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),

      routes: {
        "/login": (context) => const LoginScreen(),
        "/register": (context) => const RegisterScreen(),
        // "/dashboard": (context) => const DashboardScreen(),
        "/forgot-password": (context) => const ForgotPasswordScreen(),
        "/home": (context) => const MainNavigationScreen(),
        "/escalation-worklist": (context) => const EscalationWorklistScreen(),
        "/escalation-review": (context) {
          final escalationId =
              ModalRoute.of(context)!.settings.arguments as String?;

          if (escalationId == null) {
            return const Scaffold(
              body: Center(child: Text("Invalid escalation ID")),
            );
          }

          return EscalationReviewScreen(escalationId: escalationId);
        },
      },

      home: const SplashScreen(),
    );
  }
}
