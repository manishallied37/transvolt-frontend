import 'package:flutter/material.dart';
import '../services/token_storage.dart';
import 'login_screen.dart';
import '../../events/screens/events_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await TokenStorage.clearTokens();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),

      // ---------- Drawer (Side Bar) ----------
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const UserAccountsDrawerHeader(
                accountName: Text("Welcome"),
                accountEmail: Text("user@example.com"),
                currentAccountPicture: CircleAvatar(child: Icon(Icons.person)),
              ),

              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Dashboard'),
                onTap: () {
                  Navigator.pop(context); // just close the drawer
                },
              ),

              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Events'),
                onTap: () {
                  Navigator.pop(context); // close the drawer first
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EventsScreen()),
                    // If your EventsScreen constructor isn't const, use:
                    // MaterialPageRoute(builder: (_) => EventsScreen()),
                  );
                },
              ),

              const Divider(),

              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () => _logout(context),
              ),
            ],
          ),
        ),
      ),

      // ---------------------------------------
      body: const Center(
        child: Text("Login Successful", style: TextStyle(fontSize: 22)),
      ),
    );
  }
}
