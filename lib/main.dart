import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forget_password_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/navigation/screens/main_navigation_screen.dart';
import 'features/escalation/screens/escalation_worklist_screen.dart';
import 'features/escalation/screens/escalation_review_screen.dart';
import 'features/user_management/screens/user_management_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final envFile = kReleaseMode ? '.env.production' : '.env.development';
  await dotenv.load(fileName: envFile);

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFE24B4A),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode
                    ? details.exceptionAsString()
                    : 'Please restart the app.',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  AuthService.setupInterceptors();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transvolt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // follows device setting
      routes: {
        AppConstants.routeLogin: (_) => const LoginScreen(),
        AppConstants.routeRegister: (_) => const RegisterScreen(),
        AppConstants.routeForgotPassword: (_) => const ForgotPasswordScreen(),
        AppConstants.routeHome: (_) => const MainNavigationScreen(),
        AppConstants.routeEscalationWorklist: (_) =>
            const EscalationWorklistScreen(),
        AppConstants.routeEscalationReview: (context) {
          final id = ModalRoute.of(context)!.settings.arguments as String?;
          if (id == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid escalation ID')),
            );
          }
          return EscalationReviewScreen(escalationId: id);
        },
        AppConstants.routeUserManagement: (_) => const UserManagementScreen(),
      },
      home: const SplashScreen(),
    );
  }
}
