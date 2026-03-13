import 'package:flutter/material.dart';

import '../../dashboard/screens/dashboard_screen.dart';
import '../../events/screens/events_screen.dart';
import '../../stream/screens/stream_screen.dart';
import '../../escalation/screens/escalation_screen.dart';
import '../../reports/screens/reports_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {

  int _currentIndex = 0;

  void changeTab(int index){
    setState(() {
      _currentIndex = index;
    });
  }

  late final List<Widget> _screens = [
    DashboardScreen(onNavigate: changeTab),
    const EventsScreen(),
    const StreamScreen(),
    const EscalationScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: _screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(

        currentIndex: _currentIndex,

        onTap: changeTab,

        type: BottomNavigationBarType.fixed,

        items: const [

          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: "Dashboard",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_outlined),
            label: "Events",
          ),

          // BottomNavigationBarItem(
          //   icon: Icon(Icons.videocam_outlined),
          //   label: "Stream",
          // ),

          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem_outlined),
            label: "Escalation",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: "Reports",
          ),
        ],
      ),
    );
  }
}