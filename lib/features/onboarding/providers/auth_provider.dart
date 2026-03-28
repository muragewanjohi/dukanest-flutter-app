import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/token_storage.dart';
import '../../../config/app_mode.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
    ref.watch(tokenStorageProvider),
  );
});

String? _pickString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}

Map<String, dynamic>? _pickMap(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is Map) return Map<String, dynamic>.from(v);
  }
  return null;
}

({String? access, String? refresh}) _extractTokens(Map<String, dynamic> data) {
  final session = _pickMap(data, ['session', 'tempSession']);
  final access = _pickString(session ?? data, ['access_token', 'accessToken']);
  final refresh = _pickString(session ?? data, ['refresh_token', 'refreshToken']);
  return (access: access, refresh: refresh);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final TokenStorage _tokenStorage;

  AuthNotifier(this._authService, this._tokenStorage) : super(AuthState()) {
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      // In a real app we'd decode JWT or fetch user profile here.
      // For MVP we assume token valid if present.
      // If 401 later, our interceptor will handle it or log user out.
      state = state.copyWith(status: AuthStatus.authenticated);
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    if (kDemoMode) {
      loginWithDemoUser(email: email);
      return;
    }

    state = state.copyWith(clearError: true);
    final response = await _authService.login(email, password);

    if (response.success && response.data != null) {
      final data = response.data!;
      final userMap = data['user'];
      if (userMap is! Map) {
        state = state.copyWith(error: 'Invalid login response');
        return;
      }
      final mappedUser = Map<String, dynamic>.from(userMap);
      final user = AuthUser.fromJson(mappedUser);

      final requiresMfa = data['requiresMfa'] == true ||
          data['mfa_required'] == true ||
          data['mfaRequired'] == true;
      final pendingMfa =
          requiresMfa || (user.isMfaEnabled && data['mfa_required'] == true);

      final tempSessionRaw = data['tempSession'] ?? data['session'];
      Map<String, dynamic>? tempSession;
      if (tempSessionRaw is Map) {
        tempSession = Map<String, dynamic>.from(tempSessionRaw);
      }
      final tempAccess = tempSession != null
          ? _pickString(tempSession, ['accessToken', 'access_token'])
          : null;
      final tempRefresh = tempSession != null
          ? (_pickString(tempSession, ['refreshToken', 'refresh_token']) ?? '')
          : null;

      final tokens = _extractTokens(data);
      final access = tokens.access;
      final refresh = tokens.refresh;

      if (pendingMfa) {
        if (tempAccess != null) {
          await _tokenStorage.saveTokens(
            accessToken: tempAccess,
            refreshToken: tempRefresh ?? '',
          );
        } else if (access != null) {
          await _tokenStorage.saveTokens(
            accessToken: access,
            refreshToken: refresh ?? '',
          );
        }
        state = state.copyWith(
          status: AuthStatus.awaitingMfa,
          user: user,
          clearError: true,
        );
      } else {
        if (access != null) {
          await _tokenStorage.saveTokens(
            accessToken: access,
            refreshToken: refresh ?? '',
          );
        }
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          clearError: true,
        );
      }
    } else {
      state = state.copyWith(
        error: response.error?.message ?? 'Login failed',
      );
    }
  }

  void loginWithDemoUser({required String email}) {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: AuthUser(
        id: 'demo-user',
        email: email,
        role: 'owner',
        tenantId: 'demo-tenant-1',
        isMfaEnabled: false,
      ),
      clearError: true,
    );
  }

  Future<void> verifyMfa(String code) async {
    state = state.copyWith(clearError: true);
    final user = state.user;
    if (user == null) {
      state = state.copyWith(error: 'Session expired. Please sign in again.');
      return;
    }
    final tempAccess = await _tokenStorage.getAccessToken();
    final tempRefresh = await _tokenStorage.getRefreshToken();
    if (tempAccess == null || tempRefresh == null) {
      state = state.copyWith(error: 'Session expired. Please sign in again.');
      return;
    }

    final response = await _authService.verifyMfa(
      userId: user.id,
      code: code,
      tempAccessToken: tempAccess,
      tempRefreshToken: tempRefresh,
    );

    if (response.success && response.data != null) {
      final d = response.data!;
      final tokens = _extractTokens(d);
      final access = tokens.access;
      final refresh = tokens.refresh;
      if (access != null) {
        await _tokenStorage.saveTokens(
          accessToken: access,
          refreshToken: refresh ?? '',
        );
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        error: response.error?.message ?? 'MFA verification failed',
      );
    }
  }

  Future<void> resendMfaCode() async {
    final user = state.user;
    if (user == null) return;
    state = state.copyWith(clearError: true);
    final response = await _authService.sendMfaCode(user.id);
    if (!response.success) {
      state = state.copyWith(
        error: response.error?.message ?? 'Could not resend code',
      );
    }
  }

  Future<void> cancelMfa() async {
    await _tokenStorage.clearTokens();
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearUser: true,
      clearError: true,
    );
  }

  Future<void> googleSignIn(String idToken) async {
    if (kDemoMode) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: AuthUser(
          id: 'demo-google-user',
          email: 'owner@dukanest.demo',
          role: 'owner',
          tenantId: 'demo-tenant-1',
          isMfaEnabled: false,
        ),
        clearError: true,
      );
      return;
    }

    state = state.copyWith(clearError: true);
    final response = await _authService.googleSignIn(idToken);

    if (response.success && response.data != null) {
      final data = response.data!;
      final tokens = _extractTokens(data);
      final access = tokens.access;
      final refresh = tokens.refresh;
      if (access != null) {
        await _tokenStorage.saveTokens(
          accessToken: access,
          refreshToken: refresh ?? '',
        );
      }

      final userMap = data['user'];
      if (userMap is! Map) {
        state = state.copyWith(error: 'Invalid sign-in response');
        return;
      }
      final mappedUser = Map<String, dynamic>.from(userMap);
      final user = AuthUser.fromJson(mappedUser);

      // Google sign-in: skip email OTP — OAuth satisfies the second factor.
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        clearError: true,
      );
    } else {
      state = state.copyWith(error: response.error?.message ?? 'Google Sign In failed');
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    await _tokenStorage.clearTokens();
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearUser: true,
      clearError: true,
    );
  }
}
