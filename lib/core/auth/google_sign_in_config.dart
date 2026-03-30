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

bool androidNeedsGoogleServerClientId() {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
