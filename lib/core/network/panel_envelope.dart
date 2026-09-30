// lib/core/network/panel_envelope.dart
//
// Unwrapping helpers for the two panel response shapes:
//   nested page  {success, data: {data: [...], pagination: {...}}}
//   flat list    {success, data: [...]}
//   object       {success, data: {...}}
// Module repos call [panelPayload] first, then [panelUnwrapList] when the
// endpoint is paginated. Shared so every new module reads envelopes the same
// way instead of re-implementing `_payloadOf`/`_unwrapList` per repo.

/// Safe `Map<String, dynamic>` cast — JSON decoders hand back `Map<String, dynamic>`
/// but tests often build `Map<String, Object?>` literals.
Map<String, dynamic>? panelAsMap(dynamic value) =>
    value is Map<String, dynamic> ? value : null;

/// `response.data['data']` — the payload every panel envelope wraps.
dynamic panelPayload(dynamic data) => panelAsMap(data)?['data'];

/// Unwraps a paginated payload; accepts both envelope shapes.
({List<dynamic> items, Map<String, dynamic>? pagination})
    panelUnwrapList(dynamic payload) {
  if (payload is List) return (items: payload, pagination: null);
  final map = panelAsMap(payload);
  final inner = map?['data'];
  if (inner is List) {
    return (items: inner, pagination: panelAsMap(map?['pagination']));
  }
  return (items: const [], pagination: null);
}
