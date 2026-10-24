// lib/core/navigation/deep_link_service.dart
//
// App-side half of the QR deep link (spec Decisions 7 and 9).
//
// The QR encodes `https://tavo.abwabdigital.com/menu/<slug>` — a real web
// URL that is already live. When Tavo is installed the OS hands that URL to
// the app, which resolves the slug to a restaurant id and opens the
// restaurant's details screen. When Tavo is not installed the browser shows
// the same public menu page and none of this runs.
//
// `tavo://restaurant/<id>` is the belt-and-braces custom scheme (Android
// without verified App Links, and the web page's "Open in Tavo" CTA).
//
// The parser ([DeepLinkService.parse]) is pure and total — no I/O, never
// throws — so it is unit testable on its own. The service owns the cold
// start replay and the slug resolution.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/navigation/deep_link_target.dart';

/// Resolves a public menu slug to a restaurant id.
///
/// Returns `null` when the slug is unknown. The service treats a `null`
/// result *and* a thrown error as "could not resolve" and falls back to the
/// web page, so an implementation never has to handle its own failures.
typedef DeepLinkSlugResolver = Future<String?> Function(String slug);

/// The slice of `app_links` the service needs.
///
/// Injectable so the tests never touch a platform channel.
abstract interface class DeepLinkSource {
  /// The link that launched the app (cold start), or `null` when the app was
  /// opened normally.
  Future<Uri?> getInitialLink();

  /// The links that arrive while the app is running.
  Stream<Uri> get uriLinkStream;
}

/// [DeepLinkSource] backed by `app_links`.
class AppLinksDeepLinkSource implements DeepLinkSource {
  AppLinksDeepLinkSource([AppLinks? appLinks])
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}

/// Parses incoming links and turns them into actions for the app.
class DeepLinkService {
  DeepLinkService({
    DeepLinkSource? source,
    DeepLinkSlugResolver? resolveSlug,
    this.onUnresolvedLink,
    this.resolveTimeout = defaultResolveTimeout,
  }) : _source = source ?? AppLinksDeepLinkSource(),
       _resolveSlug = resolveSlug ?? resolveSlugByApi;

  /// How long the service waits for a slug to resolve before it gives up and
  /// falls back to the web page.
  static const Duration defaultResolveTimeout = Duration(seconds: 15);

  /// Called with the original link when its slug could not be resolved, so
  /// the app can fall back to the public web page.
  final void Function(Uri uri)? onUnresolvedLink;

  /// How long the service waits for a slug to resolve.
  final Duration resolveTimeout;

  final DeepLinkSource _source;
  final DeepLinkSlugResolver _resolveSlug;

  late final StreamController<DeepLinkTarget> _targets =
      StreamController<DeepLinkTarget>.broadcast(
        onListen: () {
          _hasListener = true;
          _drainBuffer();
        },
        onCancel: () => _hasListener = false,
      );

  /// Targets emitted before anything listened — the cold-start link can be
  /// resolved before the app root has mounted.
  final List<DeepLinkTarget> _buffer = [];

  /// Links that arrive while [init] is still starting up.
  final List<Uri> _startupLinks = [];

  StreamSubscription<Uri>? _subscription;
  bool _hasListener = false;
  bool _initialized = false;
  bool _startingUp = false;
  bool _disposed = false;
  Uri? _launchedLink;
  String? _reportedUnresolvedLink;

  /// The actions the app should take. A target is emitted for every link
  /// that arrives, including [DeepLinkTarget.none] for links the app cannot
  /// act on.
  Stream<DeepLinkTarget> get targets => _targets.stream;

  /// Starts listening for links and replays the link that launched the app.
  ///
  /// Safe to call more than once — the launch link is replayed exactly once.
  Future<void> init() async {
    if (_initialized || _disposed) return;
    _initialized = true;

    _subscription = _source.uriLinkStream.listen(
      _onStreamLink,
      onError: (Object _) {
        // A platform failure must never take the app down.
      },
    );

    _startingUp = true;
    try {
      final initial = await _source.getInitialLink();
      _launchedLink = initial;
      if (initial != null) await _handleLink(initial);
    } catch (_) {
      // A platform failure must never take the app down.
    } finally {
      _startingUp = false;
    }

    await _drainStartupLinks();
  }

  /// Releases the platform subscription. Safe to call more than once.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());

    unawaited(_targets.close());

