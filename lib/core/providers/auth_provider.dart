import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/rbac.dart';
import '../../features/auth/services/token_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../features/auth/services/auth_service.dart';

class CachedUser {
  static Map<String, dynamic>? _decoded;

  static void set(Map<String, dynamic> decoded) {
    _decoded = decoded;
  }

  static Map<String, dynamic>? get() {
    return _decoded;
  }

  static void clear() {
    _decoded = null;
  }
}

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
  bool get isSuperAdmin => role == AppRole.superAdmin;
  bool get isAuthority => role == AppRole.authority;
  bool get isCommandCenter => role == AppRole.commandCenter;
  bool get isOrganisation => role == AppRole.organisation;

  // ── Legacy set-based check (kept for compat) ────────────────────
  bool canAccess(Set<String> allowedRoles) =>
      role != null && allowedRoles.contains(role);

  // ── Fine-grained permission checks ──────────────────────────────
  bool can(String permission) => hasPermission(role, permission);
  bool canAny(List<String> permissions) => hasAnyPermission(role, permissions);
  List<String> get permissions => getPermissions(role);

  // ── Convenience flags ────────────────────────────────────────────
  bool get canViewDashboard => can(Permission.dashboardRead);
  bool get canViewEvents => can(Permission.eventRead);
  bool get canManageEvents => can(Permission.eventManage);
  bool get canViewEscalations => can(Permission.escalationRead);
  bool get canCreateEscalations => can(Permission.escalationCreate);
  bool get canUpdateEscalationStatus => can(Permission.escalationUpdateStatus);
  bool get canDeleteComments => can(Permission.commentDelete);
  bool get canUploadEvidence => can(Permission.evidenceUpload);
  bool get canViewReports => can(Permission.reportRead);
  bool get canExportReports => can(Permission.reportExport);
  bool get canManageUsers => can(Permission.userCreate);
  bool get canChangeRoles => can(Permission.userManageRoles);

  // BRD §4.1/§4.2 — full live stream (SuperAdmin, Command Center, Authority)
  bool get canViewStream => can(Permission.streamRead);

  // BRD §4.3 — Organisation has limited streaming only
  bool get canViewLimitedStream => can(Permission.streamLimited);

  // BRD §4.1/§4.2/§4.3 — camera:read for images and recorded video
  bool get canViewCamera => can(Permission.cameraRead);

  // ── Display helpers ──────────────────────────────────────────────
  String get displayRole {
    switch (role) {
      case AppRole.superAdmin:
        return 'Super Admin';
      case AppRole.authority:
        return 'Authority';
      case AppRole.commandCenter:
        return 'Command Center';
      case AppRole.organisation:
        return 'Organisation';
      default:
        return role ?? 'Unknown';
    }
  }

  String get initials {
    if (username == null || username!.trim().isEmpty) return '?';
    final parts = username!.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return username!.trim()[0].toUpperCase();
  }

  @override
  String toString() => 'CurrentUser(role: $role, username: $username)';
}

/// Auto-disposes so it re-reads after login/logout.
final currentUserProvider = FutureProvider.autoDispose<CurrentUser>((
  ref,
) async {
  // 🔥 Step 1: Return cached user if available
  final cached = CachedUser.get();
  if (cached != null) {
    return CurrentUser(
      role: cached['role'],
      region: cached['region'],
      depot: cached['depot'],
      username: cached['username'],
      email: cached['email'],
    );
  }

  // 🔥 Step 2: Read token ONCE
  String? token = await TokenStorage.getAccessToken();

  // 🔥 Step 3: Handle expiry safely using your LOCKED refresh
  if (token == null || JwtDecoder.isExpired(token)) {
    final refreshed = await AuthService.lockedRefresh();
    if (!refreshed) throw Exception('Session expired');

    token = await TokenStorage.getAccessToken();
    if (token == null) throw Exception('No token after refresh');
  }

  // 🔥 Step 4: Decode ONCE
  final decoded = JwtDecoder.decode(token);

  // 🔥 Step 5: Cache it for session
  CachedUser.set(decoded);

  return CurrentUser(
    role: decoded['role'] as String?,
    region: decoded['region'] as String?,
    depot: decoded['depot'] as String?,
    username: decoded['username'] as String?,
    email: decoded['email'] as String?,
  );
});
