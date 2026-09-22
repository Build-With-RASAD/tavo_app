import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/feature/booking/ui/widgets/booking_bottom_sheet.dart';

Future<void> pumpSelector(
  WidgetTester tester, {
  required int value,
  required int min,
  required int max,
  required ValueChanged<int> onChanged,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GuestSelector(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

void main() {
  group('GuestSelector', () {
    testWidgets('displays the current guest count', (tester) async {
      await pumpSelector(
        tester,
        value: 3,
        min: 1,
        max: 5,
        onChanged: (_) {},
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('decrement calls onChanged with value - 1 when above min',
        (tester) async {
      int? changedTo;
      await pumpSelector(
        tester,
        value: 3,
        min: 1,
        max: 5,
        onChanged: (v) => changedTo = v,
      );

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(changedTo, 2);
    });

    testWidgets('decrement is disabled at min', (tester) async {
      var callCount = 0;
      await pumpSelector(
        tester,
        value: 1,
        min: 1,
        max: 5,
        onChanged: (_) => callCount++,
      );

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(callCount, 0);
    });

    testWidgets('increment calls onChanged with value + 1 when below max',
        (tester) async {
      int? changedTo;
      await pumpSelector(
        tester,
        value: 3,
        min: 1,
        max: 5,
        onChanged: (v) => changedTo = v,
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(changedTo, 4);
    });

    testWidgets('increment is disabled at max', (tester) async {
      var callCount = 0;
      await pumpSelector(
        tester,
        value: 5,
        min: 1,
        max: 5,
        onChanged: (_) => callCount++,
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(callCount, 0);
    });
  });
}
