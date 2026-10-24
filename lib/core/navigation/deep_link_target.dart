// lib/core/navigation/deep_link_target.dart

/// What an incoming deep link asks the app to do.
///
/// Sealed so the app root can `switch` over every variant exhaustively:
///
///  * [DeepLinkTarget.none] — nothing actionable. The link came from an
///    unknown host, an unknown path, or a slug that could not be resolved;
///    the caller falls back to the public web page.
///  * [DeepLinkTarget.restaurantDetails] — open a restaurant whose id is
///    already known.
///  * [DeepLinkTarget.restaurantDetailsFromSlug] — open a restaurant the app
///    only knows by its public slug. [DeepLinkService] resolves the slug to
///    an id before the target reaches the UI, so the UI never sees this
///    variant.
sealed class DeepLinkTarget {
  const DeepLinkTarget();

  /// Nothing to open — the caller falls back to the web page.
  static const DeepLinkTarget none = _NoDeepLinkTarget();

  /// A restaurant the app can open directly; the id is already known.
  const factory DeepLinkTarget.restaurantDetails(String restaurantId) =
      RestaurantDetailsTarget;

  /// A restaurant the app only knows by its public slug.
  const factory DeepLinkTarget.restaurantDetailsFromSlug(String slug) =
      RestaurantSlugTarget;

  /// A printed table QR code (`https://<host>/t/<token>`).
  const factory DeepLinkTarget.tableSession(String token) = TableSessionTarget;

  /// The restaurant id, when this target carries one.
  String? get restaurantId => switch (this) {
    RestaurantDetailsTarget target => target.restaurantId,
    _ => null,
  };

  /// The public slug, when this target carries one.
  String? get slug => switch (this) {
    RestaurantSlugTarget target => target.slug,
    _ => null,
  };

  /// The table QR token, when this target carries one.
  String? get tableToken => switch (this) {
    TableSessionTarget target => target.tableToken,
    _ => null,
  };
}

/// The "nothing to open" target.
final class _NoDeepLinkTarget extends DeepLinkTarget {
  const _NoDeepLinkTarget();

  @override
  bool operator ==(Object other) => other is _NoDeepLinkTarget;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'DeepLinkTarget.none';
}

/// A restaurant the app can open directly.
final class RestaurantDetailsTarget extends DeepLinkTarget {
  const RestaurantDetailsTarget(this.restaurantId);

  @override
  final String restaurantId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantDetailsTarget &&
          other.restaurantId == restaurantId;

  @override
  int get hashCode => restaurantId.hashCode;

  @override
  String toString() => 'DeepLinkTarget.restaurantDetails($restaurantId)';
}

/// A restaurant the app only knows by its public slug.
final class RestaurantSlugTarget extends DeepLinkTarget {
  const RestaurantSlugTarget(this.slug);

  @override
  final String slug;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantSlugTarget && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;

  @override
  String toString() => 'DeepLinkTarget.restaurantDetailsFromSlug($slug)';
}

/// A table QR code. The token is the only thing the app needs: the public
/// endpoint resolves it to the restaurant, the table and the open session.
final class TableSessionTarget extends DeepLinkTarget {
  const TableSessionTarget(this.tableToken);

  @override
  final String tableToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableSessionTarget && other.tableToken == tableToken;

  @override
  int get hashCode => tableToken.hashCode;

  @override
  String toString() => 'DeepLinkTarget.tableSession($tableToken)';
}
