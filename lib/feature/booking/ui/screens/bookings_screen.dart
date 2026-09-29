// lib/feature/booking/ui/screens/bookings_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/helpers/utils/short_id.dart';
import 'package:tavo/core/localization/locale_keys.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
import 'package:tavo/feature/booking/data/model/booking_status.dart';
import 'package:tavo/feature/booking/ui/logic/bookings_cubit.dart';
import 'package:tavo/feature/booking/ui/logic/bookings_state.dart';
import 'package:tavo/feature/booking/ui/widgets/booking_card.dart';
import 'package:tavo/feature/booking/ui/widgets/booking_details_sheet.dart';
import 'package:tavo/feature/booking/ui/widgets/order_details_loading_sheet.dart';
import 'package:tavo/feature/Profile/ui/widgets/profile_widgets.dart';

class BookingsScreen extends StatefulWidget {
  final bool showAppBar;

  const BookingsScreen({super.key, this.showAppBar = true});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Whether the details loading sheet is currently presented. The details
  /// listener must only pop when it is — otherwise (sheet already dismissed
  /// by the user) the pop removes the screen itself.
  bool _loadingSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<BookingsCubit>()..loadBookings(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (widget.showAppBar) ...[
                SizedBox(height: 10.h),
                AnimatedAppBar(title: LocaleKeys.bookings.tr()),
                SizedBox(height: 16.h),
              ],
              _buildTabs(context),
              SizedBox(height: 14.h),
              Expanded(
                child: BlocConsumer<BookingsCubit, BookingsState>(
                  listener: (context, state) {
                    if (state.selectedBooking != null) {
                      if (_loadingSheetOpen) {
                        Navigator.of(context).pop();
                        _loadingSheetOpen = false;
                      }
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => BookingDetailsSheet(
                          booking: state.selectedBooking!,
                          order: state.orderDetails,
                        ),
                      );
                      context.read<BookingsCubit>().clearDetails();
                    }

                    if (state.detailsError != null) {
                      if (_loadingSheetOpen) {
                        Navigator.of(context).pop();
                        _loadingSheetOpen = false;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.detailsError!),
                          backgroundColor: const Color(0xFFC62828),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          margin: EdgeInsets.all(16.w),
                        ),
                      );
                      context.read<BookingsCubit>().clearDetails();
                    }
                  },
                  builder: (context, state) {
                    if (state.loading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: ColorsManager.primaryColor,
                        ),
                      );
                    }

                    if (state.error != null) {
                      return _buildErrorWidget(context, state.error!);
                    }

                    final locale = context.locale.languageCode;

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _BookingsList(
                          items: state.filterBy(BookingStatus.inProgress),
                          locale: locale,
                          onRefresh: () =>
                              context.read<BookingsCubit>().refresh(),
                          onDetails: (id) => _onViewDetails(context, id),
                        ),
                        _BookingsList(
                          items: state.filterBy(BookingStatus.completed),
                          locale: locale,
                          onRefresh: () =>
                              context.read<BookingsCubit>().refresh(),
                          onDetails: (id) => _onViewDetails(context, id),
                        ),
                        _BookingsList(
                          items: state.filterBy(BookingStatus.cancelled),
                          locale: locale,
                          onRefresh: () =>
                              context.read<BookingsCubit>().refresh(),
                          onDetails: (id) => _onViewDetails(context, id),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onViewDetails(BuildContext context, String orderId) {
    _loadingSheetOpen = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const OrderDetailsLoadingSheet(),
    ).whenComplete(() => _loadingSheetOpen = false);
    context.read<BookingsCubit>().loadBookingDetails(orderId);
  }

  Widget _buildTabs(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        height: 40.h,
        padding: EdgeInsets.all(3.r),
        decoration: BoxDecoration(
          color: ColorsManager.grey100,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: ColorsManager.black,
          unselectedLabelColor: ColorsManager.darkGray300,
          labelStyle: TextStyles.font12DarkGray400Weight(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyles.font12DarkGray400Weight(
            context,
          ).copyWith(fontWeight: FontWeight.w500),
          labelPadding: EdgeInsets.zero,
          indicator: BoxDecoration(
            color: ColorsManager.white,
            borderRadius: BorderRadius.circular(10.r),
          ),
          tabs: [
            Tab(text: LocaleKeys.inProgress.tr()),
            Tab(text: LocaleKeys.completed.tr()),
            Tab(text: LocaleKeys.cancelled.tr()),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48.r,
              color: ColorsManager.darkGray300,
            ),
            SizedBox(height: 12.h),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyles.font14DarkGray400Weight(context),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () => context.read<BookingsCubit>().loadBookings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorsManager.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'retry'.tr(),
                style: const TextStyle(color: ColorsManager.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsList extends StatelessWidget {
  final List<BookingModel> items;
  final String locale;
  final Future<void> Function() onRefresh;
  final void Function(String orderId) onDetails;

  const _BookingsList({
    required this.items,
    required this.locale,
    required this.onRefresh,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: ColorsManager.primaryColor,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 48.r,
                        color: ColorsManager.darkGray300,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        LocaleKeys.noBookings.tr(),
                        style: TextStyles.font14DarkGray400Weight(context)
                            .copyWith(
                              fontWeight: FontWeight.w600,
                              color: ColorsManager.darkGray300,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (_, i) {
                final b = items[i];
                return BookingCard(
                  bookingId: b.order?.orderNumber.isNotEmpty == true
                      ? b.order!.orderNumber
                      : shortId(b.id),
                  restaurantName: b.getName(locale),
                  logoUrl: b.restaurantLogoUrl,
                  total: b.order?.totalPrice ?? 0,
                  address: b.restaurantAddress,
                  dateTimeText: b.getFormattedDate(locale),
                  seatsText:
                      '${b.guestsCount} ${locale == 'ar' ? 'ضيوف' : 'guests'}',
                  status: b.bookingStatus,
                  onDetails: () => onDetails(b.id),
                  onDelete: () {},
                  onRate: () {},
                  onCancel: () {},
                );
              },
            ),
    );
  }
}
