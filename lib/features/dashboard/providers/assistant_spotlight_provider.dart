import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the first-run spotlight on the Assistant tab has been dismissed
/// this session (tab tapped, or explicit dismiss). Deliberately in-memory
/// only, not persisted across app launches — the app has no lightweight
/// local-flag storage already wired up (no `shared_preferences` usage
/// anywhere, `hive_flutter` is a declared but never-initialized dependency),
/// and the REAL, durable signal for "have they tried it" is already
/// server-side: the 'assistant' getting-started checklist item
/// (`dashboardGettingStartedProvider`), marked done the moment they send
/// their first message. This flag only prevents re-showing the nudge
/// mid-session after a merchant dismisses it without sending a message —
/// worst case on a cold relaunch it can reappear once more, a minor
/// polish gap, not a functional one.
final assistantSpotlightDismissedProvider = StateProvider<bool>((ref) => false);
