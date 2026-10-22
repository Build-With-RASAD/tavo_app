// test/motion_system_test.dart
import 'dart:ui' show FragmentProgram;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/animation/motion.dart';
import 'package:tavo/core/animation/motion_tokens.dart';
import 'package:tavo/core/animation/primitives/spring_counter.dart';
import 'package:tavo/core/animation/primitives/spring_press.dart';
import 'package:tavo/core/animation/primitives/spring_reveal.dart';
import 'package:tavo/core/animation/primitives/spring_sheet.dart';
import 'package:tavo/core/animation/shaders/shader_painters.dart';
import 'package:tavo/core/animation/shaders/shader_program_loader.dart';
import 'package:tavo/core/theme/motion_theme_extension.dart';

/// Hosts [child] inside a MaterialApp, optionally with reduced motion on.
Widget _host(
  Widget child, {
  bool disableAnimations = false,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: Builder(
      builder: (BuildContext context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: child,
        );
      },
    ),
  );
}

/// The scale currently applied by the enclosing [SpringPress].
double _pressScale(WidgetTester tester) {
  final Transform transform = tester.widget(
    find.descendant(
      of: find.byType(SpringPress),
      matching: find.byType(Transform),
    ),
  );
  return transform.transform.storage[0];
}

/// The opacity currently applied to the [index]-th revealed child.
double _revealOpacity(WidgetTester tester, int index) {
  final FadeTransition transition = tester.widget(
    find
        .descendant(
          of: find.byType(SpringReveal),
          matching: find.byType(FadeTransition),
        )
        .at(index),
  );
  return transition.opacity.value;
}

/// The transform currently applied by the enclosing [SpringSheet].
Matrix4 _sheetMatrix(WidgetTester tester) {
  final Transform transform = tester.widget(
    find.descendant(
      of: find.byType(SpringSheet),
      matching: find.byType(Transform),
    ),
  );
  return transform.transform;
}

/// Records the paths a loader was asked for and never returns a program.
class _RecordingLoader implements ShaderProgramLoader {
  final List<String> requestedPaths = <String>[];

  @override
  Future<FragmentProgram?> load(String assetPath) async {
    requestedPaths.add(assetPath);
    return null;
  }
}

