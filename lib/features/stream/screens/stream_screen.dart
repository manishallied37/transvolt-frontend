import 'package:flutter/material.dart';
import '../../../../core/config/rbac.dart';
import '../../../../shared/widgets/rbac_guard.dart';

/// Live stream screen — accessible to SuperAdmin, Authority, Command Center.
/// Organisation users never see this tab in the nav, but this screen
/// provides defence-in-depth with RbacScreen.
class StreamScreen extends StatelessWidget {
  const StreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RbacScreen(
      roles: {AppRole.superAdmin, AppRole.authority, AppRole.commandCenter},
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Live Stream',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: Colors.black12),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_outlined, size: 48, color: Colors.black26),
              SizedBox(height: 16),
              Text(
                'Live Stream',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Connect to vehicle camera feeds',
                style: TextStyle(fontSize: 13, color: Colors.black38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
