import '../config/rbac.dart';

class AppConstants {
  AppConstants._();

  // ── Route names ────────────────────────────────────────────
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeForgotPassword = '/forgot-password';
  static const String routeHome = '/home';
  static const String routeEscalationWorklist = '/escalation-worklist';
  static const String routeEscalationReview = '/escalation-review';
  static const String routeUserManagement = '/user-management';

  // ── API base paths (all versioned) ─────────────────────────
  static const String apiAuth = '/v1/auth';
  static const String apiEvents = '/v1/events';
  static const String apiNetradyne = '/v1/netradyne';
  static const String apiAlerts = '/v1/alerts';
  static const String apiDashboard = '/v1/dashboard';
  static const String apiEscalations = '/v1/escalations';
  static const String apiEvidence = '/v1/evidence';
  static const String apiUsers = '/v1/users';

  // ── Auth endpoints ─────────────────────────────────────────
  static const String endpointLogin = '$apiAuth/login';
  static const String endpointRegister = '$apiAuth/register';
  static const String endpointRefresh = '$apiAuth/refresh';
  static const String endpointSendOtp = '$apiAuth/send-otp';
  static const String endpointVerifyOtp = '$apiAuth/verify-otp';
  static const String endpointVerifyLoginOtp = '$apiAuth/verify-login-otp';
  static const String endpointResetPassword = '$apiAuth/reset-password';
  static const String endpointLogout = '$apiAuth/logout';
  static const String endpointLogoutAll = '$apiAuth/logout-all';
  static const String endpointDeviceLogin = '$apiAuth/device-login';
  static const String endpointAlertGenerate = '$apiAuth/api/alerts';

  // ── Dashboard endpoints ────────────────────────────────────
  static const String endpointDashboardMetrics = '$apiDashboard/metrics';

  // ── User management endpoints ──────────────────────────────
  static const String endpointUsers = apiUsers;
  static const String endpointMyPermissions = '$apiUsers/me/permissions';

  // ── Escalation statuses ────────────────────────────────────
  static const String statusEscalatedToCC = 'ESCALATED_TO_CC';
  static const String statusUnderReview = 'UNDER_REVIEW';
  static const String statusEscalatedToAuthority = 'ESCALATED_TO_AUTHORITY';
  static const String statusClosed = 'CLOSED';
  static const String statusRejected = 'REJECTED';

  static const List<String> allEscalationStatuses = [
    statusEscalatedToCC,
    statusUnderReview,
    statusEscalatedToAuthority,
    statusClosed,
    statusRejected,
  ];

  // ── Role constants (delegate to AppRole for single source of truth) ────────
  static const String roleSuperAdmin = AppRole.superAdmin;
  static const String roleAuthority = AppRole.authority;
  static const String roleCommandCenter = AppRole.commandCenter;
  static const String roleOrganisation = AppRole.organisation;

  /// Roles that can access the escalation worklist and review screens.
  static const Set<String> rolesWithEscalationAccess = {
    AppRole.superAdmin,
    AppRole.authority,
    AppRole.commandCenter,
    AppRole.organisation, // can read/create but not update status
  };

  /// Roles that can see the Stream/live camera tab.
  static const Set<String> rolesWithStreamAccess = {
    AppRole.superAdmin,
    AppRole.authority,
    AppRole.commandCenter,
  };

  /// Roles that can access User Management.
  static const Set<String> rolesWithUserManagement = {
    AppRole.superAdmin,
    AppRole.authority,
    AppRole.commandCenter,
  };
}
