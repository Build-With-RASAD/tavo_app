// test/async_state_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';

import 'helpers/app_shell.dart';

void main() {
  setUpAll(initTestEnv);

  testWidgets('ListSkeleton renders placeholder cards', (tester) async {
    await tester.pumpWidget(appShell(const Scaffold(body: ListSkeleton())));
    // appShell's ScreenUtilInit/EasyLocalization init leaves the subtree
    // unpumped on the first frame — settle before asserting (controller ruling).
    await tester.pumpAndSettle();
    expect(find.byType(ListSkeleton), findsOneWidget);
    expect(
      tester.widgetList(find.byType(SizedBox)).length,
      greaterThan(2),
      reason: 'placeholder blocks are SizedBoxes',
    );
  });

  testWidgets('EmptyStateView shows title, message and retry when given',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(appShell(Scaffold(
      body: EmptyStateView(
        icon: Icons.inbox_outlined,
        title: 'No orders yet',
        message: 'New orders will appear here',
        onRetry: () => tapped = true,
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.text('New orders will appear here'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(tapped, isTrue);
  });

  testWidgets('ErrorStateView surfaces the message and retries',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(appShell(Scaffold(
      body: ErrorStateView(
        message: 'No internet connection',
        onRetry: () => retried = true,
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('No internet connection'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
