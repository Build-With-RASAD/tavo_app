import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/feature/restaurant/data/model/cart_item_model.dart';
import 'package:tavo/feature/restaurant/data/model/menu_item_model.dart';
import 'package:tavo/feature/restaurant/data/repo/menu_repo.dart';
import 'package:tavo/feature/restaurant/data/repo/order_repo.dart';
import 'package:tavo/feature/restaurant/ui/logic/menu_cubit.dart';
import 'package:tavo/feature/restaurant/ui/logic/order_cubit.dart';
import 'package:tavo/feature/restaurant/ui/screens/restaurant_menu_screen.dart';

import 'helpers/app_shell.dart';

/// Regression test for the dead "Book your seat" button on the menu screen:
/// `onPressed` was an empty closure, so a cart built on the menu screen
/// could never be submitted. The button must sync the [MenuCubit] cart into
/// the [OrderCubit] (shared with the details screen) and place the order.
MenuItemModel _item() => MenuItemModel(
      id: 'm1',
      titleAr: 'برجر',
      titleEn: 'Burger',
      descriptionAr: '',
      descriptionEn: 'Tasty burger',
      price: 25,
      imageUrl: '',
      categoryId: 'c1',
    );

class FakeMenuCubit extends MenuCubit {
  FakeMenuCubit({required String restaurantId})
      : super(getIt<MenuRepo>(), restaurantId: restaurantId);

  @override
  Future<void> loadMenu() async {
    if (isClosed) return;
    emit(state.copyWith(
      loading: false,
      error: null,
      items: [_item()],
      cart: {'m1': 2},
    ));
  }
}

class FakeOrderCubit extends OrderCubit {
  FakeOrderCubit() : super(getIt<OrderRepo>(), restaurantId: 'r1');

  int placeOrderCalls = 0;
  List<CartItemModel> capturedItems = const [];

  @override
  Future<void> placeOrder() async {
    placeOrderCalls++;
    capturedItems = List.of(state.cartItems);
  }
}

void main() {
  setUpAll(() async {
    await initTestEnv();
    await initServiceLocator();
    if (getIt.isRegistered<MenuCubit>()) {
      await getIt.unregister<MenuCubit>();
    }
    getIt.registerFactoryParam<MenuCubit, String, void>(
      (restaurantId, _) => FakeMenuCubit(restaurantId: restaurantId),
    );
  });

  testWidgets(
      'menu "Book your seat" syncs the menu cart into the order and submits it',
      (tester) async {
    final fakeOrder = FakeOrderCubit();

    await tester.pumpWidget(appShell(
      BlocProvider<OrderCubit>.value(
        value: fakeOrder,
        child: const RestaurantMenuScreen(restaurantId: 'r1'),
      ),
    ));
    await tester.pumpAndSettle();
    await pumpUntil(tester,
        () => find.text('Book your seat').evaluate().isNotEmpty);

    // Cart has 2 units of m1, so the bottom bar (and button) is visible.
    expect(find.text('Book your seat'), findsOneWidget);

    await tester.tap(find.text('Book your seat'));
    await tester.pump();

    expect(fakeOrder.placeOrderCalls, 1,
        reason: 'the menu screen must submit the cart instead of ignoring '
            'the tap (onPressed was an empty closure)');
    expect(fakeOrder.capturedItems, isNotEmpty);
    expect(fakeOrder.capturedItems.first.menuItemId, 'm1');
    expect(fakeOrder.capturedItems.first.quantity, 2,
        reason: 'the full menu cart quantity must be carried over');

    await tester.pumpWidget(const SizedBox());
  });
}
