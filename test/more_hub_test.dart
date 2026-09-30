import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_screen.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/shell_defaults.dart';

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

class _ProbeScreen extends StatelessWidget {
  const _ProbeScreen({required this.restaurantId});
  final String restaurantId;
  @override
  Widget build(BuildContext context) => Text('probe:$restaurantId');
}

void main() {
  setUpAll(initTestEnv);
  tearDown(MoreHubRegistry.reset);

  testWidgets('empty registry renders the composed empty state', (tester) async {
    await tester.pumpWidget(appShell(
      const MoreHubScreen(restaurantId: 'r1', venue: _venue),
    ));
    // EasyLocalization loads its delegate asynchronously; settle so the
    // hub subtree is built before asserting (same pattern as other suites).
    await tester.pumpAndSettle();
    expect(find.byType(MoreHubScreen), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('registered entries render and push their screen with ids',
      (tester) async {
    MoreHubRegistry.register(MoreHubEntry(
      id: 'probe',
      labelKey: 'tables',
      icon: Icons.table_chart_outlined,
      builder: (restaurantId, venue) => _ProbeScreen(restaurantId: restaurantId),
    ));
    // idempotent: registering twice must not duplicate the tile
    MoreHubRegistry.register(MoreHubEntry(
      id: 'probe',
      labelKey: 'tables',
      icon: Icons.table_chart_outlined,
      builder: (restaurantId, venue) => _ProbeScreen(restaurantId: restaurantId),
    ));

    await tester.pumpWidget(appShell(
      const MoreHubScreen(restaurantId: 'r1', venue: _venue),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tables'), findsOneWidget); // labelKey 'tables' → en.json
    await tester.tap(find.text('Tables'));
    await tester.pumpAndSettle();

    expect(find.text('probe:r1'), findsOneWidget);
  });

  testWidgets(
      'shell defaults register the 8 placeholder tiles and a module replaces its tile by id',
      (tester) async {
    // The 800x600 default test surface fits ~2 hub rows under ScreenUtil
    // scaling, so GridView lazily skips the lower tiles. Grow the surface
    // so all 8 tiles are onstage for the assertions below.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    registerShellDefaults();
    registerShellDefaults(); // absent-only — no duplicate tiles

    expect(MoreHubRegistry.entries, hasLength(8));
    expect(
      MoreHubRegistry.entries.map((e) => e.id).toList(),
      ['menu', 'tables', 'customers', 'staff', 'branches', 'reviews',
       'settings', 'contact'],
    );

    await tester.pumpWidget(appShell(
      const MoreHubScreen(restaurantId: 'r1', venue: _venue),
    ));
    await tester.pumpAndSettle();
    for (final label in const [
      'Menu', 'Tables', 'Customers', 'Staff',
      'Branches', 'Reviews', 'Settings', 'Contact & QR',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // A module registration replaces the placeholder entry for the same id.
    MoreHubRegistry.register(MoreHubEntry(
      id: 'menu',
      labelKey: 'menu',
      icon: Icons.restaurant_menu_outlined,
      builder: (restaurantId, venue) => _ProbeScreen(restaurantId: restaurantId),
    ));
    expect(MoreHubRegistry.entries, hasLength(8));

    // The registry is a plain global store (no notifier), so the already-built
    // hub only picks up the replacement on rebuild — same as production, where
    // module registration runs at DI time before the hub builds.
    await tester.pumpWidget(appShell(
      const MoreHubScreen(restaurantId: 'r1', venue: _venue),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('probe:r1'), findsOneWidget); // module builder wins
  });
}
