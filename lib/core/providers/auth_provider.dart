import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/services/auth_state.dart';
import '../config/rbac.dart';

/// Immutable snapshot of the currently authenticated user,
/// decoded from the JWT and enriched with RBAC helpers.
class CurrentUser {
  final String? role;
  final String? region;
  final String? depot;
  final String? username;
  final String? email;

  const CurrentUser({
    this.role,
    this.region,
    this.depot,
    this.username,
    this.email,
  });

  // ── Role identity ───────────────────────────────────────────────
  bool get isSuperAdmin    => role == AppRole.superAdmin;
  bool get isAuthority     => role == AppRole.authority;
  bool get isCommandCenter => role == AppRole.commandCenter;
  bool get isOrganisation  => role == AppRole.organisation;

  // ── Legacy set-based check (kept for compat) ────────────────────
  bool canAccess(Set<String> allowedRoles) =>
      role != null && allowedRoles.contains(role);

  // ── Fine-grained permission checks ──────────────────────────────
  bool can(String permission) => hasPermission(role, permission);
  bool canAny(List<String> permissions) => hasAnyPermission(role, permissions);
  List<String> get permissions => getPermissions(role);

  // ── Convenience flags ────────────────────────────────────────────
  bool get canViewDashboard          => can(Permission.dashboardRead);
  bool get canViewEvents             => can(Permission.eventRead);
  bool get canManageEvents           => can(Permission.eventManage);
  bool get canViewEscalations        => can(Permission.escalationRead);
  bool get canCreateEscalations      => can(Permission.escalationCreate);
  bool get canUpdateEscalationStatus => can(Permission.escalationUpdateStatus);
  bool get canDeleteComments         => can(Permission.commentDelete);
  bool get canUploadEvidence         => can(Permission.evidenceUpload);
  bool get canViewReports            => can(Permission.reportRead);
  bool get canExportReports          => can(Permission.reportExport);
  bool get canManageUsers            => can(Permission.userCreate);
  bool get canChangeRoles            => can(Permission.userManageRoles);

  // BRD §4.1/§4.2 — full live stream (SuperAdmin, Command Center, Authority)
  bool get canViewStream             => can(Permission.streamRead);

  // BRD §4.3 — Organisation has limited streaming only
  bool get canViewLimitedStream      => can(Permission.streamLimited);

  // BRD §4.1/§4.2/§4.3 — camera:read for images and recorded video
  bool get canViewCamera             => can(Permission.cameraRead);

  // ── Display helpers ──────────────────────────────────────────────
  String get displayRole {
    switch (role) {
      case AppRole.superAdmin:    return 'Super Admin';
      case AppRole.authority:     return 'Authority';
      case AppRole.commandCenter: return 'Command Center';
      case AppRole.organisation:  return 'Organisation';
      default:                    return role ?? 'Unknown';
    }
  }

  String get initials {
    if (username == null || username!.isEmpty) return '?';
    final parts = username!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username![0].toUpperCase();
  }

  @override
  String toString() => 'CurrentUser(role: $role, username: $username)';
}

/// Auto-disposes so it re-reads after login/logout.
final currentUserProvider = FutureProvider.autoDispose<CurrentUser>((ref) async {
  final role     = await AuthState.getUserRole();
  final region   = await AuthState.getRegion();
  final depot    = await AuthState.getDepot();
  final username = await AuthState.getUsername();
  final email    = await AuthState.getUserEmail();

  return CurrentUser(
    role:     role,
    region:   region,
    depot:    depot,
    username: username,
    email:    email,
  );
});
