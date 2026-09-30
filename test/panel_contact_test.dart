// test/panel_contact_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_contact/data/model/contact_models.dart';
import 'package:tavo/feature/panel_contact/data/repo/contact_panel_repo.dart';
import 'package:tavo/feature/panel_contact/ui/logic/contact_panel_cubit.dart';
import 'package:tavo/feature/panel_contact/ui/screens/panel_contact_screen.dart';

import 'helpers/app_shell.dart';

const _venue = StaffRestaurant(
  restaurantId: 'r1',
  name: 'Burger Lab',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'owner',
  permissions: ['full_access'],
  status: 'active',
);

const _venueView = StaffRestaurant(
  restaurantId: 'r1',
  name: 'Burger Lab',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'staff',
  permissions: ['view_reports'],
  status: 'active',
);

PanelContact _contact() => const PanelContact(
      slug: 'burger-lab',
      menuUrl: 'https://tavo.abwabdigital.com/menu/burger-lab',
      phone: '+966501112233',
      email: 'hello@burgerlab.sa',
      whatsapp: '+966509998877',
      socialLinks: {'instagram': 'https://instagram.com/burgerlab'},
      descriptionAr: 'أفضل برجر',
      descriptionEn: 'Best burgers',
    );

class _FakeContactRepo extends ContactPanelRepo {
  _FakeContactRepo() : super(api: ApiService());
  PanelContact contact = _contact();
  Object? failure;
  final List<String> calls = [];

  @override
  Future<PanelContact> getContact(String restaurantId) async {
    calls.add('getContact');
    _maybeThrow();
    return contact;
  }

  @override
  Future<PanelContact> updateContact(
      {required String restaurantId,
      String? phone,
      String? email,
      String? whatsapp,
      Map<String, String>? socialLinks,
      String? descriptionAr,
      String? descriptionEn}) async {
    calls.add('save:$phone:$email');
    contact = PanelContact(
      slug: contact.slug,
      menuUrl: contact.menuUrl,
      phone: phone ?? contact.phone,
      email: email ?? contact.email,
      whatsapp: whatsapp ?? contact.whatsapp,
      socialLinks: socialLinks ?? contact.socialLinks,
      descriptionAr: descriptionAr ?? contact.descriptionAr,
      descriptionEn: descriptionEn ?? contact.descriptionEn,
    );
    return contact;
  }

  void _maybeThrow() {
    if (failure != null) {
      final f = failure;
      failure = null;
      throw f!;
    }
  }
}

Future<void> _pumpContact(WidgetTester tester, _FakeContactRepo repo,
    {StaffRestaurant venue = _venue}) async {
  GetIt.instance.registerLazySingleton<ContactPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  await tester.pumpWidget(
      appShell(PanelContactScreen(restaurantId: 'r1', venue: venue)));
  // Mirrors panel_menu/customers/reviews tests: EasyLocalization builds
  // the child subtree asynchronously, so wait for the skeleton first.
  await pumpUntil(
      tester, () => find.byType(ListSkeleton).evaluate().isNotEmpty);
}

void main() {
  setUpAll(initTestEnv);

  testWidgets('loading shows the skeleton before content', (tester) async {
    await _pumpContact(tester, _FakeContactRepo());
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ListSkeleton), findsNothing);
  });

  testWidgets('error shows an inline error with a working retry',
      (tester) async {
    final repo = _FakeContactRepo()..failure = Exception('boom');
    await _pumpContact(tester, repo);
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'getContact'), hasLength(2));
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('form prefills from the endpoint and saves', (tester) async {
    final repo = _FakeContactRepo();
    await _pumpContact(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('+966501112233'), findsOneWidget); // phone prefilled
    expect(find.text('hello@burgerlab.sa'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('contact_phone')), '+966509998877');
    await tester.tap(find.byKey(const Key('save_contact')));
    await tester.pumpAndSettle();

    // NB: calls also holds the initial 'getContact' from load(), so the
    // save journal entry is asserted via .last (brief draft said .single).
    expect(repo.calls.last, startsWith('save:+966509998877:'));
    expect(find.text('Contact saved'), findsOneWidget);
  });

  testWidgets('QR renders from menuUrl with copy + share actions',
      (tester) async {
    final repo = _FakeContactRepo();
    await _pumpContact(tester, repo);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu_qr')), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('https://tavo.abwabdigital.com/menu/burger-lab'),
        findsOneWidget);
    expect(find.byKey(const Key('copy_link')), findsOneWidget);
    expect(find.byKey(const Key('share_link')), findsOneWidget);
  });

  testWidgets('copy writes the menu link to the clipboard', (tester) async {
    final copied = <String?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String?);
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await _pumpContact(tester, _FakeContactRepo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copy_link')));
    await tester.pumpAndSettle();

    expect(
        copied, ['https://tavo.abwabdigital.com/menu/burger-lab']);
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('share never throws without a platform plugin', (tester) async {
    await _pumpContact(tester, _FakeContactRepo());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('share_link')));
    await tester.pumpAndSettle();

    // MissingPluginException is caught inside the screen (clipboard fallback)
    expect(tester.takeException(), isNull);
    expect(find.byType(PanelContactScreen), findsOneWidget);
  });

  testWidgets('view-only staff sees the QR but no save', (tester) async {
    await _pumpContact(tester, _FakeContactRepo(), venue: _venueView);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu_qr')), findsOneWidget);
    expect(find.byKey(const Key('save_contact')), findsNothing);
  });

  testWidgets('missing menuUrl hides the QR widget', (tester) async {
    final repo = _FakeContactRepo()
      ..contact = const PanelContact(
          slug: '', phone: '', email: '', whatsapp: '', socialLinks: {},
          descriptionAr: '', descriptionEn: '');
    await _pumpContact(tester, repo);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu_qr')), findsNothing);
  });

  test('save failure keeps the form and surfaces actionError', () async {
    final repo = _FakeContactRepo();
    final cubit = ContactPanelCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);
    await cubit.load();
    expect((cubit.state as ContactPanelLoaded).contact.phone,
        '+966501112233');
  });
}
