/// Normalizes referral input for `referrerSubdomain` on store registration.
///
/// Accepts raw subdomains, `?ref=` links, or `/ref/{code}` paths.
/// Rules match server: lowercase `a-z0-9-`, 3–63 chars.
String? parseReferrerSubdomainInput(String raw) {
  var input = raw.trim();
  if (input.isEmpty) return null;

  final uri = Uri.tryParse(input);
  if (uri != null && uri.hasScheme) {
    final refQuery = uri.queryParameters['ref']?.trim();
    if (refQuery != null && refQuery.isNotEmpty) {
      input = refQuery;
    } else {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final refIdx = segments.indexOf('ref');
      if (refIdx >= 0 && refIdx + 1 < segments.length) {
        input = segments[refIdx + 1];
      } else if (segments.isNotEmpty) {
        input = segments.last;
      }
    }
  }

  input = input.toLowerCase();
  input = input.replaceAll(RegExp(r'^@+'), '');
  if (input.length < 3 || input.length > 63) return null;
  if (!RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?$').hasMatch(input)) {
    return null;
  }
  return input;
}
