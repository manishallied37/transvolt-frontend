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

// ─── Breakpoint ───────────────────────────────────────────────────────────────
// Screens >= 600 dp wide get a NavigationRail (tablet/desktop layout).
// Screens < 600 dp get the existing BottomNavigationBar (phone layout).
const double _kTabletBreakpoint = 600;

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= _kTabletBreakpoint;

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
          child: isTablet
              ? _TabletLayout(
                  tabs: tabs,
                  currentIndex: safeIndex,
                  onTabChange: _changeTab,
                )
              : _PhoneLayout(
                  tabs: tabs,
                  currentIndex: safeIndex,
                  onTabChange: _changeTab,
                ),
        );
      },
    );
  }

  List<_NavTab> _buildTabs(CurrentUser user) {
    final tabs = <_NavTab>[];

    if (user.canViewDashboard) {
      tabs.add(
        _NavTab(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          label: 'Dashboard',
          screen: DashboardScreen(onNavigate: _changeTab),
        ),
      );
    }

    if (user.canViewEvents) {
      tabs.add(
        _NavTab(
          icon: Icons.warning_amber_outlined,
          activeIcon: Icons.warning_amber_rounded,
          label: 'Events',
          screen: const EventsScreen(),
        ),
      );
    }

    if (user.canViewStream) {
      tabs.add(
        _NavTab(
          icon: Icons.videocam_outlined,
          activeIcon: Icons.videocam_rounded,
          label: 'Stream',
          screen: const StreamScreen(),
        ),
      );
    }

    if (user.canViewEscalations) {
      tabs.add(
        _NavTab(
          icon: Icons.report_problem_outlined,
          activeIcon: Icons.report_problem,
          label: 'Escalations',
          screen: const EscalationWorklistScreen(),
        ),
      );
    }

    if (user.canViewReports) {
      tabs.add(
        _NavTab(
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart,
          label: 'Reports',
          screen: const ReportsScreen(),
        ),
      );
    }

    if (user.canManageUsers) {
      tabs.add(
        _NavTab(
          icon: Icons.manage_accounts_outlined,
          activeIcon: Icons.manage_accounts,
          label: 'Users',
          screen: const UserManagementScreen(),
        ),
      );
    }

    return tabs;
  }
}

// ─── Phone layout — BottomNavigationBar (unchanged behaviour) ─────────────────

class _PhoneLayout extends StatelessWidget {
  final List<_NavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabChange;

  const _PhoneLayout({
    required this.tabs,
    required this.currentIndex,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: tabs[currentIndex].screen,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTabChange,
        type: BottomNavigationBarType.fixed,
        items: tabs
            .map(
              (t) => BottomNavigationBarItem(
                icon: Icon(t.icon),
                activeIcon: Icon(t.activeIcon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Tablet layout — NavigationRail on the left ───────────────────────────────

class _TabletLayout extends StatelessWidget {
  final List<_NavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabChange;

  const _TabletLayout({
    required this.tabs,
    required this.currentIndex,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left rail
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onTabChange,
            // Show labels on tablets (enough horizontal space)
            labelType: NavigationRailLabelType.all,
            minWidth: 80,
            backgroundColor: Colors.white,
            // Thin divider between rail and content
            leading: const SizedBox(height: 8),
            destinations: tabs
                .map(
                  (t) => NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.activeIcon),
                    label: Text(t.label, style: const TextStyle(fontSize: 11)),
                  ),
                )
                .toList(),
          ),
          // Thin vertical divider
          const VerticalDivider(width: 1, thickness: 1),
          // Main content — takes remaining width
          Expanded(child: tabs[currentIndex].screen),
        ],
      ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class _NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
  });
}
