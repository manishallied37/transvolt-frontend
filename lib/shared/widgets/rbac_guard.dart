import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';

/// [RbacGuard] — wraps any widget with a role/permission check.
///
/// If the user does NOT have the required permission or role,
/// [fallback] is shown instead (default: empty SizedBox, i.e. hidden).
///
/// Usage — permission-based (preferred):
/// ```dart
/// RbacGuard(
///   permission: Permission.escalationUpdateStatus,
///   child: ElevatedButton(onPressed: _updateStatus, child: Text('Update')),
/// )
/// ```
///
/// Usage — role-based:
/// ```dart
/// RbacGuard(
///   roles: {AppRole.superAdmin, AppRole.authority},
///   child: AdminPanel(),
///   fallback: Text('Access denied'),
/// )
/// ```
class RbacGuard extends ConsumerWidget {
  final Widget child;
  final Widget fallback;
  final String? permission;
  final Set<String>? roles;

  const RbacGuard({
    super.key,
    required this.child,
    this.fallback = const SizedBox.shrink(),
    this.permission,
    this.roles,
  }) : assert(
          permission != null || roles != null,
          'RbacGuard requires either permission or roles.',
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, _) => fallback,
      data:    (user) {
        bool allowed = false;

        if (permission != null) {
          allowed = user.can(permission!);
        } else if (roles != null) {
          allowed = user.canAccess(roles!);
        }

        return allowed ? child : fallback;
      },
    );
  }
}

/// Convenience version that hides the child completely when not permitted.
/// Identical to RbacGuard with default fallback = SizedBox.shrink().
class PermissionGuard extends ConsumerWidget {
  final String permission;
  final Widget child;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.maybeWhen(
      data: (user) => user.can(permission) ? child : const SizedBox.shrink(),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Full-screen RBAC guard — shows an "Access Denied" screen
/// when the user navigates to a route they're not allowed to see.
class RbacScreen extends ConsumerWidget {
  final Widget child;
  final String? permission;
  final Set<String>? roles;

  const RbacScreen({
    super.key,
    required this.child,
    this.permission,
    this.roles,
  }) : assert(
          permission != null || roles != null,
          'RbacScreen requires either permission or roles.',
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const _AccessDeniedScreen(),
      data: (user) {
        bool allowed = false;
        if (permission != null) {
          allowed = user.can(permission!);
        } else if (roles != null) {
          allowed = user.canAccess(roles!);
        }
        return allowed ? child : const _AccessDeniedScreen();
      },
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEBEB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 36,
                  color: Color(0xFFA32D2D),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You do not have permission to view this section.\nContact your administrator if you believe this is an error.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black45, height: 1.5),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
