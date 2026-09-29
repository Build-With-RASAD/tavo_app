// lib/feature/restaurant_panel/ui/screens/dashboard_screen.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/dashboard_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/dashboard_state.dart';

/// Staff panel home: venue header, six headline stat cards and the latest
/// reviews for one venue.
///
/// Builds its own [DashboardCubit] through get_it (the shell only supplies
/// the restaurant id and the venue it already holds) and drives the three
/// async states with [ListSkeleton] / [ErrorStateView] / content, mirroring
/// `RestaurantHomeScreen`'s state wiring. Card styling mirrors
/// `booking_card.dart`: white card, `grey100` border, ScreenUtil padding.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.restaurantId,
    required this.venue,
  });

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DashboardCubit>()..load(restaurantId),
      child: BlocConsumer<DashboardCubit, DashboardState>(
        // Failures render inline via the error state — no transient UI here.
        listener: (context, state) {},
        builder: (context, state) {
          if (state is DashboardError) {
            return Scaffold(
              body: ErrorStateView(
                message: state.message,
                onRetry: () =>
                    context.read<DashboardCubit>().load(restaurantId),
              ),
            );
          }
          if (state is DashboardLoaded) {
            return Scaffold(
              body: RefreshIndicator(
                onRefresh: () =>
                    context.read<DashboardCubit>().load(restaurantId),
                child: _buildLoaded(context, state.stats),
              ),
            );
          }
          // DashboardInitial / DashboardLoading.
          return const Scaffold(body: ListSkeleton());
        },
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, DashboardStats stats) {
    final locale = context.locale.languageCode;
    final recent = stats.reviews.recent.take(3).toList();

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, locale),
            SizedBox(height: 16.h),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12.w,
                crossAxisSpacing: 12.w,
                mainAxisExtent: 130.h,
              ),
              children: [
                _StatCard(
                  label: 'total_orders'.tr(),
                  value: '${stats.orders.total}',
                ),
                _StatCard(
                  label: 'new_orders'.tr(),
                  value: '${stats.orders.newCount}',
                ),
                _StatCard(
                  label: 'pending'.tr(),
                  value: '${stats.orders.pending}',
                ),
                _StatCard(
                  label: 'total_reservations'.tr(),
                  value: '${stats.reservations.total}',
                ),
                _StatCard(
                  label: 'revenue_this_month'.tr(),
                  value:
                      '${_formatAmount(stats.revenue.thisMonth)} ${'currency'.tr()}',
                ),
                _StatCard(
                  label: 'avg_rating'.tr(),
                  value: '${stats.reviews.averageRating}',
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Text(
              'recent_reviews'.tr(),
              style: TextStyles.font16Black500Weight(context),
            ),
            SizedBox(height: 8.h),
            if (recent.isEmpty)
              EmptyStateView(
                icon: Icons.rate_review_outlined,
                title: 'no_data'.tr(),
              )
            else
              for (final review in recent) ...[
                _ReviewCard(review: review),
                SizedBox(height: 8.h),
              ],
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String locale) {
    return Row(
      children: [
        Container(
          width: 44.r,
          height: 44.r,
          decoration: BoxDecoration(
            color: ColorsManager.grey100,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.restaurant,
            size: 22.r,
            color: ColorsManager.darkGray300,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                venue.displayName(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.font20Black500Weight(context),
              ),
              SizedBox(height: 2.h),
              Text(
                'dashboard'.tr(),
                style: TextStyles.font14DarkGray400Weight(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One headline number: grey label above a bold value on a white card.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: ColorsManager.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.font12DarkGray400Weight(context),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.font18Black500Weight(context),
          ),
        ],
      ),
    );
  }
}

/// One recent review: star row, comment and reviewer name.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final RecentReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: ColorsManager.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < review.rating && i < 5; i++) ...[
                if (i > 0) SizedBox(width: 2.w),
                Icon(Icons.star, size: 16.r, color: ColorsManager.secondary500),
              ],
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              review.comment,
              style: TextStyles.font14Black400Weight(context),
            ),
          ],
          if (review.userName.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              review.userName,
              style: TextStyles.font12DarkGray400Weight(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `400` → `400`, `1234.5` → `1,234.50` — thousands grouping for revenue.
String _formatAmount(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return _groupDigits(value.round());
  }
  final whole = _groupDigits(value.truncate());
  final cents = (value - value.truncate()).abs().toStringAsFixed(2).substring(2);
  return '$whole.$cents';
}

String _groupDigits(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}
