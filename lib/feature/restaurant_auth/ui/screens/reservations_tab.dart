// lib/feature/restaurant_auth/ui/screens/reservations_tab.dart

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/helpers/utils/short_id.dart';
import 'package:tavo/core/helpers/utils/spacing.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/widgets/status_badge.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_state.dart';

/// Reservations tab of the staff shell: the former `RestaurantHomeScreen`
/// body (venue picker, app bar and logout removed — those live in
/// [StaffShellScreen] now) driving one venue's bookings through
/// `RestaurantHomeCubit` with confirm → seat → complete (or cancel) actions.
///
/// The status pill is the shared [StatusBadge] (ruling): its `colorFor`
/// palette already covers every reservation status.
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
          return Center(child: Text('no_reservations'.tr()));
        }
        return RefreshIndicator(
          onRefresh: () =>
              context.read<RestaurantHomeCubit>().loadReservations(),
          child: ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: loaded.reservations.length,
            separatorBuilder: (_, __) => verticalSpace(12),
            itemBuilder: (context, index) {
              final booking = loaded.reservations[index];
              return _ReservationCard(
                booking: booking,
                acting: loaded.actingId == booking.id,
                onAction: (action) => context
                    .read<RestaurantHomeCubit>()
                    .updateStatus(booking.id, action),
              );
            },
          ),
        );
      },
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final BookingModel booking;
  final bool acting;
  final void Function(String action) onAction;

  const _ReservationCard({
    required this.booking,
    required this.acting,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final textTheme = Theme.of(context).textTheme;
    final actions = nextActionsFor(booking.status);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.w),
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
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge(status: booking.status),
              ],
            ),
            verticalSpace(4),
            Text(
              booking.getFormattedDate(locale),
              style: textTheme.bodySmall,
            ),
            verticalSpace(4),
            Text(
              '${'guests'.tr()}: ${booking.guestsCount}'
              '${booking.guestPhone.isNotEmpty ? ' • ${booking.guestPhone}' : ''}'
              '${booking.getTablesText().isNotEmpty ? ' • ${booking.getTablesText()}' : ''}',
              style: textTheme.bodySmall,
            ),
            if (actions.isNotEmpty) ...[
              verticalSpace(8),
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
    );
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
        minimumSize: Size(0, 40.h),
      ),
      child: acting
          ? SizedBox(
              width: 18.w,
              height: 18.h,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(actionLabelKey(action).tr()),
    );
  }
}
