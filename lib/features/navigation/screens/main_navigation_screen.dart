import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../events/screens/events_screen.dart';
import '../../stream/screens/stream_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../escalation/screens/escalation_worklist_screen.dart';
import '../../user_management/screens/user_management_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  void _changeTab(int index) => setState(() => _currentIndex = index);

  Future<bool> _handleBack() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return false;
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
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Failed to load user'))),
      data: (user) {
        final tabs = _buildTabs(user);
        final safeIndex = _currentIndex.clamp(0, tabs.length - 1);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav = Navigator.of(context);
            if (await _handleBack()) nav.pop();
          },
          child: Scaffold(
            body: tabs[safeIndex].screen,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: safeIndex,
              onTap: _changeTab,
              type: BottomNavigationBarType.fixed,
              items: tabs
                  .map(
                    (t) => BottomNavigationBarItem(
                      icon: Icon(t.icon),
                      label: t.label,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  List<_NavTab> _buildTabs(CurrentUser user) {
    final tabs = <_NavTab>[];

    // ── Dashboard — all authenticated roles ──────────────────────────────────
    if (user.canViewDashboard) {
      tabs.add(
        _NavTab(
          icon: Icons.dashboard_outlined,
          label: 'Dashboard',
          screen: DashboardScreen(onNavigate: _changeTab),
        ),
      );
    }

    // ── Events — all roles with event:read ───────────────────────────────────
    if (user.canViewEvents) {
      tabs.add(
        _NavTab(
          icon: Icons.warning_amber_outlined,
          label: 'Events',
          screen: const EventsScreen(),
        ),
      );
    }

    // ── Stream — SuperAdmin, Authority, Command Center ───────────────────────
    if (user.canViewStream) {
      tabs.add(
        _NavTab(
          icon: Icons.videocam_outlined,
          label: 'Stream',
          screen: const StreamScreen(),
        ),
      );
    }

    // ── Escalation — all roles with escalation:read ──────────────────────────
    if (user.canViewEscalations) {
      tabs.add(
        _NavTab(
          icon: Icons.report_problem_outlined,
          label: 'Escalations',
          screen: const EscalationWorklistScreen(),
        ),
      );
    }

    // ── Reports — all roles with report:read ─────────────────────────────────
    if (user.canViewReports) {
      tabs.add(
        _NavTab(
          icon: Icons.bar_chart_outlined,
          label: 'Reports',
          screen: const ReportsScreen(),
        ),
      );
    }

    // ── User Management — SuperAdmin, Authority, Command Center ──────────────
    if (user.canManageUsers) {
      tabs.add(
        _NavTab(
          icon: Icons.manage_accounts_outlined,
          label: 'Users',
          screen: const UserManagementScreen(),
        ),
      );
    }

    return tabs;
  }
}

class _NavTab {
  final IconData icon;
  final String label;
  final Widget screen;
  const _NavTab({
    required this.icon,
    required this.label,
    required this.screen,
  });
}
