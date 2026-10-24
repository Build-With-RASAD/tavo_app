// lib/feature/restaurant_auth/ui/screens/reservations_tab.dart

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/helpers/utils/short_id.dart';
import 'package:tavo/core/helpers/utils/spacing.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/core/widgets/status_badge.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
import 'package:tavo/feature/booking/data/model/reservation_schedule.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_state.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reservations tab of the staff shell.
///
/// The old tab was a flat list of rows: a name, a date and a status. A host
/// cannot run a door from that. This version answers the four questions a
/// host actually has:
///   * what does today look like hour by hour (the timeline),
///   * which arrival is next and how late is it (relative pill),
///   * how many guests and which table (party + assignment),
///   * what did the guest ask for (special requests).
/// Days are grouped and sorted, so "today" is always the first section even
/// when older bookings exist.
class ReservationsTab extends StatelessWidget {
  const ReservationsTab({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context) {
    if (restaurantId.isEmpty) return Center(child: Text('no_data'.tr()));
    return BlocProvider(
      create: (_) =>
          getIt<RestaurantHomeCubit>(param1: restaurantId)..loadReservations(),
      child: const _ReservationsList(),
    );
  }
}

/// The list itself — kept as its own widget so `context.read` resolves
/// against the [BlocProvider] above it.
class _ReservationsList extends StatelessWidget {
  const _ReservationsList();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RestaurantHomeCubit, RestaurantHomeState>(
      listener: (context, state) {
        if (state is RestaurantHomeLoaded && state.actionError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionError!)),
          );
        }
      },
      builder: (context, state) {
        if (state is RestaurantHomeLoading ||
            state is RestaurantHomeInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is RestaurantHomeError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.message),
                verticalSpace(12),
                ElevatedButton(
                  onPressed: () =>
                      context.read<RestaurantHomeCubit>().loadReservations(),
                  child: Text('retry'.tr()),
                ),
              ],
            ),
          );
        }

        final loaded = state as RestaurantHomeLoaded;
        if (loaded.reservations.isEmpty) {
          return EmptyStateView(
            icon: Iconsax.calendar_2,
            title: 'no_reservations'.tr(),
            onRetry: () =>
                context.read<RestaurantHomeCubit>().loadReservations(),
          );
        }

        final now = DateTime.now();
        final languageCode = context.locale.languageCode;
        final days = groupReservationsByDay(loaded.reservations);
        final today = days
            .where((day) => reservationDay(day.date) == reservationDay(now))
            .toList();
        final todaysBookings = today.isEmpty ? <BookingModel>[] : today.first.bookings;

        return RefreshIndicator(
          onRefresh: () =>
              context.read<RestaurantHomeCubit>().loadReservations(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
            children: [
              if (todaysBookings.isNotEmpty)
                _TodaySummary(bookings: todaysBookings, now: now),
              for (final day in days) ...[
                _DayHeader(
                  label: reservationDayLabel(
                    day.date,
                    now,
                    languageCode,
                    today: 'today'.tr(),
                    tomorrow: 'reservations_tomorrow'.tr(),
                  ),
                  count: day.bookings.length,
                  guests: day.guests,
                ),
                for (final booking in day.bookings)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _ReservationCard(
                      booking: booking,
                      acting: loaded.actingId == booking.id,
                      now: now,
                      onAction: (action) => context
                          .read<RestaurantHomeCubit>()
                          .updateStatus(booking.id, action),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Today at a glance: how many covers, how many are still pending, and the
/// hour-by-hour histogram. The timeline is informational (no hidden filter):
/// tapping an hour does not pretend to filter a list that is already grouped.
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.bookings, required this.now});

  final List<BookingModel> bookings;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final languageCode = context.locale.languageCode;
    final pending = bookings.where((b) => b.status == 'pending').length;
    final seated = bookings.where((b) => b.status == 'seated').length;
    final covers = bookings.fold(0, (sum, b) => sum + b.guestsCount);
    final hours = timelineHours(bookings);
    final perHour = reservationsPerHour(bookings);

    return Container(
      margin: EdgeInsets.only(bottom: 18.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: ColorsManager.primaryColor.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${bookings.length}',
                style: TextStyle(
                  fontSize: 30.sp,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: ColorsManager.black,
                ),
              ),
              SizedBox(width: 8.w),
              Padding(
                padding: EdgeInsets.only(bottom: 3.h),
                child: Text(
                  'reservations_today'.tr(),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: ColorsManager.darkGray,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$covers ${'guests'.tr()}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: ColorsManager.darkGray,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              _Stat(
                icon: Iconsax.clock,
                label: 'pending'.tr(),
                value: '$pending',
                color: const Color(0xFFF9A825),
              ),
              SizedBox(width: 8.w),
              _Stat(
                icon: Iconsax.people,
                label: 'seated_now'.tr(),
                value: '$seated',
                color: const Color(0xFF22A83A),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 54.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hours.length,
              separatorBuilder: (_, __) => SizedBox(width: 6.w),
              itemBuilder: (context, index) {
                final hour = hours[index];
                final count = perHour[hour] ?? 0;
                final isNow = now.hour == hour;
                return _HourCell(
                  label: hourLabel(hour, languageCode),
                  count: count,
                  isNow: isNow,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 5.w),
          Text(
            '$value ',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: ColorsManager.darkGray),
          ),
        ],
      ),
    );
  }
}

class _HourCell extends StatelessWidget {
  const _HourCell({
    required this.label,
    required this.count,
    required this.isNow,
  });

  final String label;
  final int count;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;

    return Container(
      width: 46.w,
      padding: EdgeInsets.symmetric(vertical: 5.h),
      decoration: BoxDecoration(
        color: isNow
            ? ColorsManager.primaryColor
            : active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isNow
              ? ColorsManager.primaryColor
              : const Color(0xFFEBDCC0),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            active ? '$count' : '·',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: isNow
                  ? ColorsManager.black
                  : active
                      ? ColorsManager.black
                      : ColorsManager.darkGray300,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: 9.sp,
              color: isNow ? ColorsManager.black : ColorsManager.darkGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.label,
    required this.count,
    required this.guests,
  });

  final String label;
  final int count;
  final int guests;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 4.h, bottom: 8.h),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: ColorsManager.black,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '$count · $guests ${'guests'.tr()}',
            style: TextStyle(fontSize: 11.sp, color: ColorsManager.darkGray300),
          ),
          SizedBox(width: 10.w),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.booking,
    required this.acting,
    required this.now,
    required this.onAction,
  });

  final BookingModel booking;
  final bool acting;
  final DateTime now;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final languageCode = context.locale.languageCode;
    final textTheme = Theme.of(context).textTheme;
    final actions = nextActionsFor(booking.status);
    final tables = booking.tables
        .map((table) => table.code)
        .where((code) => code.isNotEmpty)
        .toList();
    final relative = _relativeLabel(languageCode);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: ColorsManager.grey100),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimeBlock(
                  start: clockLabel(booking.startAt, languageCode),
                  end: clockLabel(booking.endAt, languageCode),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              booking.guestName.isNotEmpty
                                  ? booking.guestName
                                  : '#${shortId(booking.id)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          StatusBadge(status: booking.status),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children: [
                          _Pill(
                            icon: Iconsax.people,
                            label:
                                '${booking.guestsCount} ${'guests'.tr()}',
                          ),
                          _Pill(
                            icon: Iconsax.grid_2,
                            label: tables.isEmpty
                                ? 'unassigned'.tr()
                                : tables.join(', '),
                            warn: tables.isEmpty &&
                                (booking.status == 'confirmed' ||
                                    booking.status == 'pending'),
                          ),
                          if (relative != null) relative,
                        ],
                      ),
                      if (booking.guestPhone.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        _CallRow(phone: booking.guestPhone),
                      ],
                      if (booking.specialRequests.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        _SpecialRequest(text: booking.specialRequests),
                      ],
                      if (actions.isNotEmpty) ...[
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            for (var i = 0; i < actions.length; i++) ...[
                              if (i > 0) SizedBox(width: 8.w),
                              Expanded(
                                child: _buildActionButton(
                                  context,
                                  actions[i],
                                  textTheme,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "in 25 min" for an imminent arrival, "12 min late" once the slot has
  /// passed, nothing for settled bookings.
  Widget? _relativeLabel(String languageCode) {
    if (booking.status != 'pending' && booking.status != 'confirmed') {
      return null;
    }
    final minutes = booking.startAt.difference(now).inMinutes;
    if (minutes < -10) {
      return _Pill(
        icon: Iconsax.warning_2,
        label: 'minutes_late'.tr(args: ['${-minutes}']),
        danger: true,
      );
    }
    if (minutes <= 60) {
      return _Pill(
        icon: Iconsax.timer_1,
        label: 'in_minutes'.tr(args: ['${minutes < 0 ? 0 : minutes}']),
        warn: true,
      );
    }
    return null;
  }

  Widget _buildActionButton(
    BuildContext context,
    String action,
    TextTheme textTheme,
  ) {
    final isDanger = action == 'cancel';
    return ElevatedButton(
      onPressed: acting ? null : () => onAction(action),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isDanger ? ColorsManager.redButton : ColorsManager.primaryColor,
        foregroundColor:
            isDanger ? ColorsManager.white : ColorsManager.black,
        minimumSize: Size(0, 38.h),
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        textStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
      ),
      child: acting
          ? SizedBox(
              width: 16.w,
              height: 16.h,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(actionLabelKey(action).tr()),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.start, required this.end});

  final String start;
  final String end;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78.w,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        color: ColorsManager.grey100,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Text(
            start,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: ColorsManager.black,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'ends_at'.tr(args: [end]),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(fontSize: 9.sp, color: ColorsManager.darkGray300),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    this.warn = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool warn;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFC62828)
        : warn
            ? const Color(0xFFB26A00)
            : ColorsManager.darkGray;
    final background = danger
        ? const Color(0xFFFDECEA)
        : warn
            ? const Color(0xFFFFF3DF)
            : ColorsManager.grey100;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({required this.phone});

  final String phone;

  Future<void> _call() async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _call,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 3.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.call, size: 13, color: Color(0xFF1565C0)),
              SizedBox(width: 5.w),
              Text(
                phone,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecialRequest extends StatelessWidget {
  const _SpecialRequest({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(10.r),
        border: const Border(
          left: BorderSide(color: Color(0xFFB0B7C3), width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.message_text, size: 13, color: Color(0xFF5A6472)),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.sp,
                height: 1.45,
                color: const Color(0xFF3D4552),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
