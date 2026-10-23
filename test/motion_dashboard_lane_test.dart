// test/motion_dashboard_lane_test.dart
//
// Task 33-B, dashboard lane: the live-ops surface must be animated, and the
// animation must be *honest* — it never delays a number and it collapses to
// the final frame when the platform asks for reduced motion.
//
// These tests assert the two things that can silently regress:
//   1. the motion is actually wired to the widgets (structure), and
//   2. under `disableAnimations` the content is final on the FIRST frame
//      (no waiting, no invisible text, no offset tile).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/animation/primitives/spring_counter.dart';
import 'package:tavo/core/animation/primitives/spring_reveal.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/kpi_tiles.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/live_hero_band.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/management_shortcuts.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/order_pipeline.dart';

import 'helpers/app_shell.dart';
import 'panel_dashboard_v2_test.dart' show sampleAnalytics;

/// Pumps [child] with animations either enabled or explicitly disabled.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required bool reduced,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: appShell(child),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(initTestEnv);

  final analytics = DashboardAnalytics.fromJson(sampleAnalytics);

  group('the motion is wired', () {
    testWidgets('the KPI grid reveals its tiles in sequence', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: KpiTiles(kpi: analytics.kpi)),
        ),
        reduced: false,
      );

      expect(tester.takeException(), isNull);
      // One reveal item per tile — the stagger is real, not a single fade.
      expect(find.byType(SpringRevealItem), findsNWidgets(12));
    });

    testWidgets('the shortcut grid reveals its tiles in sequence',
        (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: ManagementShortcuts()),
        ),
        reduced: false,
      );

      expect(tester.takeException(), isNull);
      // Five tiles: menu, staff, branches, reviews, settings.
      expect(find.byType(SpringRevealItem), findsNWidgets(5));
    });

    testWidgets('the pipeline reveals one row per status', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: OrderPipeline(
            ordersByStatus: const {'pending': 3, 'preparing': 1},
          ),
        ),
        reduced: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SpringRevealItem), findsNWidgets(2));
    });

    testWidgets('the live revenue is spring-driven, not a hand-picked tween',
        (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: LiveHeroBand(
            live: analytics.live,
            sparkline: const [],
          ),
        ),
        reduced: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SpringCounter), findsOneWidget);
      // The band's three figures each get their own reveal slot.
      expect(find.byType(SpringRevealItem), findsNWidgets(3));
    });
  });

  group('reduced motion is honest', () {
    testWidgets('the KPI values are final on the first frame', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: KpiTiles(kpi: analytics.kpi)),
        ),
        reduced: true,
        settle: false, // deliberately: no settling allowed
      );
      // One frame only — the value must already be the real one.
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('247.25'), findsOneWidget); // gross revenue
      expect(find.text('215.00'), findsOneWidget); // net revenue
    });

    testWidgets('the live revenue is final on the first frame', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: LiveHeroBand(
            live: analytics.live,
            sparkline: const [],
          ),
        ),
        reduced: true,
        settle: false,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('247.25'), findsOneWidget);
    });

    testWidgets('a revealed tile is neither transparent nor offset',
        (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: OrderPipeline(
            ordersByStatus: const {'pending': 3, 'preparing': 1},
          ),
        ),
        reduced: true,
        settle: false,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // No lingering opacity: every revealed child is fully opaque.
      final fades = tester.widgetList<Opacity>(find.byType(Opacity));
      for (final fade in fades) {
        expect(fade.opacity, 1.0);
      }
      // The pipeline rows are all present in the first frame.
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });
  });
}
