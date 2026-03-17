import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/rbac.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/rbac_guard.dart';
import '../services/user_management_service.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await UserManagementService.listUsers(page: _page);
      final data = result['data'] as Map<String, dynamic>? ?? result;
      setState(() {
        _users = List<Map<String, dynamic>>.from(data['users'] ?? []);
        _totalPages = (data['totalPages'] as int?) ?? 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Role display helpers ──────────────────────────────────────────────────

  Color _roleBg(String? role) {
    switch (role) {
      case AppRole.superAdmin:
        return const Color(0xFFEEEDFE);
      case AppRole.authority:
        return const Color(0xFFFAEEDA);
      case AppRole.commandCenter:
        return const Color(0xFFE6F1FB);
      case AppRole.organisation:
        return const Color(0xFFEAF3DE);
      default:
        return const Color(0xFFF1EFE8);
    }
  }

  Color _roleText(String? role) {
    switch (role) {
      case AppRole.superAdmin:
        return const Color(0xFF534AB7);
      case AppRole.authority:
        return const Color(0xFF854F0B);
      case AppRole.commandCenter:
        return const Color(0xFF185FA5);
      case AppRole.organisation:
        return const Color(0xFF3B6D11);
      default:
        return const Color(0xFF5F5E5A);
    }
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // ── Create user sheet ─────────────────────────────────────────────────────

  void _showCreateUserSheet(CurrentUser currentUser) {
    final usernameC = TextEditingController();
    final emailC = TextEditingController();
    final passwordC = TextEditingController();
    final regionC = TextEditingController();
    final depotC = TextEditingController();
    final mobileC = TextEditingController();
    String? selectedRole;
    bool loading = false;
    bool hidePassword = true;
    String? fullMobileNumber;

    // Only SuperAdmin can create users — other roles have no creation rights
    final creatableRoles = currentUser.isSuperAdmin
        ? [AppRole.authority, AppRole.commandCenter, AppRole.organisation]
        : <String>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create New User',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'New user will receive login credentials via email',
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),
                const SizedBox(height: 20),

                _field(usernameC, 'Username', Icons.person_outline),
                const SizedBox(height: 12),
                _field(
                  emailC,
                  'Email',
                  Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),

                // Password
                TextField(
                  controller: passwordC,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () =>
                          setSheet(() => hidePassword = !hidePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Role picker
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  hint: const Text(
                    'Select role',
                    style: TextStyle(fontSize: 14),
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                  items: creatableRoles
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, style: const TextStyle(fontSize: 14)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSheet(() => selectedRole = v),
                ),
                const SizedBox(height: 12),
                _field(regionC, 'Region (optional)', Icons.map_outlined),
                const SizedBox(height: 12),
                _field(depotC, 'Depot (optional)', Icons.warehouse_outlined),
                const SizedBox(height: 12),
                IntlPhoneField(
                  decoration: InputDecoration(
                    labelText: 'Mobile',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  initialCountryCode: 'IN',
                  onChanged: (phone) {
                    fullMobileNumber = phone.completeNumber;
                  },
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (usernameC.text.trim().isEmpty ||
                                emailC.text.trim().isEmpty ||
                                passwordC.text.trim().isEmpty ||
                                selectedRole == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please fill all required fields',
                                  ),
                                ),
                              );
                              return;
                            }
                            setSheet(() => loading = true);
                            try {
                              await UserManagementService.createUser(
                                username: usernameC.text.trim(),
                                email: emailC.text.trim(),
                                password: passwordC.text.trim(),
                                role: selectedRole!,
                                region: regionC.text.trim().isNotEmpty
                                    ? regionC.text.trim()
                                    : null,
                                depot: depotC.text.trim().isNotEmpty
                                    ? depotC.text.trim()
                                    : null,
                                mobileNumber: fullMobileNumber,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadUsers();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('User created successfully'),
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheet(() => loading = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString().replaceAll(
                                        'Exception: ',
                                        '',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF534AB7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create User',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── User actions sheet ────────────────────────────────────────────────────

  void _showUserActions(Map<String, dynamic> user, CurrentUser currentUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _roleBg(user['role'] as String?),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _initials(user['username'] as String?),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _roleText(user['role'] as String?),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['username'] ?? '-',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      user['email'] ?? '-',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(thickness: 0.5),
            const SizedBox(height: 8),

            // Toggle active status — SuperAdmin + Authority
            if (currentUser.isSuperAdmin || currentUser.isAuthority)
              _actionTile(
                icon: (user['is_active'] == true)
                    ? Icons.person_off_outlined
                    : Icons.person_outlined,
                label: (user['is_active'] == true)
                    ? 'Deactivate user'
                    : 'Activate user',
                color: (user['is_active'] == true)
                    ? const Color(0xFFA32D2D)
                    : const Color(0xFF3B6D11),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await UserManagementService.updateUser(
                      user['id'] as int,
                      isActive: !(user['is_active'] as bool? ?? true),
                    );
                    _loadUsers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User status updated')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceAll('Exception: ', ''),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),

            // Change role — SuperAdmin only
            if (currentUser.isSuperAdmin)
              _actionTile(
                icon: Icons.swap_horiz_rounded,
                label: 'Change role',
                color: const Color(0xFF185FA5),
                onTap: () {
                  Navigator.pop(context);
                  _showChangeRoleSheet(user);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showChangeRoleSheet(Map<String, dynamic> user) {
    String? selectedRole;
    bool loading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change role for ${user['username']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ...AppRole.all.map((role) {
                final isSelected = selectedRole == role;
                final isCurrent = user['role'] == role;
                return GestureDetector(
                  onTap: () => setSheet(() => selectedRole = role),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEEEDFE)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF534AB7)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            role,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF3C3489)
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          const Text(
                            'Current',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
                          ),
                        if (isSelected && !isCurrent)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF534AB7),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      loading ||
                          selectedRole == null ||
                          selectedRole == user['role']
                      ? null
                      : () async {
                          setSheet(() => loading = true);
                          try {
                            await UserManagementService.changeUserRole(
                              user['id'] as int,
                              selectedRole!,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadUsers();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Role changed successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            setSheet(() => loading = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF534AB7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm role change',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Full-screen RBAC guard — Organisation cannot reach this tab (nav won't
    // show it), but this is a defence-in-depth fallback.
    return RbacScreen(permission: Permission.userRead, child: _buildContent());
  }

  Widget _buildContent() {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Failed to load user'))),
      data: (currentUser) => Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'User Management',
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
          // Create button — SuperAdmin only
          actions: [
            RbacGuard(
              roles: {AppRole.superAdmin},
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  onPressed: () => _showCreateUserSheet(currentUser),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('New User', style: TextStyle(fontSize: 13)),
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
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : _buildList(currentUser),
      ),
    );
  }

  Widget _buildList(CurrentUser currentUser) {
    if (_users.isEmpty) {
      return const Center(
        child: Text('No users found', style: TextStyle(color: Colors.black45)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _users.length + 1,
        itemBuilder: (_, i) {
          if (i == _users.length) return _buildPagination();
          return _buildUserCard(_users[i], currentUser);
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, CurrentUser currentUser) {
    final role = user['role'] as String?;
    final isActive = user['is_active'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isActive ? _roleBg(role) : const Color(0xFFF1EFE8),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _initials(user['username'] as String?),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isActive ? _roleText(role) : Colors.black38,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user['username'] ?? '-',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.black87 : Colors.black38,
                ),
              ),
            ),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EFE8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Inactive',
                  style: TextStyle(fontSize: 10, color: Colors.black38),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              user['email'] ?? '-',
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _roleBg(role),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role ?? '-',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _roleText(role),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (user['region'] != null)
                  Text(
                    user['region'] as String,
                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
              ],
            ),
          ],
        ),
        // Actions — only show if current user can modify
        trailing: (currentUser.isSuperAdmin || currentUser.isAuthority)
            ? IconButton(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.black38,
                ),
                onPressed: () => _showUserActions(user, currentUser),
              )
            : null,
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1
                ? () {
                    _page--;
                    _loadUsers();
                  }
                : null,
          ),
          Text(
            'Page $_page of $_totalPages',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < _totalPages
                ? () {
                    _page++;
                    _loadUsers();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.black26, size: 40),
          const SizedBox(height: 12),
          Text(
            _error!.replaceAll('Exception: ', ''),
            style: const TextStyle(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: _loadUsers, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(fontSize: 14, color: color)),
      onTap: onTap,
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black12, width: 0.5),
        ),
      ),
    );
  }
}
