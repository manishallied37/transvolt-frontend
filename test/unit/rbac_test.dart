import 'package:flutter_test/flutter_test.dart';
import 'package:transvolt_fleet/core/config/rbac.dart';
import 'package:transvolt_fleet/core/providers/auth_provider.dart';

void main() {
  // ── AppRole constants ────────────────────────────────────────────────────────
  group('AppRole', () {
    test('all four roles are defined', () {
      expect(AppRole.all.length, 4);
      expect(AppRole.all, contains(AppRole.superAdmin));
      expect(AppRole.all, contains(AppRole.authority));
      expect(AppRole.all, contains(AppRole.commandCenter));
      expect(AppRole.all, contains(AppRole.organisation));
    });

    test('isValid returns true for known roles', () {
      expect(AppRole.isValid('SuperAdmin'),    isTrue);
      expect(AppRole.isValid('Authority'),     isTrue);
      expect(AppRole.isValid('Command Center'), isTrue);
      expect(AppRole.isValid('Organisation'),  isTrue);
    });

    test('isValid returns false for old/invalid role strings', () {
      expect(AppRole.isValid('admin'),      isFalse);
      expect(AppRole.isValid('supervisor'), isFalse);
      expect(AppRole.isValid('driver'),     isFalse);
      expect(AppRole.isValid('viewer'),     isFalse);
      expect(AppRole.isValid(''),           isFalse);
    });
  });

  // ── hasPermission ────────────────────────────────────────────────────────────
  group('hasPermission()', () {
    test('SuperAdmin has all permissions', () {
      for (final perm in rolePermissions[AppRole.superAdmin]!) {
        expect(hasPermission(AppRole.superAdmin, perm), isTrue,
            reason: 'SuperAdmin should have: $perm');
      }
    });

    test('SuperAdmin has escalation:update_status', () {
      expect(
        hasPermission(AppRole.superAdmin, Permission.escalationUpdateStatus),
        isTrue,
      );
    });

    test('Authority has escalation:update_status', () {
      expect(
        hasPermission(AppRole.authority, Permission.escalationUpdateStatus),
        isTrue,
      );
    });

    test('Command Center has escalation:update_status', () {
      expect(
        hasPermission(AppRole.commandCenter, Permission.escalationUpdateStatus),
        isTrue,
      );
    });

    test('Organisation does NOT have escalation:update_status', () {
      expect(
        hasPermission(AppRole.organisation, Permission.escalationUpdateStatus),
        isFalse,
      );
    });

    test('Authority has report:export', () {
      expect(hasPermission(AppRole.authority, Permission.reportExport), isTrue);
    });

    test('Command Center does NOT have report:export', () {
      expect(
        hasPermission(AppRole.commandCenter, Permission.reportExport),
        isFalse,
      );
    });

    test('Organisation does NOT have report:export', () {
      expect(
        hasPermission(AppRole.organisation, Permission.reportExport),
        isFalse,
      );
    });

    test('Authority has audit:read', () {
      expect(hasPermission(AppRole.authority, Permission.auditRead), isTrue);
    });

    test('Command Center does NOT have audit:read', () {
      expect(
        hasPermission(AppRole.commandCenter, Permission.auditRead),
        isFalse,
      );
    });

    test('SuperAdmin has user:manage_roles', () {
      expect(
        hasPermission(AppRole.superAdmin, Permission.userManageRoles),
        isTrue,
      );
    });

    test('Authority does NOT have user:manage_roles', () {
      expect(
        hasPermission(AppRole.authority, Permission.userManageRoles),
        isFalse,
      );
    });

    test('Organisation does NOT have comment:delete', () {
      expect(
        hasPermission(AppRole.organisation, Permission.commentDelete),
        isFalse,
      );
    });

    test('Command Center has comment:delete', () {
      expect(
        hasPermission(AppRole.commandCenter, Permission.commentDelete),
        isTrue,
      );
    });

    test('null role returns false for any permission', () {
      expect(hasPermission(null, Permission.dashboardRead), isFalse);
    });

    test('unknown role returns false', () {
      expect(hasPermission('admin', Permission.dashboardRead), isFalse);
      expect(hasPermission('supervisor', Permission.dashboardRead), isFalse);
    });
  });

  // ── hasAnyPermission ─────────────────────────────────────────────────────────
  group('hasAnyPermission()', () {
    test('returns true if role has at least one', () {
      expect(
        hasAnyPermission(AppRole.organisation, [
          Permission.escalationRead,
          Permission.reportExport,
        ]),
        isTrue,
      );
    });

    test('returns false if role has none', () {
      expect(
        hasAnyPermission(AppRole.organisation, [
          Permission.userManageRoles,
          Permission.systemConfig,
        ]),
        isFalse,
      );
    });
  });

  // ── CurrentUser convenience flags ────────────────────────────────────────────
  group('CurrentUser', () {
    CurrentUser makeUser(String role) =>
        CurrentUser(role: role, username: 'test');

    test('SuperAdmin: all flags true', () {
      final u = makeUser(AppRole.superAdmin);
      expect(u.isSuperAdmin, isTrue);
      expect(u.canViewDashboard, isTrue);
      expect(u.canUpdateEscalationStatus, isTrue);
      expect(u.canExportReports, isTrue);
      expect(u.canChangeRoles, isTrue);
      expect(u.canManageUsers, isTrue);
      expect(u.canViewStream, isTrue);
    });

    test('Authority: can export, update status, cannot change roles', () {
      final u = makeUser(AppRole.authority);
      expect(u.isAuthority, isTrue);
      expect(u.canUpdateEscalationStatus, isTrue);
      expect(u.canExportReports, isTrue);
      expect(u.canChangeRoles, isFalse);
      expect(u.canViewStream, isTrue);
    });

    test('Command Center: can update status, cannot export', () {
      final u = makeUser(AppRole.commandCenter);
      expect(u.isCommandCenter, isTrue);
      expect(u.canUpdateEscalationStatus, isTrue);
      expect(u.canExportReports, isFalse);
      expect(u.canChangeRoles, isFalse);
      expect(u.canViewStream, isTrue);
    });

    test('Organisation: cannot update status, cannot export, cannot view stream', () {
      final u = makeUser(AppRole.organisation);
      expect(u.isOrganisation, isTrue);
      expect(u.canUpdateEscalationStatus, isFalse);
      expect(u.canExportReports, isFalse);
      expect(u.canDeleteComments, isFalse);
      expect(u.canChangeRoles, isFalse);
      expect(u.canManageUsers, isFalse);
      expect(u.canViewStream, isFalse);
    });

    test('Organisation: can create escalations and read dashboard', () {
      final u = makeUser(AppRole.organisation);
      expect(u.canCreateEscalations, isTrue);
      expect(u.canViewDashboard, isTrue);
      expect(u.canViewEscalations, isTrue);
    });

    test('displayRole returns human-readable string', () {
      expect(makeUser(AppRole.superAdmin).displayRole,    'Super Admin');
      expect(makeUser(AppRole.authority).displayRole,     'Authority');
      expect(makeUser(AppRole.commandCenter).displayRole, 'Command Center');
      expect(makeUser(AppRole.organisation).displayRole,  'Organisation');
    });

    test('initials computed correctly', () {
      expect(
        CurrentUser(role: AppRole.commandCenter, username: 'manish kumar').initials,
        'MK',
      );
      expect(
        CurrentUser(role: AppRole.commandCenter, username: 'john').initials,
        'J',
      );
      expect(
        CurrentUser(role: AppRole.commandCenter, username: null).initials,
        '?',
      );
    });

    test('canAccess with role set', () {
      final u = makeUser(AppRole.commandCenter);
      expect(
        u.canAccess({AppRole.superAdmin, AppRole.commandCenter}),
        isTrue,
      );
      expect(
        u.canAccess({AppRole.superAdmin, AppRole.authority}),
        isFalse,
      );
    });
  });
}
