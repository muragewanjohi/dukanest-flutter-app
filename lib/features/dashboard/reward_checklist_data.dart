/// Pure parsing/derivation helpers for the onboarding reward checklist.
///
/// Free of Flutter imports so the rules can be unit-tested in isolation; the
/// widget ([RewardChecklistCard]) delegates to these.
library;

/// A single checklist step row.
typedef RewardStep = ({
  String title,
  String subtitle,
  bool done,
  String stepId,
  String href,
  String actionLabel,
});

/// Truthy across the various shapes the backend uses for booleans/status.
bool rewardBool(dynamic v) =>
    v == true ||
    v == 1 ||
    v == '1' ||
    v == 'true' ||
    v == 'completed' ||
    v == 'done';

/// Extracts the `reward` sub-map from the checklist payload, if present.
Map<String, dynamic>? rewardMap(Map<String, dynamic>? data) {
  if (data == null) return null;
  final r = data['reward'];
  if (r is! Map) return null;
  return Map<String, dynamic>.from(r);
}

/// Parses the `items`/`steps`/`checklist`/`tasks` array into display rows.
List<RewardStep> rewardSteps(Map<String, dynamic> data) {
  final raw =
      data['items'] ?? data['steps'] ?? data['checklist'] ?? data['tasks'];
  if (raw is! List) return const [];
  final out = <RewardStep>[];
  for (final e in raw.whereType<Map>()) {
    final m = Map<String, dynamic>.from(e);
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    final rawKey = pick(['id', 'key', 'stepKey', 'step', 'step_id']);
    final title = pick(['label', 'title', 'name']);
    final displayTitle =
        title.isNotEmpty ? title : (rawKey.isNotEmpty ? rawKey : '');
    if (displayTitle.isEmpty) continue;
    final done = rewardBool(m['completed'] ??
        m['done'] ??
        m['complete'] ??
        m['isComplete'] ??
        m['isCompleted'] ??
        m['status']);
    final cta = pick(['cta', 'actionLabel', 'action_label', 'buttonText']);
    out.add((
      title: humanizeRewardKey(displayTitle),
      subtitle: pick(['description', 'hint', 'subtitle', 'helpText']),
      done: done,
      stepId: rawKey.isNotEmpty ? rawKey : displayTitle,
      href: pick(['href', 'link', 'path', 'route', 'deepLink', 'deep_link']),
      actionLabel: cta.isEmpty ? 'Continue' : cta,
    ));
  }
  return out;
}

/// Turns a snake/camel/kebab key into a human-friendly title.
String humanizeRewardKey(String key) {
  if (key.contains(' ')) return key;
  final spaced = key
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim();
  if (spaced.isEmpty) return key;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// Whether a reward checklist step id refers to product attributes.
bool isAttributesRewardStepId(String stepId) {
  final k = stepId.trim().toLowerCase().replaceAll('-', '_');
  if (k.isEmpty) return false;
  if (k == 'attributes' || k == 'attribute' || k == 'product_attributes') {
    return true;
  }
  return k.contains('attribute');
}

RewardStep defaultAttributesRewardStep({bool done = false}) {
  return (
    title: 'Add product attributes',
    subtitle: 'Create options like Size, Weight, and Colour for products.',
    done: done,
    stepId: 'attributes',
    href: '/attributes/new',
    actionLabel: 'Add attribute',
  );
}

/// Ensures the attributes step appears in the onboarding reward carousel
/// (moved off Getting Started). Uses API item completion when present.
List<RewardStep> ensureAttributesRewardStep(
  List<RewardStep> steps,
  Map<String, dynamic> data,
) {
  if (steps.any((s) => isAttributesRewardStepId(s.stepId))) {
    return steps;
  }

  var done = false;
  final raw =
      data['items'] ?? data['steps'] ?? data['checklist'] ?? data['tasks'];
  if (raw is List) {
    for (final e in raw.whereType<Map>()) {
      final m = Map<String, dynamic>.from(e);
      final id = (m['id'] ?? m['key'] ?? m['stepKey'] ?? m['step_id'] ?? '')
          .toString();
      if (!isAttributesRewardStepId(id)) continue;
      done = rewardBool(m['completed'] ??
          m['done'] ??
          m['complete'] ??
          m['isComplete'] ??
          m['isCompleted'] ??
          m['status']);
      break;
    }
  }

  final attributesStep = defaultAttributesRewardStep(done: done);
  final categoryIndex = steps.indexWhere((s) {
    final k = s.stepId.toLowerCase().replaceAll('-', '_');
    return k == 'categories_two' ||
        k == 'category' ||
        k == 'categories' ||
        k.contains('categor');
  });
  var insertAt = steps.length;
  if (categoryIndex >= 0) {
    insertAt = categoryIndex + 1;
  } else {
    final productIndex = steps.indexWhere((s) {
      final k = s.stepId.toLowerCase().replaceAll('-', '_');
      return k == 'products_five' || k == 'product' || k == 'products';
    });
    if (productIndex >= 0) {
      insertAt = productIndex + 1;
    }
  }
  final out = List<RewardStep>.from(steps);
  out.insert(insertAt.clamp(0, out.length), attributesStep);
  return out;
}

/// The card is only shown when the reward program is enabled and the store is
/// either eligible or has already been granted the reward.
bool shouldShowReward(Map<String, dynamic>? data) {
  final reward = rewardMap(data);
  if (reward == null) return false;
  if (!rewardBool(reward['enabled'])) return false;
  final eligible = rewardBool(reward['eligible']);
  final granted = rewardBool(reward['granted']);
  return eligible || granted;
}
