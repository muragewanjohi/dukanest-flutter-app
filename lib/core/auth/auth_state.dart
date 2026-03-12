enum AuthStatus {
  initial,
  unauthenticated,
  checkingMfa,
  awaitingMfa,
  authenticated,
}

class AuthUser {
  final String id;
  final String email;
  final String role;
  final String? tenantId;
  final bool isMfaEnabled;

  AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.tenantId,
    required this.isMfaEnabled,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'user',
      tenantId: json['tenant_id'] as String?,
      isMfaEnabled: json['is_mfa_enabled'] as bool? ?? false,
    );
  }
}

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? error;

  AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}
