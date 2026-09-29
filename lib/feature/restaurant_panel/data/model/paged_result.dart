/// One page of a paginated panel list response.
///
/// Constructed by `RestaurantPanelRepo` from the paged envelope returned by
/// the panel endpoints (`items`/`data` plus `page`/`limit`/`total`/`pages`).
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int pages;

  /// Whether a page after this one exists (`page < pages`).
  bool get hasNext => page < pages;
}
