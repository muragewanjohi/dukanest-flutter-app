enum AuthStatus {
  /// Secure storage + optional `/auth/me` not finished yet.
  initial,
  /// Access token present; validating with `GET /auth/me`.
  sessionRestoring,
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
  /// Display name from auth (`name`, `fullName`, Supabase metadata, etc.).
  final String? name;

  AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.tenantId,
    required this.isMfaEnabled,
    this.name,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    String? pickName() {
      for (final key in [
        'name',
        'fullName',
        'full_name',
        'displayName',
        'display_name',
      ]) {
        final v = json[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      final meta = json['user_metadata'] ?? json['userMetadata'];
      if (meta is Map) {
        final m = Map<String, dynamic>.from(meta);
        for (final key in ['full_name', 'name', 'display_name']) {
          final v = m[key];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
      return null;
    }

    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'user',
      tenantId: json['tenant_id'] as String? ?? json['tenantId'] as String?,
      isMfaEnabled:
          json['is_mfa_enabled'] as bool? ?? json['mfaEnabled'] as bool? ?? false,
      name: pickName(),
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
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
    );
  }
}
