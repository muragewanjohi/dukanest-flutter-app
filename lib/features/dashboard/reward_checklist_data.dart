/// Pure parsing/derivation helpers for the onboarding reward checklist.
///
/// Free of Flutter imports so the rules can be unit-tested in isolation; the
/// widget ([RewardChecklistCard]) delegates to these.
library;

/// A single checklist step row.
typedef RewardStep = ({String title, String subtitle, bool done});

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

    final title = pick(['label', 'title', 'name', 'step', 'key']);
    if (title.isEmpty) continue;
    final done = rewardBool(m['completed'] ??
        m['done'] ??
        m['complete'] ??
        m['isComplete'] ??
        m['isCompleted'] ??
        m['status']);
    out.add((
      title: humanizeRewardKey(title),
      subtitle: pick(['description', 'hint', 'subtitle', 'helpText']),
      done: done,
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