void main() {
  group('motion tokens', () {
    test('AppDurations exposes the four duration tokens', () {
      expect(AppDurations.fast, const Duration(milliseconds: 150));
      expect(AppDurations.normal, const Duration(milliseconds: 250));
      expect(AppDurations.slow, const Duration(milliseconds: 400));
      expect(AppDurations.hero, const Duration(milliseconds: 500));
    });

    test('AppCurves exposes the three curve tokens', () {
      expect(AppCurves.easeOut, Curves.easeOutCubic);
      expect(AppCurves.easeIn, Curves.easeInCubic);
      expect(AppCurves.emphasized, const Cubic(0.2, 0.0, 0.0, 1.0));
    });

    test('AppSprings exposes the three spring tokens', () {
      expect(AppSprings.snappy.mass, 1);
      expect(AppSprings.snappy.stiffness, 520);
      expect(AppSprings.snappy.damping, 30);
      expect(AppSprings.gentle.mass, 1);
      expect(AppSprings.gentle.stiffness, 220);
      expect(AppSprings.gentle.damping, 24);
      expect(AppSprings.bouncy.mass, 1);
      expect(AppSprings.bouncy.stiffness, 400);
      expect(AppSprings.bouncy.damping, 16);
    });
  });

  group('Motion', () {
    testWidgets('isReduced mirrors MediaQuery.disableAnimations',
        (WidgetTester tester) async {
      bool? reducedWithAnimations;
      bool? reducedWithoutAnimations;

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              reducedWithAnimations = Motion.isReduced(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(reducedWithAnimations, isFalse);

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              reducedWithoutAnimations = Motion.isReduced(context);
              return const SizedBox.shrink();
            },
          ),
          disableAnimations: true,
        ),
      );
      expect(reducedWithoutAnimations, isTrue);
    });

    testWidgets('adapt collapses the duration to zero under reduced motion',
        (WidgetTester tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
          disableAnimations: true,
        ),
      );
      expect(Motion.adapt(capturedContext, AppDurations.slow), Duration.zero);

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(Motion.adapt(capturedContext, AppDurations.slow), AppDurations.slow);
    });

    testWidgets('springFor returns the no-motion spring under reduced motion',
        (WidgetTester tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
          disableAnimations: true,
        ),
      );
      expect(
        Motion.springFor(capturedContext, AppSprings.snappy).stiffness,
        AppSprings.noSpring.stiffness,
      );
      expect(
        Motion.springFor(capturedContext, AppSprings.snappy).damping,
        AppSprings.noSpring.damping,
      );
      expect(
        Motion.springFor(capturedContext, AppSprings.snappy).mass,
        AppSprings.noSpring.mass,
      );

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        Motion.springFor(capturedContext, AppSprings.snappy).stiffness,
        AppSprings.snappy.stiffness,
      );
      expect(
        Motion.springFor(capturedContext, AppSprings.snappy).damping,
        AppSprings.snappy.damping,
      );
      expect(
        Motion.springFor(capturedContext, AppSprings.snappy).mass,
        AppSprings.snappy.mass,
      );
    });
  });

  group('MotionTheme', () {
    testWidgets('of returns the theme extension when one is registered',
        (WidgetTester tester) async {
      late MotionTheme captured;

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              captured = MotionTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[
              MotionTheme(revealSpring: AppSprings.bouncy),
            ],
          ),
        ),
      );
      expect(captured.revealSpring.stiffness, AppSprings.bouncy.stiffness);
      expect(captured.pressSpring.stiffness, AppSprings.snappy.stiffness);
    });

    testWidgets('of falls back to the default tokens when none is registered',
        (WidgetTester tester) async {
      late MotionTheme captured;

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              captured = MotionTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured.revealSpring.stiffness, AppSprings.gentle.stiffness);
      expect(captured.pressSpring.stiffness, AppSprings.snappy.stiffness);
    });

    test('copyWith overrides a single token and lerp blends two themes', () {
      const MotionTheme base = MotionTheme();
      final MotionTheme copy = base.copyWith(revealSpring: AppSprings.bouncy);
      expect(copy.revealSpring.stiffness, AppSprings.bouncy.stiffness);
      expect(copy.pressSpring.stiffness, AppSprings.snappy.stiffness);

      final MotionTheme blended = base.lerp(
        const MotionTheme(revealSpring: AppSprings.bouncy),
        0.5,
      );
      expect(blended.revealSpring.stiffness,
          (AppSprings.gentle.stiffness + AppSprings.bouncy.stiffness) / 2);
    });
  });

  group('SpringPress', () {
    testWidgets('scales down while pressed and springs back on release',
        (WidgetTester tester) async {
      int taps = 0;

      await tester.pumpWidget(
        _host(
          SpringPress(
            onTap: () => taps++,
            child: const SizedBox(
              key: ValueKey<String>('press-target'),
              width: 120,
              height: 60,
            ),
          ),
        ),
      );
      expect(_pressScale(tester), 1.0);

      final Offset center = tester.getCenter(
        find.byKey(const ValueKey<String>('press-target')),
      );
      final TestGesture gesture = await tester.startGesture(center);
      // The first frame after the gesture starts the spring with an elapsed
      // time of zero, the second frame is the first one that moved.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(_pressScale(tester), lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_pressScale(tester), 1.0);
      expect(taps, 1);
    });

    testWidgets('is a no-op under reduced motion',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const SpringPress(
            child: SizedBox(
              key: ValueKey<String>('press-target'),
              width: 120,
              height: 60,
            ),
          ),
          disableAnimations: true,
        ),
      );

      final Offset center = tester.getCenter(
        find.byKey(const ValueKey<String>('press-target')),
      );
      final TestGesture gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_pressScale(tester), 1.0);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_pressScale(tester), 1.0);
    });

    testWidgets('animates the transform only, never the layout',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const SpringPress(
            child: SizedBox(
              key: ValueKey<String>('press-target'),
              width: 120,
              height: 60,
            ),
          ),
        ),
      );
      final Size before = tester.getSize(
        find.byKey(const ValueKey<String>('press-target')),
      );

      final Offset center = tester.getCenter(
        find.byKey(const ValueKey<String>('press-target')),
      );
      final TestGesture gesture = await tester.startGesture(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      // A layout animation would resize or move the child.
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('press-target'))),
        before,
      );
      expect(_pressScale(tester), isNot(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('SpringCounter', () {
    testWidgets('settles on the target inside the hero budget',
        (WidgetTester tester) async {
      double? observed;

      await tester.pumpWidget(
        _host(
          SpringCounter(
            value: 1250,
            from: 0,
            builder: (BuildContext context, double value) {
              observed = value;
              return Text('$value');
            },
          ),
        ),
      );

      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        AppDurations.hero * 2,
      );
      expect(observed, closeTo(1250, 0.001));
    });

    testWidgets('jumps straight to the target under reduced motion',
        (WidgetTester tester) async {
      double? observed;

      await tester.pumpWidget(
        _host(
          SpringCounter(
            value: 1250,
            from: 0,
            builder: (BuildContext context, double value) {
              observed = value;
              return Text('$value');
            },
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(observed, 1250);
    });
  });

  group('SpringReveal', () {
    const List<Widget> revealChildren = <Widget>[
      SizedBox(key: ValueKey<String>('reveal-0'), width: 40, height: 20),
      SizedBox(key: ValueKey<String>('reveal-1'), width: 40, height: 20),
      SizedBox(key: ValueKey<String>('reveal-2'), width: 40, height: 20),
    ];

    testWidgets('reveals the children one after the other',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const SpringReveal(
            itemDelay: Duration(milliseconds: 400),
            children: revealChildren,
          ),
        ),
      );

      // The first frame after the delay starts the spring with an elapsed
      // time of zero, the second frame is the first one that moved.
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_revealOpacity(tester, 0), greaterThan(0.0));
      expect(_revealOpacity(tester, 1), 0.0);
      expect(_revealOpacity(tester, 2), 0.0);

      await tester.pumpAndSettle();
      expect(_revealOpacity(tester, 0), 1.0);
      expect(_revealOpacity(tester, 1), 1.0);
      expect(_revealOpacity(tester, 2), 1.0);
    });

    testWidgets('shows every child immediately under reduced motion',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const SpringReveal(children: revealChildren),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(_revealOpacity(tester, 0), 1.0);
      expect(_revealOpacity(tester, 1), 1.0);
      expect(_revealOpacity(tester, 2), 1.0);
    });
  });

  group('SpringSheet', () {
    testWidgets('settles on the identity transform',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const SpringSheet(
            child: SizedBox(
              key: ValueKey<String>('sheet-target'),
              width: 200,
              height: 120,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final Matrix4 matrix = _sheetMatrix(tester);
      expect(matrix.getTranslation().x, 0.0);
      expect(matrix.getTranslation().y, 0.0);
      expect(matrix.getMaxScaleOnAxis(), 1.0);
    });

    testWidgets('is at the final transform immediately under reduced motion',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const SpringSheet(
            child: SizedBox(
              key: ValueKey<String>('sheet-target'),
              width: 200,
              height: 120,
            ),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      final Matrix4 matrix = _sheetMatrix(tester);
      expect(matrix.getTranslation().x, 0.0);
      expect(matrix.getTranslation().y, 0.0);
      expect(matrix.getMaxScaleOnAxis(), 1.0);
    });
  });

  group('shaders', () {
    test('the painters degrade to a plain fill without a program', () {
      const Size size = Size(120, 60);
      final List<({CustomPainter painter, Color color})> painters =
          <({CustomPainter painter, Color color})>[
        (
          painter: const GooeyPainter(color: Color(0xff102040)),
          color: const Color(0xff102040),
        ),
        (
          painter: const LiquidPainter(color: Color(0xff203040)),
          color: const Color(0xff203040),
        ),
        (
          painter: const AuroraPainter(color: Color(0xff304050)),
          color: const Color(0xff304050),
        ),
      ];

      for (final ({CustomPainter painter, Color color}) entry in painters) {
        final TestRecordingCanvas canvas = TestRecordingCanvas();
        entry.painter.paint(canvas, size);

        expect(canvas.invocations, isNotEmpty);
        final RecordedInvocation invocation = canvas.invocations.first;
        expect(invocation.invocation.memberName, #drawRect);
        expect(
          invocation.invocation.positionalArguments[0],
          Offset.zero & size,
        );
        final Paint paint =
            invocation.invocation.positionalArguments[1] as Paint;
        expect(paint.color.toARGB32(), entry.color.toARGB32());
        expect(paint.shader, isNull);
      }
    });

    test('the asset loader degrades to null when the program is missing',
        () async {
      final FragmentProgram? program =
          await const AssetShaderProgramLoader().load('missing/program.frag');
      expect(program, isNull);
    });

    testWidgets('a surface renders through an injected loader',
        (WidgetTester tester) async {
      final _RecordingLoader loader = _RecordingLoader();

      await tester.pumpWidget(
        _host(
          ShaderProgramLoaderScope(
            loader: loader,
            child: const GooeySurface(),
          ),
        ),
      );
      // The shader surface runs a looping clock, so it never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));

      expect(loader.requestedPaths, contains(kGooeyShaderAsset));
      expect(tester.takeException(), isNull);
      expect(find.byType(GooeySurface), findsOneWidget);
    });
  });

  group('disposal', () {
    testWidgets('every primitive releases its controller when removed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: <Widget>[
              const SpringPress(
                child: SizedBox(key: ValueKey<String>('press'), width: 40, height: 20),
              ),
              const SpringReveal(
                children: <Widget>[
                  SizedBox(key: ValueKey<String>('reveal'), width: 40, height: 20),
                ],
              ),
              SpringCounter(
                value: 10,
                builder: (BuildContext context, double value) => Text('$value'),
              ),
              const SpringSheet(
                child: SizedBox(key: ValueKey<String>('sheet'), width: 40, height: 20),
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(_host(const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });
}
