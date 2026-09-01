import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../../dashboard/providers/dashboard_getting_started_provider.dart';

/// One message in the assistant conversation, for display. `citedArticles`
/// and `nextSteps` mirror the equivalent fields the web assistant panel
/// renders (src/components/dashboard/assistant/assistant-panel.tsx) —
/// keeping the same shape so both platforms present the same information.
class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    this.citedArticles = const [],
    this.nextSteps = const [],
    this.isError = false,
  });

  final String role; // 'user' | 'assistant'
  final String text;
  final List<Map<String, dynamic>> citedArticles;
  final List<Map<String, dynamic>> nextSteps;
  final bool isError;
}

/// A collected-so-far product from the product_intake conversation — mirrors
/// web's CollectedProduct (assistant-panel.tsx).
class _CollectedProduct {
  const _CollectedProduct({this.name, this.price, this.stockQuantity, this.category, this.sku, this.requiresShipping});

  final String? name;
  final num? price;
  final int? stockQuantity;
  final String? category;
  final String? sku;
  // Basic services support (docs/SERVICES_PLAN.md)
  final bool? requiresShipping;

  static _CollectedProduct fromJson(Map<String, dynamic> json) {
    return _CollectedProduct(
      name: json['name'] as String?,
      price: json['price'] as num?,
      stockQuantity: (json['stockQuantity'] as num?)?.toInt(),
      category: json['category'] as String?,
      sku: json['sku'] as String?,
      requiresShipping: json['requiresShipping'] as bool?,
    );
  }
}

/// A collected-so-far delivery zone from the delivery_zone_intake
/// conversation — mirrors web's CollectedZone (assistant-panel.tsx).
class _CollectedZone {
  const _CollectedZone({this.name, this.price, this.locations = const []});

  final String? name;
  final num? price;
  final List<String> locations;

