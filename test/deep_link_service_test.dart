// test/deep_link_service_test.dart
//
// App-side deep link (spec Decision 7 & 9).
//
// The QR encodes `https://tavo.abwabdigital.com/menu/<slug>`. When Tavo is
// installed the OS hands that URL to the app, which resolves the slug to a
// restaurant id and opens the restaurant's details screen. When Tavo is not
// installed the browser shows the same public menu page.
//
// Every test here runs against a fake [DeepLinkSource] and a fake slug
// resolver, so neither a platform channel nor the network is ever touched.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/navigation/deep_link_service.dart';
import 'package:tavo/core/navigation/deep_link_target.dart';

const String _menuUrl =
    'https://tavo.abwabdigital.com/menu/sultan-fish-house';

/// Stands in for `app_links` so the tests never touch a platform channel.
class _FakeLinkSource implements DeepLinkSource {
  _FakeLinkSource({this.initialLink, this.linksDuringStartup = const []});

  /// The link that launched the app.
  Uri? initialLink;

  /// Links the platform delivers on the stream *while* the app is starting
  /// up — some platforms hand the launch link to both channels.
  final List<Uri> linksDuringStartup;

  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async {
    for (final link in linksDuringStartup) {
      _controller.add(link);
    }
    return initialLink;
  }

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  /// Simulates a link that arrives while the app is already running.
  void emit(Uri uri) => _controller.add(uri);

  Future<void> close() => _controller.close();
}

