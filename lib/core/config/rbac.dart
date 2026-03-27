/// RBAC Configuration — Transvolt Frontend
///
/// Single source of truth for roles and permissions.
/// Must stay in sync with the backend config/roles.js.
///
/// Roles (hierarchy: highest → lowest):
///   SuperAdmin     – full system access
///   Authority      – cross-org oversight, reporting, escalation oversight
///   Command Center – operational control, status updates
///   Organisation   – read-only + create escalations within own org

// ── Role constants ─────────────────────────────────────────────────────────────
library;

class AppRole {
  AppRole._();

  static const String superAdmin = 'SuperAdmin';
  static const String authority = 'Authority';
  static const String commandCenter = 'Command Center';
  static const String organisation = 'Organisation';

  static const List<String> all = [
    superAdmin,
    authority,
    commandCenter,
    organisation,
  ];

  static bool isValid(String role) => all.contains(role);
}

// ── Permission constants ───────────────────────────────────────────────────────

class Permission {
  Permission._();

  // Users
  static const String userCreate = 'user:create';
  static const String userRead = 'user:read';
  static const String userUpdate = 'user:update';
  static const String userDelete = 'user:delete';
  static const String userManageRoles = 'user:manage_roles';

  // Escalations
  static const String escalationCreate = 'escalation:create';
  static const String escalationRead = 'escalation:read';
  static const String escalationUpdateStatus = 'escalation:update_status';
  static const String escalationDelete = 'escalation:delete';

  // Comments
  static const String commentRead = 'comment:read';
  static const String commentCreate = 'comment:create';
  static const String commentDelete = 'comment:delete';

  // Evidence
  static const String evidenceUpload = 'evidence:upload';
  static const String evidenceRead = 'evidence:read';

  // Dashboard & Reports
  static const String dashboardRead = 'dashboard:read';
  static const String reportRead = 'report:read';
  static const String reportExport = 'report:export';

  // Alerts
  static const String alertRead = 'alert:read';
  static const String alertGenerate = 'alert:generate';

  // Events / Media
  static const String eventRead = 'event:read';
  static const String eventManage = 'event:manage';

  // Camera & Streaming (BRD §4.1/§4.2/§4.3)
  static const String cameraRead = 'camera:read';
  static const String streamRead = 'stream:read';
  static const String streamLimited = 'stream:limited';

  // System
  static const String systemHealth = 'system:health';
  static const String systemConfig = 'system:config';
  static const String auditRead = 'audit:read';
}

// ── Role → Permission mapping ──────────────────────────────────────────────────

const _allPermissions = [
  Permission.userCreate,
  Permission.userRead,
  Permission.userUpdate,
  Permission.userDelete,
  Permission.userManageRoles,
  Permission.escalationCreate,
  Permission.escalationRead,
  Permission.escalationUpdateStatus,
  Permission.escalationDelete,
  Permission.commentRead,
  Permission.commentCreate,
  Permission.commentDelete,
  Permission.evidenceUpload,
  Permission.evidenceRead,
  Permission.dashboardRead,
  Permission.reportRead,
  Permission.reportExport,
  Permission.alertRead,
  Permission.alertGenerate,
  Permission.eventRead,
  Permission.eventManage,
  Permission.cameraRead,
  Permission.streamRead,
  Permission.streamLimited,
  Permission.systemHealth,
  Permission.systemConfig,
  Permission.auditRead,
];

const Map<String, List<String>> rolePermissions = {
  AppRole.superAdmin: _allPermissions,

  // BRD §4.2 — Authority: region-scoped
  AppRole.authority: [
    Permission.userRead,
    Permission.escalationRead,
    Permission.escalationUpdateStatus,
    Permission.commentRead,
    Permission.commentCreate,
    Permission.commentDelete,
    Permission.evidenceRead,
    Permission.evidenceUpload,
    Permission.cameraRead,
    Permission.streamRead,
    Permission.dashboardRead,
    Permission.reportRead,
    Permission.reportExport,
    Permission.alertRead,
    Permission.eventRead,
    Permission.auditRead,
  ],

  // BRD §4.1 — Command Center: full visibility across all depots
  AppRole.commandCenter: [
    Permission.userRead,
    Permission.escalationCreate,
    Permission.escalationRead,
    Permission.escalationUpdateStatus,
    Permission.commentRead,
    Permission.commentCreate,
    Permission.commentDelete,
    Permission.evidenceUpload,
    Permission.evidenceRead,
    Permission.cameraRead,
    Permission.streamRead,
    Permission.dashboardRead,
    Permission.reportRead,
    Permission.alertRead,
    Permission.alertGenerate,
    Permission.eventRead,
    Permission.eventManage,
  ],

  // BRD §4.3 — Organisation: depot-scoped, limited streaming
  AppRole.organisation: [
    Permission.userRead,
    Permission.escalationCreate,
    Permission.escalationRead,
    Permission.commentRead,
    Permission.commentCreate,
    Permission.evidenceRead,
    Permission.evidenceUpload,
    Permission.cameraRead,
    Permission.streamLimited,
    Permission.dashboardRead,
    Permission.alertRead,
    Permission.eventRead,
  ],
};

// ── RBAC helper ────────────────────────────────────────────────────────────────

/// Check if a role has a specific permission.
bool hasPermission(String? role, String permission) {
  if (role == null) return false;
  final perms = rolePermissions[role];
  if (perms == null) return false;
  return perms.contains(permission);
}

/// Check if a role has any of the given permissions.
bool hasAnyPermission(String? role, List<String> permissions) {
  if (role == null) return false;
  final perms = rolePermissions[role] ?? [];
  return permissions.any(perms.contains);
}

/// Get all permissions for a role.
List<String> getPermissions(String? role) {
  if (role == null) return [];
  return rolePermissions[role] ?? [];
}
