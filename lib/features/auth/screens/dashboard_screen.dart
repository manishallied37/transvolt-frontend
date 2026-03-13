import 'package:flutter/material.dart';
import '../services/token_storage.dart';
import 'login_screen.dart';
import '../../events/screens/events_screen.dart';
import '../services/auth_service.dart';
import '../services/auth_state.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AuthService.logout();
    } catch (e) {
      await TokenStorage.clearTokens();
    }

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  /// Back button logout dialog
  Future<bool> _onBackPressed(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit App"),
        content: const Text("Do you want to logout and exit?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TokenStorage.clearTokens();
      if (!context.mounted) return false;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(context),

      child: Scaffold(
        appBar: AppBar(
          title: const Text("Dashboard"),

          actions: [

            /// Bell Icon
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EventsScreen(),
                  ),
                );
              },
            ),

            /// Profile Menu
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == "logout") {
                  _logout(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: "logout",
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 10),
                      Text("Logout"),
                    ],
                  ),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person),
                ),
              ),
            ),
          ],
        ),

        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [

                /// Dynamic User Header
                FutureBuilder(
                  future: Future.wait([
                    AuthState.getUserRole(),
                    AuthState.getUserEmail(),
                  ]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const UserAccountsDrawerHeader(
                        accountName: Text("Loading..."),
                        accountEmail: Text(""),
                        currentAccountPicture: CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                      );
                    }

                    final role = snapshot.data![0] ?? "User";
                    final email = snapshot.data![1] ?? "";

                    return UserAccountsDrawerHeader(
                      accountName: Text(role),
                      accountEmail: Text(email),
                      currentAccountPicture: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('Events'),
                  onTap: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EventsScreen(),
                      ),
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

        body: FutureBuilder(
          future: AuthState.getUsername(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final username = snapshot.data ?? "User";

            return Center(
              child: Text(
                "Welcome, $username",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}