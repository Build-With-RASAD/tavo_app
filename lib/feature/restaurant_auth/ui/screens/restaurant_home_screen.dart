import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/helpers/utils/short_id.dart';
import 'package:tavo/core/helpers/utils/spacing.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
import 'package:tavo/feature/restaurant_auth/data/repo/restaurant_auth_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_state.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/restaurant_login_screen.dart';

/// Staff landing: pick a venue (when several), see its reservations and move
/// them through confirm → seat → complete (or cancel).
class RestaurantHomeScreen extends StatefulWidget {
  final List<StaffRestaurant> restaurants;

  const RestaurantHomeScreen({super.key, this.restaurants = const []});

  @override
  State<RestaurantHomeScreen> createState() => _RestaurantHomeScreenState();
}

class _RestaurantHomeScreenState extends State<RestaurantHomeScreen> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId =
        widget.restaurants.isNotEmpty ? widget.restaurants.first.restaurantId : '';
  }

  Future<void> _onLogout() async {
    await getIt<RestaurantAuthRepo>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RestaurantLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final selected = widget.restaurants
        .where((r) => r.restaurantId == _selectedId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(selected?.displayName(locale) ?? 'my_reservations'.tr()),
        actions: [
          IconButton(
            tooltip: 'logout'.tr(),
            icon: const Icon(Icons.logout),
            onPressed: _onLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.restaurants.length > 1) _buildVenuePicker(locale),
          Expanded(
            child: _selectedId.isEmpty
                ? Center(child: Text('no_data'.tr()))
                : BlocProvider(
                    key: ValueKey(_selectedId),
                    create: (_) =>
                        getIt<RestaurantHomeCubit>(param1: _selectedId)
                          ..loadReservations(),
                    child: _buildReservations(context),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenuePicker(String locale) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          for (final r in widget.restaurants)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: ChoiceChip(
                label: Text(r.displayName(locale)),
                selected: r.restaurantId == _selectedId,
                onSelected: (_) =>
                    setState(() => _selectedId = r.restaurantId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReservations(BuildContext context) {
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
                _StatusBadge(status: booking.status, locale: locale),
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

class _StatusBadge extends StatelessWidget {
  final String status;
  final String locale;

  const _StatusBadge({required this.status, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        _label(context),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  String _label(BuildContext context) {
    switch (status) {
      case 'pending':
        return 'pending'.tr();
      case 'confirmed':
        return 'confirmed'.tr();
      case 'seated':
        return 'seated'.tr();
      case 'completed':
        return 'completed'.tr();
      case 'cancelled':
        return 'cancelled'.tr();
      default:
        return status;
    }
  }

  Color get _background {
    switch (status) {
      case 'confirmed':
      case 'completed':
        return const Color(0xFFE8F7EB);
      case 'seated':
        return const Color(0xFFE3F2FD);
      case 'cancelled':
      case 'no_show':
        return const Color(0xFFFDECEA);
      default:
        return const Color(0xFFFFF8E1);
    }
  }

  Color get _foreground {
    switch (status) {
      case 'confirmed':
      case 'completed':
        return const Color(0xFF22A83A);
      case 'seated':
        return const Color(0xFF1565C0);
      case 'cancelled':
      case 'no_show':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFF9A825);
    }
  }
}
