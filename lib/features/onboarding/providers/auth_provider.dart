import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/api/api_client.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
    ref.watch(tokenStorageProvider),
  );
});

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
    state = state.copyWith(error: null); // Clear previous errors
    final response = await _authService.login(email, password);

    if (response.success && response.data != null) {
      final data = response.data!;
      await _tokenStorage.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      
      final user = AuthUser.fromJson(data['user']);
      
      if (user.isMfaEnabled && data['mfa_required'] == true) {
        state = state.copyWith(status: AuthStatus.awaitingMfa, user: user);
      } else {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      }
    } else {
      state = state.copyWith(
        error: response.error?.message ?? 'Login failed',
      );
    }
  }

  Future<void> verifyMfa(String code) async {
    state = state.copyWith(error: null);
    final response = await _authService.verifyMfa(code);
    
    if (response.success && response.data != null) {
      // Assuming verification returns full fresh tokens
      await _tokenStorage.saveTokens(
        accessToken: response.data!['access_token'],
        refreshToken: response.data!['refresh_token'],
      );
      state = state.copyWith(status: AuthStatus.authenticated);
    } else {
      state = state.copyWith(error: response.error?.message ?? 'MFA verification failed');
    }
  }

  Future<void> googleSignIn(String idToken) async {
    state = state.copyWith(error: null);
    final response = await _authService.googleSignIn(idToken);
    
    if (response.success && response.data != null) {
      final data = response.data!;
      await _tokenStorage.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      
      final user = AuthUser.fromJson(data['user']);
      if (user.isMfaEnabled && data['mfa_required'] == true) {
         state = state.copyWith(status: AuthStatus.awaitingMfa, user: user);
      } else {
         state = state.copyWith(status: AuthStatus.authenticated, user: user);
      }
    } else {
       state = state.copyWith(error: response.error?.message ?? 'Google Sign In failed');
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    await _tokenStorage.clearTokens();
    state = state.copyWith(status: AuthStatus.unauthenticated, user: null, error: null);
  }
}
