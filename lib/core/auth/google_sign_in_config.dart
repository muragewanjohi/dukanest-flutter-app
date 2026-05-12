import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/app_config.dart';

/// google_sign_in 7.x: [GoogleSignIn.initialize] must complete once before auth calls.
Future<void>? _googleSignInInitFuture;

Future<void> ensureGoogleSignInInitialized() {
  _googleSignInInitFuture ??= GoogleSignIn.instance.initialize(
    serverClientId: AppConfig.googleServerClientId.isEmpty
        ? null
        : AppConfig.googleServerClientId,
  );
  return _googleSignInInitFuture!;
}

/// Clears any cached Google session, then runs interactive sign-in.
///
/// Credential Manager can reuse a session that returns an account without an
/// [GoogleSignInAuthentication.idToken]. Signing out first yields a fresh
/// credential that includes the ID token when [serverClientId] is configured.
///
/// Always requests [openid] so the platform can mint an OIDC ID token.
Future<GoogleSignInAccount> authenticateGoogleInteractive() async {
  await ensureGoogleSignInInitialized();
  await GoogleSignIn.instance.signOut();
  return GoogleSignIn.instance.authenticate(
    scopeHint: const ['openid', 'email', 'profile'],
  );
}

/// Best-effort OAuth access token retrieval for google_sign_in 7.x.
Future<String?> resolveGoogleAccessToken(GoogleSignInAccount account) async {
  const scopes = ['openid', 'email', 'profile'];
  try {
    final authz =
        await account.authorizationClient.authorizationForScopes(scopes) ??
            await account.authorizationClient.authorizeScopes(scopes);
    return authz.accessToken;
  } on GoogleSignInException {
    return null;
  } catch (_) {
    return null;
  }
}

bool androidNeedsGoogleServerClientId() {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
