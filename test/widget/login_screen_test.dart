import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:transvolt_fleet/features/auth/screens/login_screen.dart';
import 'package:transvolt_fleet/core/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: 'API_URL=http://localhost:5000');
  });

  Widget buildSubject() => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const LoginScreen(),
    ),
  );

  group('LoginScreen form validation', () {
    testWidgets('shows error when login field is empty', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Tap login button without filling any field
      final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
      await tester.tap(loginBtn);
      await tester.pump();

      expect(find.text('Enter username or email'), findsOneWidget);
    });

    testWidgets('shows error when password field is empty', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Fill login, leave password empty
      await tester.enterText(
        find.byType(TextFormField).first,
        'user@example.com',
      );

      final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
      await tester.tap(loginBtn);
      await tester.pump();

      expect(find.text('Enter password'), findsOneWidget);
    });

    testWidgets('does not show validation errors when both fields are filled', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
        find.byType(TextFormField).first,
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');

      final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
      await tester.tap(loginBtn);
      await tester.pump();

      expect(find.text('Enter username or email'), findsNothing);
      expect(find.text('Enter password'), findsNothing);
    });

    testWidgets('password field toggles visibility', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Get the inner TextField of the password field
      final passwordField = find.byType(TextField).at(1);
      expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
    });

    testWidgets('forgot password button navigates correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            routes: {
              '/forgot-password': (_) =>
                  const Scaffold(body: Text('Forgot Password Screen')),
            },
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password Screen'), findsOneWidget);
    });
  });
}
