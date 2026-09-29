import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tavo/core/constants/app_assets.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/theme/theme_extensions.dart';
import 'package:tavo/feature/restaurant/ui/logic/menu_cubit.dart';
import 'package:tavo/feature/restaurant/ui/logic/menu_state.dart';
import 'package:tavo/feature/restaurant/ui/logic/order_cubit.dart';
import 'package:tavo/feature/restaurant/ui/screens/meal_customization_screen.dart';
import 'package:tavo/feature/restaurant/ui/widgets/bottom_booking_bar.dart';
import 'package:tavo/feature/restaurant/ui/widgets/menu_item_card.dart';

class RestaurantMenuScreen extends StatelessWidget {
  final String restaurantId;

  const RestaurantMenuScreen({
    super.key,
    required this.restaurantId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<MenuCubit>(param1: restaurantId)..loadMenu(),
      child: const _RestaurantMenuView(),
    );
  }
}

class _RestaurantMenuView extends StatelessWidget {
  const _RestaurantMenuView();

  List<BottomCartLine> _mapCartLines(MenuState state) {
    final lines = <BottomCartLine>[];
    for (final item in state.items) {
      final q = state.cart[item.id] ?? 0;
      if (q > 0) {
        lines.add(BottomCartLine(id: item.id, imageUrl: item.imageUrl, qty: q));
      }
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final orderSubmitting = context.watch<OrderCubit>().state.submitting;

    return BlocBuilder<MenuCubit, MenuState>(
      builder: (context, state) {
        final cubit = context.read<MenuCubit>();
        final cartLines = _mapCartLines(state);
        final showBottomBar = state.hasItemsInCart;

        return Scaffold(
          backgroundColor: ColorsManager.white,
          body: SafeArea(
            bottom: !showBottomBar,
            child: Column(
              children: [
                _buildHeader(context, state),
                if (state.categories.isNotEmpty)
                  _buildCategoriesRow(context, state, cubit, locale),
                SizedBox(height: 12.h),
                Expanded(
                  child: _buildContent(context, state, cubit, locale),
                ),
              ],
            ),
          ),
          bottomNavigationBar: showBottomBar
              ? BottomBookingBar(
                  onPressed: orderSubmitting
                      ? null
                      : () {
                          // Sync the menu cart into the OrderCubit that the
                          // details screen shares with this screen (via
                          // BlocProvider.value), then submit. The details
                          // screen's success listener opens the order
                          // success sheet, which leads to the booking sheet.
                          final orderCubit = context.read<OrderCubit>();
                          state.cart.forEach((itemId, qty) {
                            final item = state.items
                                .where((m) => m.id == itemId)
                                .firstOrNull;
                            if (item == null) return;
                            for (var i = 0; i < qty; i++) {
                              orderCubit.addSimpleItem(
                                menuItemId: itemId,
                                name: item.getTitle(locale),
                                imageUrl: item.imageUrl,
                                price: item.price,
                              );
                            }
                          });
                          orderCubit.placeOrder();
                        },
                  buttonTextKey: 'book_your_seat',
                  total: state.total,
                  cartLines: cartLines,
                  onAddItem: cubit.add,
                  onRemoveItem: cubit.remove,
                )
              : null,
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, MenuState state) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40.r,
              height: 40.r,
              decoration: const BoxDecoration(
                color: ColorsManager.grey100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.arrowRight,
                  width: 16.r,
                  height: 16.r,
                  colorFilter: const ColorFilter.mode(ColorsManager.black, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            'menu'.tr(),
            style: TextStyles.font16Black500Weight(context).copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (state.hasItemsInCart)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: ColorsManager.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 16.r, color: ColorsManager.primaryColor),
                  SizedBox(width: 4.w),
                  Text(
                    '${state.totalCartItems}',
                    style: TextStyle(
                      color: ColorsManager.primaryColor,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesRow(BuildContext context, MenuState state, MenuCubit cubit, String locale) {
    return Padding(
      padding: EdgeInsets.only(top: 14.h),
      child: SizedBox(
        height: 38.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: state.categories.length + 1,
          separatorBuilder: (_, __) => SizedBox(width: 8.w),
          itemBuilder: (_, i) {
            if (i == 0) {
              return _CategoryChip(
                text: 'all'.tr(),
                selected: state.selectedCategoryId == null,
                count: state.items.length,
                onTap: () => cubit.selectCategory(null),
              );
            }
            final category = state.categories[i - 1];
            final isSelected = state.selectedCategoryId == category.id;
            final count = state.items.where((item) => item.categoryId == category.id).length;
            return _CategoryChip(
              text: category.getName(locale),
              selected: isSelected,
              count: count,
              onTap: () => cubit.selectCategory(category.id),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, MenuState state, MenuCubit cubit, String locale) {
    if (state.loading) {
      return const Center(
        child: CircularProgressIndicator.adaptive(backgroundColor: ColorsManager.primaryColor),
      );
    }

    if (state.error != null) {
      return _buildErrorWidget(context, state.error!, cubit);
    }

    if (state.filteredItems.isEmpty) {
      return _buildEmptyWidget(context);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >= notification.metrics.maxScrollExtent - 100) {
          cubit.loadMoreItems();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => cubit.refresh(),
        color: ColorsManager.primaryColor,
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, state.hasItemsInCart ? 120.h : 20.h),
          itemCount: state.filteredItems.length + (state.loadingMore ? 1 : 0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (_, i) {
            if (i >= state.filteredItems.length) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: const CircularProgressIndicator.adaptive(
                    backgroundColor: ColorsManager.primaryColor,
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            final item = state.filteredItems[i];
            return MenuItemCard(
              item: item,
              locale: locale,
              qty: state.qty(item.id),
              onAdd: () {
                cubit.add(item.id);
                try {
                  context.read<OrderCubit>().addSimpleItem(
                        menuItemId: item.id,
                        name: item.getTitle(locale),
                        imageUrl: item.imageUrl,
                        price: item.price,
                      );
                } catch (_) {}
              },
              onRemove: () {
                cubit.remove(item.id);
                try {
                  context.read<OrderCubit>().removeFromCart(item.id);
                } catch (_) {}
              },
              onCustomize: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) {
                      try {
                        return BlocProvider.value(
                          value: context.read<OrderCubit>(),
                          child: MealCustomizationScreen(
                            restaurantId: cubit.restaurantId,
                            menuItemId: item.id,
                          ),
                        );
                      } catch (_) {
                        return MealCustomizationScreen(
                          restaurantId: cubit.restaurantId,
                          menuItemId: item.id,
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String error, MenuCubit cubit) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.r,
              height: 80.r,
              decoration: BoxDecoration(color: ColorsManager.grey100, shape: BoxShape.circle),
              child: Icon(Icons.error_outline, size: 40.r, color: ColorsManager.darkGray300),
            ),
            SizedBox(height: 20.h),
            Text(error, textAlign: TextAlign.center, style: TextStyles.font14DarkGray400Weight(context)),
            SizedBox(height: 24.h),
            SizedBox(
              height: 44.h,
              child: ElevatedButton(
                onPressed: () => cubit.loadMenu(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsManager.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
                ),
                child: Text('retry'.tr(), style: const TextStyle(color: ColorsManager.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.r,
              height: 80.r,
              decoration: BoxDecoration(color: ColorsManager.grey100, shape: BoxShape.circle),
              child: Icon(Icons.restaurant_menu, size: 40.r, color: ColorsManager.darkGray300),
            ),
            SizedBox(height: 20.h),
            Text(
              'no_menu_items'.tr(),
              textAlign: TextAlign.center,
              style: TextStyles.font14DarkGray400Weight(context).copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),
            Text(
              'no_items_in_category'.tr(),
              textAlign: TextAlign.center,
              style: TextStyles.font12DarkGray400Weight(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String text;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.text,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? ColorsManager.secondaryColor : ColorsManager.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? ColorsManager.secondaryColor : context.borderColor,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: ColorsManager.secondaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              text,
              style: TextStyles.font12DarkGray400Weight(context).copyWith(
                color: selected ? ColorsManager.white : ColorsManager.black,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: selected ? ColorsManager.white.withOpacity(0.2) : ColorsManager.grey100,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? ColorsManager.white : ColorsManager.darkGray300,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}