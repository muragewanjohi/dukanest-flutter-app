import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';

/// One message rendered on screen — mirrors web's DisplayMessage
/// (onboarding-chat-client.tsx).
class OnboardingChatMessage {
  const OnboardingChatMessage({required this.role, required this.text});

  final String role; // 'user' | 'assistant'
  final String text;
}

/// Onboarding AI Chat (OC.3) — bearer-token mirror of web's
/// src/app/dashboard/onboarding/chat/onboarding-chat-client.tsx, driving
/// POST /api/v1/mobile/onboarding/chat turn by turn and saving the result
/// via PATCH /api/v1/mobile/onboarding/business-context on completion.
/// Additive, not a gate — see IMPLEMENTATION_TRACKER.md's OC.2 scope note;
/// this screen is reachable but never blocks a merchant from using the app.
class OnboardingChatState {
  const OnboardingChatState({
    this.contextLoading = true,
    this.storeName,
    this.knownBusinessType,
    this.knownNiche,
    this.messages = const [],
    this.history = const [],
    this.loading = false,
    this.done = false,
    this.saved = false,
    this.errored = false,
  });

  /// True while the initial GET business-context call (to learn whether
  /// this merchant already finished onboarding) is in flight.
  final bool contextLoading;

  final String? storeName;
  final String? knownBusinessType;
  final String? knownNiche;

  /// What's rendered on screen.
  final List<OnboardingChatMessage> messages;

  /// What's sent to the API each turn — mirrors web's stateless-per-request
  /// history, including the JSON-stringified-full-turn quirk for assistant
  /// entries (see _sendTurn below).
  final List<Map<String, String>> history;

  final bool loading;
  final bool done;

  /// Whether PATCH business-context succeeded once done:true. Only
  /// meaningful when `done` is true.
  final bool saved;

  /// A turn failed (network/API error) — never traps the merchant; the
  /// screen always offers a "Skip for now" escape hatch when this is true
  /// and `done` is still false (OC.5).
  final bool errored;

  OnboardingChatState copyWith({
    bool? contextLoading,
    String? storeName,
    String? knownBusinessType,
    String? knownNiche,
    List<OnboardingChatMessage>? messages,
    List<Map<String, String>>? history,
    bool? loading,
    bool? done,
    bool? saved,
    bool? errored,
  }) {
    return OnboardingChatState(
      contextLoading: contextLoading ?? this.contextLoading,
      storeName: storeName ?? this.storeName,
      knownBusinessType: knownBusinessType ?? this.knownBusinessType,
      knownNiche: knownNiche ?? this.knownNiche,
      messages: messages ?? this.messages,
      history: history ?? this.history,
      loading: loading ?? this.loading,
      done: done ?? this.done,
      saved: saved ?? this.saved,
      errored: errored ?? this.errored,
    );
  }
}

const _kickoff = {'role': 'user', 'content': '(Start the onboarding conversation.)'};

class OnboardingChatNotifier extends StateNotifier<OnboardingChatState> {
  OnboardingChatNotifier(this._api) : super(const OnboardingChatState()) {
    _init();
  }

  final ApiClient _api;
  bool _started = false;

  Future<void> _init() async {
    try {
      final response = await _api.getOnboardingBusinessContext();
      var data = response.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic> && data['storeName'] == null) {
        data = data['data'];
      }
      final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
      state = state.copyWith(
        contextLoading: false,
        storeName: map['storeName'] as String?,
        knownBusinessType: map['businessType'] as String?,
        knownNiche: map['niche'] as String?,
      );
    } catch (_) {
      // Non-fatal — proceed without pre-seeded context, same as web's
      // Prisma read failing open to `undefined` never having been a
      // concern there (server component would just 500); here we degrade
      // to "ask everything" rather than blocking the screen from loading.
      state = state.copyWith(contextLoading: false);
    }

    // Mirrors web's initial-turn effect: only auto-start if the merchant
    // hasn't already told us their niche.
    if (!_started && state.knownNiche == null) {
      _started = true;
      state = state.copyWith(history: const [_kickoff]);
      await _sendTurn(const [_kickoff]);
    }
  }

  void _pushMessage(OnboardingChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.loading || state.done) return;

    _pushMessage(OnboardingChatMessage(role: 'user', text: trimmed));
    final next = [...state.history, {'role': 'user', 'content': trimmed}];
    state = state.copyWith(history: next, errored: false);
    await _sendTurn(next);
  }

  Future<void> _sendTurn(List<Map<String, String>> history) async {
    state = state.copyWith(loading: true);
    try {
      final response = await _api.postOnboardingChat(
        history,
        storeName: state.storeName,
        knownBusinessType: state.knownBusinessType,
      );

      if (!response.success) {
        _pushMessage(OnboardingChatMessage(
          role: 'assistant',
          text: response.error?.message ??
              'The onboarding assistant is temporarily unavailable. You can skip this and set it up later.',
        ));
        state = state.copyWith(errored: true);
        return;
      }

      var data = response.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic> && data['reply'] == null) {
        data = data['data'];
      }
      if (data is! Map<String, dynamic>) {
        _pushMessage(const OnboardingChatMessage(
          role: 'assistant',
          text: 'The onboarding assistant returned an unexpected response.',
        ));
        state = state.copyWith(errored: true);
        return;
      }

      final reply = (data['reply'] as String?)?.trim() ?? '';
      final done = data['done'] == true;
      final collected = data['collected'];

      if (reply.isNotEmpty) {
        _pushMessage(OnboardingChatMessage(role: 'assistant', text: reply));
      }
      // Mirrors web's quirk of storing the full JSON turn (not just the
      // reply text) as the "assistant" message in history — Claude uses it
      // as its own memory of what's already been collected.
      state = state.copyWith(history: [
        ...history,
        {'role': 'assistant', 'content': jsonEncode(data)},
      ]);

      if (done) {
        state = state.copyWith(done: true);
        if (collected is Map<String, dynamic>) {
          await _saveBusinessContext(
            businessType: collected['businessType'] as String?,
            niche: collected['niche'] as String?,
          );
        }
      }
    } catch (e) {
      _pushMessage(OnboardingChatMessage(role: 'assistant', text: apiErrorMessage(e)));
      state = state.copyWith(errored: true);
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> _saveBusinessContext({String? businessType, String? niche}) async {
    if ((businessType == null || businessType.isEmpty) && (niche == null || niche.isEmpty)) {
      return;
    }
    try {
      final response = await _api.patchOnboardingBusinessContext(businessType: businessType, niche: niche);
      state = state.copyWith(saved: response.success);
    } catch (_) {
      // Non-fatal — mirrors web's saveBusinessContext, which never blocks
      // the merchant from continuing to the dashboard even if this fails.
      state = state.copyWith(saved: false);
    }
  }
}

final onboardingChatProvider =
    StateNotifierProvider.autoDispose<OnboardingChatNotifier, OnboardingChatState>((ref) {
  final api = ref.read(apiClientProvider);
  return OnboardingChatNotifier(api);
});