    _buffer.clear();
    _startupLinks.clear();
  }

  /// Parses [uri] into the action it asks for.
  ///
  /// Pure and total: it never throws and returns [DeepLinkTarget.none] for
  /// anything unrecognised. Only `https` on the app's own host and the
  /// `tavo` custom scheme are accepted; the host has to match exactly, so a
  /// look-alike such as `tavo.abwabdigital.com.evil.com` is ignored.
  static DeepLinkTarget? parse(String uri) {
    try {
      final parsed = Uri.tryParse(uri);
      if (parsed == null) return DeepLinkTarget.none;

      final scheme = parsed.scheme.toLowerCase();
      if (scheme == _httpsScheme) return _parseWebLink(parsed);
      if (scheme == _customScheme) return _parseCustomLink(parsed);
      return DeepLinkTarget.none;
    } catch (_) {
      return DeepLinkTarget.none;
    }
  }

  /// The default slug resolver — `GET /v1/api/public/restaurant/:slug`.
  ///
  /// The service lookup happens inside the call, not at construction time,
  /// so a link that arrives before the app's DI is ready cannot crash it.
  static Future<String?> resolveSlugByApi(String slug) async {
    final response = await _apiService().get(publicRestaurantPath(slug));

    final body = response.data;
    if (body is! Map) return null;
    if (body['success'] != true) return null;

    final data = body['data'];
    if (data is! Map) return null;

    final id = data['_id'];
    if (id is! String || id.isEmpty) return null;
    return id;
  }

  /// Path of the public slug endpoint (Task 30-A).
  static String publicRestaurantPath(String slug) =>
      '/v1/api/public/restaurant/$slug';

  static ApiService _apiService() {
    if (GetIt.I.isRegistered<ApiService>()) return GetIt.I<ApiService>();
    return ApiService();
  }

  static DeepLinkTarget _parseWebLink(Uri uri) {
    if (uri.userInfo.isNotEmpty) return DeepLinkTarget.none;
    if (uri.hasPort) return DeepLinkTarget.none;
    if (uri.host.toLowerCase() != _allowedHost) return DeepLinkTarget.none;

    final segments = _segments(uri.pathSegments);
    if (segments.length != 2) return DeepLinkTarget.none;

    final section = segments.first.toLowerCase();
    if (section == _tableSegment) {
      final token = segments.last;
      if (!_tableTokenPattern.hasMatch(token)) return DeepLinkTarget.none;
      return DeepLinkTarget.tableSession(token);
    }

    if (section != _menuSegment) {
      return DeepLinkTarget.none;
    }
    return DeepLinkTarget.restaurantDetailsFromSlug(segments.last);
  }

  static DeepLinkTarget _parseCustomLink(Uri uri) {
    final segments = _segments([
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ]);
    if (segments.length != 2) return DeepLinkTarget.none;
    if (segments.first.toLowerCase() != _restaurantSegment) {
      return DeepLinkTarget.none;
    }
    return DeepLinkTarget.restaurantDetails(segments.last);
  }

  static List<String> _segments(List<String> raw) =>
      raw.where((segment) => segment.isNotEmpty).toList();

  void _onStreamLink(Uri uri) {
    if (_disposed) return;
    if (_startingUp) {
      _startupLinks.add(uri);
      return;
    }
    unawaited(_handleLink(uri));
  }

  Future<void> _handleLink(Uri uri) async {
    if (_disposed) return;

    final target = parse(uri.toString());
    if (target == null) {
      _emit(DeepLinkTarget.none);
      return;
    }

    switch (target) {
      case RestaurantSlugTarget(:final slug):
        final restaurantId = await _resolve(slug);
        if (restaurantId == null) {
          _emit(DeepLinkTarget.none);
          _reportUnresolved(uri);
        } else {
          _emit(DeepLinkTarget.restaurantDetails(restaurantId));
        }
      case RestaurantDetailsTarget():
        _emit(target);
      default:
        _emit(DeepLinkTarget.none);
    }
  }

  /// Reports a link whose slug could not be resolved — once per link.
  ///
  /// Re-opening the same web page would send the user straight back into the
  /// app (App Links resolve to the app), so the fallback is reported once.
  void _reportUnresolved(Uri uri) {
    final link = uri.toString();
    if (link == _reportedUnresolvedLink) return;
    _reportedUnresolvedLink = link;
    onUnresolvedLink?.call(uri);
  }

  Future<String?> _resolve(String slug) async {
    try {
      final restaurantId = await _resolveSlug(slug).timeout(resolveTimeout);
      if (restaurantId == null) return null;
      final trimmed = restaurantId.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      return null;
    }
  }

  /// Hands the links that arrived during startup to [handleLink], skipping
  /// the one that already launched the app so it is replayed exactly once.
  Future<void> _drainStartupLinks() async {
    if (_startupLinks.isEmpty) return;

    final links = List<Uri>.from(_startupLinks);
    _startupLinks.clear();

    for (final link in links) {
      final launched = _launchedLink;
      if (launched != null && link.toString() == launched.toString()) continue;
      await _handleLink(link);
    }
  }

  void _emit(DeepLinkTarget target) {
    if (_disposed) return;
    if (!_hasListener) {
      _buffer.add(target);
      return;
    }
    _targets.add(target);
  }

  void _drainBuffer() {
    if (_buffer.isEmpty) return;

    final buffered = List<DeepLinkTarget>.from(_buffer);
    _buffer.clear();
    for (final target in buffered) {
      _targets.add(target);
    }
  }
}

const String _httpsScheme = 'https';
const String _customScheme = 'tavo';
const String _menuSegment = 'menu';
const String _tableSegment = 't';
const String _restaurantSegment = 'restaurant';

/// A printed table token: URL-safe, long enough to be unguessable. Matches the
/// backend's 24-byte base64url tokens and rejects the `/t/` web page spelling
/// (`/t/5`) that the marketing site uses for its demo.
final RegExp _tableTokenPattern = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

/// The only host the app answers to — derived from the API base URL so the
/// allow-list and the API can never drift apart.
final String _allowedHost = _hostOf(ApiConstants.baseUrl);

String _hostOf(String url) {
  try {
    return Uri.tryParse(url)?.host.toLowerCase() ?? '';
  } catch (_) {
    return '';
  }
}