  static _CollectedZone fromJson(Map<String, dynamic> json) {
    return _CollectedZone(
      name: json['name'] as String?,
      price: json['price'] as num?,
      locations: (json['locations'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

/// 'assistant' = normal Q&A mode. 'product_intake' = the assistant handed
/// off to conversational product creation (configuration_guidance ->
/// target: 'product_intake') and is now driving POST
/// /api/v1/mobile/products/ai-intake turn by turn — mirrors web's Mode type
/// (assistant-panel.tsx). 'deliveryZoneIntake' (AI Phase 7.1) is the same
/// pattern for target: 'delivery_zone', driving
/// /api/v1/mobile/delivery-zones/ai-intake.
enum AssistantMode { assistant, productIntake, deliveryZoneIntake }

class AssistantChatState {
  const AssistantChatState({
    this.messages = const [],
    this.history = const [],
    this.loading = false,
    this.mode = AssistantMode.assistant,
    this.intakeHistory = const [],
    this.zoneIntakeHistory = const [],
  });

  /// What's rendered on screen.
  final List<AssistantMessage> messages;

  /// What's sent to the API each turn — plain {role, content} text, the
  /// same stateless-per-request contract the web assistant uses (see
  /// POST /api/v1/mobile/assistant/chat).
  final List<Map<String, String>> history;

  final bool loading;

  final AssistantMode mode;

  /// Separate stateless history for the product_intake sub-conversation —
  /// kept apart from `history` so switching back to assistant mode doesn't
  /// lose either thread, same as web's separate assistantHistory/intakeHistory.
  final List<Map<String, String>> intakeHistory;

  /// Same separation as `intakeHistory`, for the delivery_zone_intake
  /// sub-conversation (AI Phase 7.1).
  final List<Map<String, String>> zoneIntakeHistory;

  AssistantChatState copyWith({
    List<AssistantMessage>? messages,
    List<Map<String, String>>? history,
    bool? loading,
    AssistantMode? mode,
    List<Map<String, String>>? intakeHistory,
    List<Map<String, String>>? zoneIntakeHistory,
  }) {
    return AssistantChatState(
      messages: messages ?? this.messages,
      history: history ?? this.history,
      loading: loading ?? this.loading,
      mode: mode ?? this.mode,
      intakeHistory: intakeHistory ?? this.intakeHistory,
      zoneIntakeHistory: zoneIntakeHistory ?? this.zoneIntakeHistory,
    );
  }
}

const _welcomeText =
    "Hi! I can answer questions about your store's data, help you understand "
    "DukaNest's features, add a product or sale, suggest categories or "
    "pricing for your business, write a social/WhatsApp/SMS post or a blog "
    "post to share with your customers, or tell you what to set up next. What can I help with?";

const _suggestedPrompts = <String>[
  'What should I do next?',
  'How do I add a product?',
  'How many orders do I have?',
  'Write a social post about my new arrivals',
  'Create a sale for my store',
  'Write a blog post about caring for my products',
];

List<String> get assistantSuggestedPrompts => _suggestedPrompts;

const _intakeStart = {'role': 'user', 'content': '(Start the product intake conversation.)'};
const _zoneIntakeStart = {'role': 'user', 'content': '(Start the delivery zone setup conversation.)'};

class AssistantChatNotifier extends StateNotifier<AssistantChatState> {
  AssistantChatNotifier(this._api, this._ref)
      : super(const AssistantChatState(
          messages: [AssistantMessage(role: 'assistant', text: _welcomeText)],
        ));

  final ApiClient _api;
  final Ref _ref;
  bool _hasMarkedTried = false;

  /// Marks the 'assistant' getting-started checklist item done — mirrors
  /// web's `markAssistantTried()` (assistant-panel.tsx). Fire-and-forget,
  /// guarded to fire once per screen visit; best-effort, never surfaces an
  /// error (worst case the checklist item just doesn't tick off).
  void _markAssistantTried() {
    if (_hasMarkedTried) return;
    _hasMarkedTried = true;
    _api.postGettingStartedAction('assistant_tried').then((_) {
      // Refresh so the first-run spotlight (dashboard_shell.dart) picks up
      // the new completed state promptly instead of on its next natural refetch.
      _ref.invalidate(dashboardGettingStartedProvider);
    }).catchError((_) {});
  }

  void _pushMessage(AssistantMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.loading) return;

    _pushMessage(AssistantMessage(role: 'user', text: trimmed));
    _markAssistantTried();
    state = state.copyWith(loading: true);

    try {
      if (state.mode == AssistantMode.productIntake) {
        final next = [...state.intakeHistory, {'role': 'user', 'content': trimmed}];
        state = state.copyWith(intakeHistory: next);
        await _sendIntakeTurn(next);
      } else if (state.mode == AssistantMode.deliveryZoneIntake) {
        final next = [...state.zoneIntakeHistory, {'role': 'user', 'content': trimmed}];
        state = state.copyWith(zoneIntakeHistory: next);
        await _sendZoneIntakeTurn(next);
      } else {
        final next = [...state.history, {'role': 'user', 'content': trimmed}];
        state = state.copyWith(history: next);
        await _sendAssistantTurn(next);
      }
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> _sendAssistantTurn(List<Map<String, String>> history) async {
    try {
      final response = await _api.postAssistantChat(history);

      if (!response.success) {
        _pushError(response.error?.message ??
            'The assistant is temporarily unavailable. Please try again shortly.');
        return;
      }

      // Defensive double-unwrap — several providers in this app guard
      // against the payload arriving double-nested; cheap insurance here
      // even though the mobile assistant route only nests one level.
      var payload = response.data;
      if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic> && payload['answer'] == null) {
        payload = payload['data'];
      }
      if (payload is! Map<String, dynamic>) {
        _pushError('The assistant returned an unexpected response.');
        return;
      }

      final answer = (payload['answer'] as String?)?.trim();
      if (answer == null || answer.isEmpty) {
        _pushError('The assistant returned an empty response.');
        return;
      }

      final innerData = payload['data'];
      final citedArticles = _extractList(innerData, 'citedArticles');
      final nextSteps = _extractList(innerData, 'steps');
      final intent = payload['intent'] as String?;
      final target = innerData is Map<String, dynamic> ? innerData['target'] as String? : null;
      final endpoint = innerData is Map<String, dynamic> ? innerData['endpoint'] as String? : null;

      _pushMessage(AssistantMessage(
        role: 'assistant',
        text: answer,
        citedArticles: citedArticles,
        nextSteps: nextSteps,
      ));
      state = state.copyWith(history: [
        ...history,
        {'role': 'assistant', 'content': answer},
      ]);

      // Hand off into product_intake mode — mirrors web's equivalent branch
      // (assistant-panel.tsx). Only triggers when the backend actually
      // returned the intake endpoint (it always does for this target
      // today, but this keeps the client honest about what it's trusting).
      if (intent == 'configuration_guidance' && target == 'product_intake' && endpoint != null) {
        state = state.copyWith(mode: AssistantMode.productIntake, intakeHistory: const [_intakeStart]);
        await _sendIntakeTurn(const [_intakeStart]);
      } else if (intent == 'configuration_guidance' && target == 'delivery_zone' && endpoint != null) {
        state = state.copyWith(mode: AssistantMode.deliveryZoneIntake, zoneIntakeHistory: const [_zoneIntakeStart]);
        await _sendZoneIntakeTurn(const [_zoneIntakeStart]);
      }
    } catch (e) {
      // ApiClient.postAssistantChat() calls Dio directly rather than
      // through dioPostEnvelope (dio_envelope.dart) — Dio throws on any
      // non-2xx response by default (quota/rate-limit 403s included, e.g.
      // "assistant_query limit reached (20/20) for this month"), so
      // response.success is never actually reached for those; the real
      // message lives on the thrown DioException instead. apiErrorMessage()
      // is the same extraction the rest of the app already uses (e.g.
      // product_editor_screen.dart) — never swallow it behind generic text.
      _pushError(apiErrorMessage(e));
    }
  }

  Future<void> _sendIntakeTurn(List<Map<String, String>> history) async {
    try {
      final response = await _api.postProductAiIntake(history);

      if (!response.success) {
        _pushError(response.error?.message ??
            'Something went wrong — you can add the product from the Products tab instead.');
        state = state.copyWith(mode: AssistantMode.assistant);
        return;
      }

      var data = response.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic> && data['reply'] == null) {
        data = data['data'];
      }
      if (data is! Map<String, dynamic>) {
        _pushError('The assistant returned an unexpected response.');
        state = state.copyWith(mode: AssistantMode.assistant);
        return;
      }

      final reply = (data['reply'] as String?)?.trim() ?? '';
      final done = data['done'] == true;

      if (reply.isNotEmpty) {
        _pushMessage(AssistantMessage(role: 'assistant', text: reply));
      }
      // Mirrors web's quirk of storing the full JSON turn (not just the
      // reply text) as the "assistant" message in intake history — Claude
      // uses it as its own memory of what's already been collected.
      state = state.copyWith(intakeHistory: [
        ...history,
        {'role': 'assistant', 'content': jsonEncode(data)},
      ]);

      if (done) {
        state = state.copyWith(mode: AssistantMode.assistant);
        final collectedJson = data['collected'];
        if (collectedJson is Map<String, dynamic>) {
          await _createProductFromCollected(_CollectedProduct.fromJson(collectedJson));
        }
      }
    } catch (e) {
      _pushError(apiErrorMessage(e));
      state = state.copyWith(mode: AssistantMode.assistant);
    }
  }

  Future<void> _sendZoneIntakeTurn(List<Map<String, String>> history) async {
    try {
      final response = await _api.postDeliveryZoneAiIntake(history);

      if (!response.success) {
        _pushError(response.error?.message ??
            'Something went wrong — you can add the delivery zone from the Delivery Zones screen instead.');
        state = state.copyWith(mode: AssistantMode.assistant);
        return;
      }

      var data = response.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic> && data['reply'] == null) {
        data = data['data'];
      }
      if (data is! Map<String, dynamic>) {
        _pushError('The assistant returned an unexpected response.');
        state = state.copyWith(mode: AssistantMode.assistant);
        return;
      }

      final reply = (data['reply'] as String?)?.trim() ?? '';
      final done = data['done'] == true;

      if (reply.isNotEmpty) {
        _pushMessage(AssistantMessage(role: 'assistant', text: reply));
      }
      state = state.copyWith(zoneIntakeHistory: [
        ...history,
        {'role': 'assistant', 'content': jsonEncode(data)},
      ]);

      if (done) {
        state = state.copyWith(mode: AssistantMode.assistant);
        final collectedJson = data['collected'];
        if (collectedJson is Map<String, dynamic>) {
          await _createZoneFromCollected(_CollectedZone.fromJson(collectedJson));
        }
      }
    } catch (e) {
      _pushError(apiErrorMessage(e));
      state = state.copyWith(mode: AssistantMode.assistant);
    }
  }

  Future<void> _createZoneFromCollected(_CollectedZone collected) async {
    if (collected.name == null || collected.name!.trim().isEmpty || collected.price == null || collected.locations.isEmpty) {
      _pushMessage(const AssistantMessage(
        role: 'assistant',
        text: "I didn't end up with enough details to create the delivery zone — you can finish it from the Delivery Zones screen.",
        isError: true,
      ));
      return;
    }

    try {
      final response = await _api.createDeliveryZone({
        'name': collected.name,
        'price': collected.price,
        'locations': collected.locations,
      });

      if (!response.success) {
        _pushMessage(AssistantMessage(
          role: 'assistant',
          text: 'I collected the details, but creating the zone failed: '
              '${response.error?.message ?? 'please try again from the Delivery Zones screen.'}',
          isError: true,
        ));
        return;
      }

      _pushMessage(AssistantMessage(
        role: 'assistant',
        text: 'Done — the "${collected.name}" delivery zone has been created.',
      ));
    } catch (e) {
      _pushMessage(AssistantMessage(
        role: 'assistant',
        text: 'I collected the details, but creating the zone failed: ${apiErrorMessage(e)}',
        isError: true,
      ));
    }
  }

  Future<String?> _resolveCategoryId(String? categoryName) async {
    if (categoryName == null || categoryName.trim().isEmpty) return null;
    try {
      final response = await _api.getCategories();
      if (!response.success) return null;
      var data = response.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
        data = data['data'];
      }
      final categories = (data is Map<String, dynamic> ? data['categories'] : null) as List?;
      if (categories == null) return null;
      for (final c in categories) {
        if (c is Map && (c['name'] as String?)?.toLowerCase() == categoryName.toLowerCase()) {
          return c['id'] as String?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _createProductFromCollected(_CollectedProduct collected) async {
    if (collected.name == null || collected.name!.trim().isEmpty || collected.price == null) {
      _pushMessage(const AssistantMessage(
        role: 'assistant',
        text: "I didn't end up with enough details to create the product — you can finish it from the Products tab.",
        isError: true,
      ));
      return;
    }

    final categoryId = await _resolveCategoryId(collected.category);
    // Category is required to save a product (user-requested change) - the
    // AI intake prompt is instructed to always resolve one and never
    // finish without it, but never trust that blindly: if resolution
    // genuinely failed here, fail fast with a clear message instead of
    // letting the save attempt below surface a generic server error.
    if (categoryId == null) {
      final category = collected.category;
      _pushMessage(AssistantMessage(
        role: 'assistant',
        text: category != null && category.trim().isNotEmpty
            ? 'I couldn\'t match "$category" to one of your existing categories — please finish adding this product from the Products tab and pick a category there.'
            : "I need a category to save this product, but didn't get one — please finish adding it from the Products tab.",
        isError: true,
      ));
      return;
    }

    try {
      final requiresShipping = collected.requiresShipping != false;
      final response = await _api.createProduct({
        'name': collected.name,
        'price': collected.price,
        // A non-shipped item (service) has no stock tracked at all — null,
        // not 0 (0 would read as "out of stock" at checkout, see
        // docs/SERVICES_PLAN.md).
        'stock_quantity': requiresShipping ? (collected.stockQuantity ?? 0) : null,
        if (collected.sku != null && collected.sku!.trim().isNotEmpty) 'sku': collected.sku,
        'category_id': categoryId,
        'requires_shipping': requiresShipping,
      });

      if (!response.success) {
        _pushMessage(AssistantMessage(
          role: 'assistant',
          text: 'I collected the details, but creating the product failed: '
              '${response.error?.message ?? 'please try again from the Products tab.'}',
          isError: true,
        ));
        return;
      }

      var data = response.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
        data = data['data'];
      }
      final product = data is Map<String, dynamic> ? data['product'] as Map<String, dynamic>? : null;
      final sku = product?['sku'] as String?;

      _pushMessage(AssistantMessage(
        role: 'assistant',
        text: 'Done — "${collected.name}" has been added to your products.'
            '${sku != null ? ' Want to add a photo?' : ''}',
        nextSteps: sku != null
            ? [
                {'id': 'photo', 'cta': 'Add a photo', 'href': '/products/edit/$sku'},
              ]
            : const [],
      ));
    } catch (e) {
      _pushMessage(AssistantMessage(
        role: 'assistant',
        text: 'I collected the details, but creating the product failed: ${apiErrorMessage(e)}',
        isError: true,
      ));
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic innerData, String key) {
    if (innerData is! Map<String, dynamic>) return const [];
    final list = innerData[key];
    if (list is! List) return const [];
    return list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  void _pushError(String message) {
    _pushMessage(AssistantMessage(role: 'assistant', text: message, isError: true));
  }
}

final assistantChatProvider =
    StateNotifierProvider.autoDispose<AssistantChatNotifier, AssistantChatState>((ref) {
  final api = ref.read(apiClientProvider);
  return AssistantChatNotifier(api, ref);
});