void main() {
  group('DeepLinkService.parse', () {
    test('maps the public menu URL to a slug target', () {
      final target = DeepLinkService.parse(_menuUrl);

      expect(target, isA<RestaurantSlugTarget>());
      expect(target?.slug, 'sultan-fish-house');
      expect(target?.restaurantId, isNull);
    });

    test('tolerates a query string and a fragment', () {
      final target = DeepLinkService.parse(
        'https://tavo.abwabdigital.com/menu/sultan-fish-house?lang=ar#top',
      );

      expect(target, isA<RestaurantSlugTarget>());
      expect(target?.slug, 'sultan-fish-house');
    });

    test('maps the custom scheme to a restaurant id target', () {
      final target = DeepLinkService.parse(
        'tavo://restaurant/6a9e23a52204c506123063ec',
      );

      expect(target, isA<RestaurantDetailsTarget>());
      expect(target?.restaurantId, '6a9e23a52204c506123063ec');
      expect(target?.slug, isNull);
    });

    test('maps the custom scheme with an empty authority to an id target', () {
      final target = DeepLinkService.parse(
        'tavo:///restaurant/6a9e23a52204c506123063ec',
      );

      expect(target, isA<RestaurantDetailsTarget>());
      expect(target?.restaurantId, '6a9e23a52204c506123063ec');
    });

    test('ignores an unknown path on the allowed host', () {
      expect(
        DeepLinkService.parse('https://tavo.abwabdigital.com/some/other/page'),
        DeepLinkTarget.none,
      );
    });

    test('ignores a foreign host', () {
      expect(
        DeepLinkService.parse('https://evil.example.com/menu/x'),
        DeepLinkTarget.none,
      );
    });

    test('ignores a look-alike host with the allowed host as a prefix', () {
      expect(
        DeepLinkService.parse('https://tavo.abwabdigital.com.evil.com/menu/x'),
        DeepLinkTarget.none,
      );
    });

    test('ignores a look-alike host with the allowed host as a suffix', () {
      expect(
        DeepLinkService.parse('https://not-tavo.abwabdigital.com/menu/x'),
        DeepLinkTarget.none,
      );
    });

    test('ignores the allowed host smuggled into the user info', () {
      expect(
        DeepLinkService.parse('https://tavo.abwabdigital.com@evil.com/menu/x'),
        DeepLinkTarget.none,
      );
    });

    test('ignores an explicit port', () {
      expect(
        DeepLinkService.parse('https://tavo.abwabdigital.com:8443/menu/x'),
        DeepLinkTarget.none,
      );
    });

    test('ignores an empty slug', () {
      expect(
        DeepLinkService.parse('https://tavo.abwabdigital.com/menu/'),
        DeepLinkTarget.none,
      );
    });

    test('ignores plain http — only https and the custom scheme are allowed',
        () {
      expect(
        DeepLinkService.parse('http://tavo.abwabdigital.com/menu/x'),
        DeepLinkTarget.none,
      );
    });

    test('ignores an unknown scheme', () {
      expect(
        DeepLinkService.parse('ftp://tavo.abwabdigital.com/menu/x'),
        DeepLinkTarget.none,
      );
    });

    test('ignores a malformed uri without throwing', () {
      expect(DeepLinkService.parse('http://[::1'), DeepLinkTarget.none);
      expect(DeepLinkService.parse(''), DeepLinkTarget.none);
      expect(DeepLinkService.parse('not a uri'), DeepLinkTarget.none);
    });

    test('accepts the allowed host whatever its case', () {
      final target = DeepLinkService.parse(
        'https://TAVO.ABWABDIGITAL.COM/menu/sultan-fish-house',
      );

      expect(target?.slug, 'sultan-fish-house');
    });
  });

  group('DeepLinkService', () {
    test('replays the cold-start link exactly once', () async {
      final source = _FakeLinkSource(initialLink: Uri.parse(_menuUrl));
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) async => 'restaurant-1',
      );
      final targets = <DeepLinkTarget>[];
      final subscription = service.targets.listen(targets.add);

      await service.init();
      await pumpEventQueue();

      expect(targets, [DeepLinkTarget.restaurantDetails('restaurant-1')]);

      await subscription.cancel();
      service.dispose();
    });

    test('init() twice does not replay the cold-start link again', () async {
      final source = _FakeLinkSource(initialLink: Uri.parse(_menuUrl));
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) async => 'restaurant-1',
      );
      final targets = <DeepLinkTarget>[];
      final subscription = service.targets.listen(targets.add);

      await service.init();
      await service.init();
      await pumpEventQueue();

      expect(targets.length, 1);

      await subscription.cancel();
      service.dispose();
    });

    test('replays a link delivered on both channels exactly once', () async {
      final source = _FakeLinkSource(
        initialLink: Uri.parse(_menuUrl),
        linksDuringStartup: [Uri.parse(_menuUrl)],
      );
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) async => 'restaurant-1',
      );
      final targets = <DeepLinkTarget>[];
      final subscription = service.targets.listen(targets.add);

      await service.init();
      await pumpEventQueue();

      expect(targets, [DeepLinkTarget.restaurantDetails('restaurant-1')]);

      await subscription.cancel();
      service.dispose();
    });

    test('delivers the cold-start link to a listener that attaches late',
        () async {
      final source = _FakeLinkSource(initialLink: Uri.parse(_menuUrl));
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) async => 'restaurant-1',
      );

      await service.init();

      final target = await service.targets.first
          .timeout(const Duration(seconds: 5));

      expect(target, DeepLinkTarget.restaurantDetails('restaurant-1'));

      service.dispose();
    });

    test('routes a warm link from the stream', () async {
      final source = _FakeLinkSource();
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) async => 'restaurant-2',
      );
      final targets = <DeepLinkTarget>[];
      final subscription = service.targets.listen(targets.add);

      await service.init();

      source.emit(Uri.parse('tavo://restaurant/6a9e23a52204c506123063ec'));
      await pumpEventQueue();

      expect(targets, [DeepLinkTarget.restaurantDetails('6a9e23a52204c506123063ec')]);

      await subscription.cancel();
      service.dispose();
    });

    test('resolves a warm slug link to a restaurant id', () async {
      final source = _FakeLinkSource();
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) async {
          expect(slug, 'sultan-fish-house');
          return 'restaurant-3';
        },
      );
      final targets = <DeepLinkTarget>[];
      final subscription = service.targets.listen(targets.add);

      await service.init();

      source.emit(Uri.parse(_menuUrl));
      await pumpEventQueue();

      expect(targets, [DeepLinkTarget.restaurantDetails('restaurant-3')]);

      await subscription.cancel();
      service.dispose();
    });

    test('emits the none target when the slug cannot be resolved', () async {
      final source = _FakeLinkSource(initialLink: Uri.parse(_menuUrl));
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) async => null,
      );
      final targets = <DeepLinkTarget>[];
      final subscription = service.targets.listen(targets.add);

      await service.init();
      await pumpEventQueue();

      expect(targets, [DeepLinkTarget.none]);

      await subscription.cancel();
      service.dispose();
    });

    test('emits the none target when the resolver throws', () async {
      final source = _FakeLinkSource(initialLink: Uri.parse(_menuUrl));
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) async => throw Exception('network down'),
      );
      final targets = <DeepLinkTarget>[];
      var streamErrors = 0;
      final subscription = service.targets.listen(
        targets.add,
        onError: (Object _) => streamErrors++,
      );

      await service.init();
      await pumpEventQueue();

      expect(targets, [DeepLinkTarget.none]);
      expect(streamErrors, 0);

      await subscription.cancel();
      service.dispose();
    });

    test('emits the none target when the resolver never completes', () async {
      final source = _FakeLinkSource(initialLink: Uri.parse(_menuUrl));
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) => Completer<String?>().future,
        resolveTimeout: const Duration(milliseconds: 50),
      );

      await service.init();

      final target = await service.targets.first
          .timeout(const Duration(seconds: 5));

      expect(target, DeepLinkTarget.none);

      service.dispose();
    });

    test('emits the none target for an unknown host', () async {
      final source = _FakeLinkSource();
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) async => 'restaurant-4',
      );
      final targets = <DeepLinkTarget>[];
      final subscription = service.targets.listen(targets.add);

      await service.init();

      source.emit(Uri.parse('https://evil.example.com/menu/x'));
      await pumpEventQueue();

      expect(targets, [DeepLinkTarget.none]);

      await subscription.cancel();
      service.dispose();
    });

    test('reports the unresolved link so the caller can fall back to the web '
        'page', () async {
      final source = _FakeLinkSource(initialLink: Uri.parse(_menuUrl));
      final unresolved = <Uri>[];
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) async => null,
        onUnresolvedLink: unresolved.add,
      );
      final subscription = service.targets.listen((_) {});

      await service.init();
      await pumpEventQueue();

      expect(unresolved.map((uri) => uri.toString()), [_menuUrl]);

      await subscription.cancel();
      service.dispose();
    });

    test('reports the same unresolved link only once', () async {
      final source = _FakeLinkSource();
      final unresolved = <Uri>[];
      final targets = <DeepLinkTarget>[];
      final service = DeepLinkService(
        source: source,
        resolveSlug: (slug) async => null,
        onUnresolvedLink: unresolved.add,
      );
      final subscription = service.targets.listen(targets.add);

      await service.init();

      source.emit(Uri.parse(_menuUrl));
      await pumpEventQueue();
      source.emit(Uri.parse(_menuUrl));
      await pumpEventQueue();

      expect(targets, [DeepLinkTarget.none, DeepLinkTarget.none]);
      expect(unresolved.length, 1);

      await subscription.cancel();
      service.dispose();
    });
  });
}
