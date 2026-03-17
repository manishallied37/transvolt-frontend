import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/rbac.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/rbac_guard.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Reports',
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
        // Export action — Authority and SuperAdmin only
        actions: [
          PermissionGuard(
            permission: Permission.reportExport,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exporting report...')),
                  );
                },
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF534AB7),
                  backgroundColor: const Color(0xFFEEEDFE),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Failed to load user data')),
        data: (user) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Role-aware report summary header
            _RoleContextBanner(user: user),
            const SizedBox(height: 16),

            _ReportCard(
              title: 'Event Summary',
              subtitle: 'Total events, severity breakdown, trends',
              icon: Icons.bar_chart_outlined,
              iconBg: const Color(0xFFE6F1FB),
              iconColor: const Color(0xFF185FA5),
              onTap: () {},
            ),
            const SizedBox(height: 10),

            _ReportCard(
              title: 'Escalation Report',
              subtitle: 'Status distribution, resolution times',
              icon: Icons.report_problem_outlined,
              iconBg: const Color(0xFFFAEEDA),
              iconColor: const Color(0xFF854F0B),
              onTap: () {},
            ),
            const SizedBox(height: 10),

            _ReportCard(
              title: 'Driver Performance',
              subtitle: 'Compliance, incidents, scoring',
              icon: Icons.person_outlined,
              iconBg: const Color(0xFFEAF3DE),
              iconColor: const Color(0xFF3B6D11),
              onTap: () {},
            ),
            const SizedBox(height: 10),

            // Audit log — Authority and SuperAdmin only
            RbacGuard(
              permission: Permission.auditRead,
              child: Column(
                children: [
                  _ReportCard(
                    title: 'Audit Log',
                    subtitle: 'User actions, role changes, login history',
                    icon: Icons.history_outlined,
                    iconBg: const Color(0xFFEEEDFE),
                    iconColor: const Color(0xFF534AB7),
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // Full export panel — Authority and SuperAdmin only
            RbacGuard(
              permission: Permission.reportExport,
              child: _ExportPanel(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Role context banner ────────────────────────────────────────────────────────

class _RoleContextBanner extends StatelessWidget {
  final CurrentUser user;
  const _RoleContextBanner({required this.user});

  Color get _bg {
    switch (user.role) {
      case AppRole.superAdmin:
        return const Color(0xFFEEEDFE);
      case AppRole.authority:
        return const Color(0xFFFAEEDA);
      case AppRole.commandCenter:
        return const Color(0xFFE6F1FB);
      default:
        return const Color(0xFFEAF3DE);
    }
  }

  Color get _text {
    switch (user.role) {
      case AppRole.superAdmin:
        return const Color(0xFF534AB7);
      case AppRole.authority:
        return const Color(0xFF854F0B);
      case AppRole.commandCenter:
        return const Color(0xFF185FA5);
      default:
        return const Color(0xFF3B6D11);
    }
  }

  String get _scopeDescription {
    switch (user.role) {
      case AppRole.superAdmin:
        return 'Viewing all data across all regions and organisations.';
      case AppRole.authority:
        return 'Viewing full reports with export access.';
      case AppRole.commandCenter:
        return user.region != null
            ? 'Viewing data for region: ${user.region}'
            : 'Viewing operational reports.';
      default:
        return user.depot != null
            ? 'Viewing data for depot: ${user.depot}'
            : 'Viewing your organisation\'s reports.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _text.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.displayRole,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _scopeDescription,
              style: TextStyle(fontSize: 12, color: _text),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Export panel ───────────────────────────────────────────────────────────────

class _ExportPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export Options',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ExportButton(
                label: 'PDF',
                icon: Icons.picture_as_pdf_outlined,
                color: const Color(0xFFA32D2D),
                bg: const Color(0xFFFCEBEB),
              ),
              const SizedBox(width: 10),
              _ExportButton(
                label: 'Excel',
                icon: Icons.table_chart_outlined,
                color: const Color(0xFF3B6D11),
                bg: const Color(0xFFEAF3DE),
              ),
              const SizedBox(width: 10),
              _ExportButton(
                label: 'CSV',
                icon: Icons.text_snippet_outlined,
                color: const Color(0xFF185FA5),
                bg: const Color(0xFFE6F1FB),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;

  const _ExportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Exporting as $label...')));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Report card ────────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.black26,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
