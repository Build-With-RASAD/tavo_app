// test/tavo_web_kit_test.dart
//
// Widget tests for the Tavo website design kit. The kit is host-agnostic:
// no ScreenUtil, no localization delegate, no app theme. Each test wraps the
// widget in a plain `MaterialApp` and overrides only the MediaQuery bits the
// kit reads (`disableAnimations`, size, view insets).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';

Widget host(
  Widget child, {
  bool reduceMotion = false,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return MaterialApp(
    builder: (BuildContext context, Widget? appChild) {
      final MediaQueryData data = MediaQuery.of(context);
      return MediaQuery(
        data: data.copyWith(disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: textDirection,
          child: appChild!,
        ),
      );
    },
    home: Scaffold(body: Center(child: child)),
  );
}

Opacity _revealOpacity(WidgetTester tester) {
  return tester.widget<Opacity>(
    find
        .descendant(
          of: find.byType(TavoReveal),
          matching: find.byType(Opacity),
        )
        .first,
  );
}

void main() {
  testWidgets('every button variant renders, shows its icon slot and taps once', (
    WidgetTester tester,
  ) async {
    int taps = 0;

    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TavoButton.primary(
              label: 'Primary',
              leading: const Icon(Iconsax.tick_circle),
              onPressed: () => taps++,
            ),
            TavoButton.secondary(
              label: 'Secondary',
              onPressed: () => taps++,
            ),
            TavoButton.ghost(label: 'Ghost', onPressed: () => taps++),
            TavoButton.destructive(
              label: 'Delete',
              onPressed: () => taps++,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(TavoButton), findsNWidgets(4));
    expect(find.byType(Icon), findsOneWidget);
    for (final Element element in find.byType(TavoButton).evaluate()) {
      final RenderBox box = element.renderObject! as RenderBox;
      expect(box.size.height, greaterThanOrEqualTo(TavoSpace.minTouchTarget));
    }

    for (final String label in <String>[
      'Primary',
      'Secondary',
      'Ghost',
      'Delete',
    ]) {
      await tester.tap(find.text(label));
      await tester.pump(TavoMotion.base);
    }

    expect(taps, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled button blocks taps and dims to 50%', (
    WidgetTester tester,
  ) async {
    int taps = 0;

    await tester.pumpWidget(
      host(TavoButton.primary(label: 'Save', onPressed: null)),
    );

    await tester.tap(find.text('Save'));
    await tester.pump(TavoMotion.base);

    expect(taps, 0);
    final Iterable<Opacity> dims = tester.widgetList<Opacity>(
      find.descendant(
        of: find.byType(TavoButton),
        matching: find.byType(Opacity),
      ),
    );
    expect(dims.any((Opacity opacity) => opacity.opacity == 0.5), isTrue);
  });

  testWidgets('loading button shows progress, blocks taps and announces', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      host(
        TavoButton.primary(
          label: 'Save',
          isLoading: true,
          loadingSemanticsLabel: 'Saving',
          onPressed: () => taps++,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.bySemanticsLabel('Saving'), findsOneWidget);

    await tester.tap(find.byType(TavoButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(taps, 0);

    semantics.dispose();
  });

  testWidgets('stat tile groups thousands and keeps decimals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              TavoStatTile(label: 'ORDERS', value: 1234567),
              TavoStatTile(
                label: 'REVENUE',
                value: 1234.5,
                decimals: 1,
                prefix: 'SAR',
                suffix: 'today',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('1,234,567'), findsOneWidget);
    expect(find.textContaining('SAR 1,234.5'), findsOneWidget);
    expect(find.textContaining('today'), findsOneWidget);
    expect(TavoNumberFormat.grouped(-9876543), '-9,876,543');
    expect(TavoNumberFormat.grouped(0), '0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reveal is a plain child when animations are disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const TavoReveal(index: 4, child: Text('Revealed')),
        reduceMotion: true,
      ),
    );

    expect(find.text('Revealed'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TavoReveal),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(TavoReveal),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });

  testWidgets('reveal fades and rises, and caps the stagger at eight items', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(const TavoReveal(child: Text('First'))),
    );
    expect(_revealOpacity(tester).opacity, 0);
    await tester.pump(TavoMotion.reveal);
    await tester.pump(const Duration(milliseconds: 20));
    expect(_revealOpacity(tester).opacity, 1);

    await tester.pumpWidget(
      host(
        const TavoReveal(
          key: ValueKey<String>('late'),
          index: 12,
          child: Text('Late'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(_revealOpacity(tester).opacity, 0);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(TavoMotion.reveal + const Duration(milliseconds: 20));
    expect(_revealOpacity(tester).opacity, 1);
  });

  testWidgets('press scale shrinks while held without stealing the tap', (
    WidgetTester tester,
  ) async {
    int taps = 0;

    await tester.pumpWidget(
      host(
        TavoPressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 120, height: 48),
          ),
        ),
      ),
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(TavoPressScale)),
    );
    await tester.pump();
    await tester.pump(TavoMotion.fast);

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      TavoMotion.pressScale,
    );

    await gesture.up();
    await tester.pump();
    await tester.pump(TavoMotion.fast);

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(taps, 1);
  });

  testWidgets('status pills cover every tone and chips tap', (
    WidgetTester tester,
  ) async {
    bool tapped = false;

    await tester.pumpWidget(
      host(
        SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Wrap(
                spacing: TavoSpace.sm,
                runSpacing: TavoSpace.sm,
                children: <Widget>[
                  for (final TavoTone tone in TavoTone.values)
                    TavoStatusPill(label: tone.name, tone: tone),
                ],
              ),
              const SizedBox(height: TavoSpace.md),
              Wrap(
                spacing: TavoSpace.sm,
                runSpacing: TavoSpace.sm,
                children: <Widget>[
                  const TavoChip(label: 'All', selected: true),
                  TavoChip(label: 'Open', onTap: () => tapped = true),
                  const TavoChip(
                    label: 'Terrace',
                    variant: TavoChipVariant.gold,
                  ),
                  const TavoChip(
                    label: 'Trending',
                    variant: TavoChipVariant.glass,
                    leading: Icon(Iconsax.trend_up),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    for (final TavoTone tone in TavoTone.values) {
      expect(find.text(tone.name), findsOneWidget);
    }

    await tester.tap(find.text('Open'));
    await tester.pump(TavoMotion.base);
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('composed card renders in LTR and mirrors without overflow', (
    WidgetTester tester,
  ) async {
    Widget card() {
      return SizedBox(
        width: 320,
        child: TavoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const TavoSectionHeader(
                title: 'Tonight',
                subtitle: 'Service 18:00 – 23:00',
                action: TavoStatusPill(
                  label: 'Live',
                  tone: TavoTone.success,
                  size: TavoPillSize.small,
                ),
              ),
              const SizedBox(height: TavoSpace.lg),
              const TavoStatTile(
                label: 'COVERS',
                value: 42,
                suffix: 'booked',
              ),
              const SizedBox(height: TavoSpace.md),
              Row(
                children: <Widget>[
                  const TavoIconTile(icon: Icon(Iconsax.clock)),
                  const SizedBox(width: TavoSpace.md),
                  Expanded(
                    child: Text(
                      'Next slot 19:30',
                      style: TavoType.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(host(card()));
    expect(find.text('Tonight'), findsOneWidget);
    expect(find.text('Next slot 19:30'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(host(card(), textDirection: TextDirection.rtl));
    expect(find.text('Tonight'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet opens with a handle and drags past the threshold to close', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: TavoButton.primary(
                  label: 'Open sheet',
                  onPressed: () => unawaited(
                    TavoSheet.show<void>(
                      context,
                      title: 'Booking',
                      subtitle: 'Table for four',
                      child: const Text('Sheet body'),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Sheet body'), findsOneWidget);
    expect(find.byKey(TavoSheet.handleKey), findsOneWidget);
    expect(find.text('Booking'), findsOneWidget);

    await tester.drag(find.byKey(TavoSheet.handleKey), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(find.text('Sheet body'), findsNothing);
  });
}
