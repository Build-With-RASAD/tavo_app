import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/localization/locale_keys.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
import 'package:tavo/feature/booking/data/repo/bookings_repo.dart';
import 'package:tavo/feature/booking/ui/logic/create_booking_cubit.dart';
import 'package:tavo/feature/booking/ui/widgets/table_seat_icon.dart';
import 'package:tavo/feature/booking/ui/logic/create_booking_state.dart';
import 'package:tavo/feature/Profile/data/repo/profile_repo.dart';
import 'package:tavo/feature/home/ui/screens/main_nav_screen.dart';

class BookingBottomSheet extends StatefulWidget {
  final String restaurantId;
  final String? orderId;
  final String restaurantName;
  final String? restaurantLogo;
  final int? maxGuests;
  final VoidCallback? onClose;
  final VoidCallback? onSuccess;

  const BookingBottomSheet({
    super.key,
    required this.restaurantId,
    this.orderId,
    required this.restaurantName,
    this.restaurantLogo,
    this.maxGuests,
    this.onClose,
    this.onSuccess,
  });

  static void show(
    BuildContext context, {
    required String restaurantId,
    String? orderId,
    required String restaurantName,
    String? restaurantLogo,
    int? maxGuests,
    VoidCallback? onClose,
    VoidCallback? onSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => BlocProvider(
        create: (_) =>
            CreateBookingCubit(
              getIt<BookingsRepo>(),
              profileRepo: getIt<ProfileRepo>(),
            )..init(
              restaurantId: restaurantId,
              orderId: orderId,
              restaurantName: restaurantName,
              restaurantLogo: restaurantLogo,
              maxGuests: maxGuests,
            ),
        child: BookingBottomSheet(
          restaurantId: restaurantId,
          orderId: orderId,
          restaurantName: restaurantName,
          restaurantLogo: restaurantLogo,
          maxGuests: maxGuests,
          onClose: onClose,
          onSuccess: onSuccess,
        ),
      ),
    );
  }

  @override
  State<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<BookingBottomSheet> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateBookingCubit, CreateBookingState>(
      listener: (context, state) {
        if (state.createdReservation != null) {
          Navigator.of(context).pop();
          widget.onClose?.call();
          _showSuccessSheet(context, state);
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: const Color(0xFFC62828),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<CreateBookingCubit>().clearError();
        }
      },
      builder: (context, state) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: ColorsManager.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            children: [
              _buildHeader(context),
              _buildStepIndicator(state),
              Expanded(child: _buildStepContent(context, state)),
              _buildBottomBar(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Text(
            LocaleKeys.bookTable.tr(),
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              widget.onClose?.call();
            },
            child: Container(
              padding: EdgeInsets.all(8.r),
              decoration: const BoxDecoration(
                color: ColorsManager.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 20.r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(CreateBookingState state) {
    final steps = [
      _StepData(
        context.locale.languageCode == 'ar' ? 'التاريخ والوقت' : 'Date & Time',
        state.selectedDate != null && state.selectedTime != null,
      ),
      _StepData(LocaleKeys.tables.tr(), state.selectedTableIds.isNotEmpty),
      _StepData(LocaleKeys.confirm.tr(), false),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isActive = index == _currentStep;
          final isCompleted = step.isCompleted;

          return Expanded(
            child: GestureDetector(
              onTap: index < 2
                  ? () => setState(() => _currentStep = index)
                  : null,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36.r,
                    height: 36.r,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? ColorsManager.primaryColor
                          : (isActive
                                ? ColorsManager.primaryColor.withValues(
                                    alpha: 0.2,
                                  )
                                : ColorsManager.grey100),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted || isActive
                            ? ColorsManager.primaryColor
                            : ColorsManager.grey200,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isCompleted && !isActive
                          ? Icon(
                              Icons.check,
                              size: 18.r,
                              color: ColorsManager.white,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: isCompleted || isActive
                                    ? ColorsManager.primaryColor
                                    : ColorsManager.darkGray300,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isActive
                          ? ColorsManager.primaryColor
                          : ColorsManager.darkGray300,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, CreateBookingState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_currentStep),
        child: _currentStep == 0
            ? _buildDateTimeStep(context, state)
            : _currentStep == 1
            ? _buildTableStep(context, state)
            : _buildSummaryStep(context, state),
      ),
    );
  }

  Widget _buildTableStep(BuildContext context, CreateBookingState state) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.selectedDate != null && state.selectedTime != null) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: ColorsManager.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18.r,
                    color: ColorsManager.primaryColor,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '${state.selectedDate!.day}/${state.selectedDate!.month}/${state.selectedDate!.year}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Icon(
                    Icons.access_time,
                    size: 18.r,
                    color: ColorsManager.primaryColor,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    state.selectedTime!,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.selectYourTable.tr(),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      LocaleKeys.tapToSelectTable.tr(),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: ColorsManager.darkGray300,
                      ),
                    ),
                  ],
                ),
              ),
              GuestSelector(
                value: state.guestsCount,
                min: 1,
                max: state.maxGuests ?? 10,
                onChanged: (value) {
                  context.read<CreateBookingCubit>().setGuestsCount(value);
                },
              ),
            ],
          ),
          if (state.selectedTableIds.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: state.hasEnoughSeats
                    ? ColorsManager.primaryColor.withValues(alpha: 0.1)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    state.hasEnoughSeats ? Icons.check_circle : Icons.warning,
                    size: 14.r,
                    color: state.hasEnoughSeats
                        ? ColorsManager.primaryColor
                        : const Color(0xFFE65100),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '${LocaleKeys.selected.tr()}: ${state.totalSeatsSelected} ${LocaleKeys.seats.tr()}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: state.hasEnoughSeats
                          ? ColorsManager.primaryColor
                          : const Color(0xFFE65100),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (!state.hasEnoughSeats) ...[
              SizedBox(height: 4.h),
              Text(
                LocaleKeys.notEnoughSeats.tr(),
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0xFFE65100),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
          SizedBox(height: 16.h),
          Expanded(
            child: state.loadingAvailability
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        SizedBox(height: 16.h),
                        Text(
                          LocaleKeys.checkingAvailability.tr(),
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: ColorsManager.darkGray300,
                          ),
                        ),
                      ],
                    ),
                  )
                : state.availableTables.isEmpty
                ? _buildNoTablesView(context, state)
                : _buildTableGrid(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTablesView(BuildContext context, CreateBookingState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.table_restaurant,
            size: 64.r,
            color: ColorsManager.grey200,
          ),
          SizedBox(height: 16.h),
          Text(
            LocaleKeys.noTablesAvailable.tr(),
            style: TextStyle(fontSize: 16.sp, color: ColorsManager.darkGray300),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () =>
                context.read<CreateBookingCubit>().checkAvailability(),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsManager.primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text(LocaleKeys.checkAvailability.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildTableGrid(BuildContext context, CreateBookingState state) {
    final selectedTableId = state.selectedTableIds.isNotEmpty
        ? state.selectedTableIds.first
        : null;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12.w,
        crossAxisSpacing: 12.w,
        childAspectRatio: 1.0,
      ),
      itemCount: state.availableTables.length,
      itemBuilder: (context, index) {
        final table = state.availableTables[index];
        final isSelected = table.id == selectedTableId;

        return GestureDetector(
          onTap: () => context.read<CreateBookingCubit>().selectTable(table.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? ColorsManager.primaryColor
                  : ColorsManager.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected
                    ? ColorsManager.primaryColor
                    : ColorsManager.grey200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: ColorsManager.primaryColor.withValues(
                          alpha: 0.3,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TableSeatIcon(
                  seats: table.seats,
                  isSelected: isSelected,
                  size: 50.r,
                ),
                SizedBox(height: 6.h),
                Text(
                  table.code,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? ColorsManager.white
                        : ColorsManager.black,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateTimeStep(BuildContext context, CreateBookingState state) {
    final locale = context.locale.languageCode;
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.selectDate.tr(),
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 90.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 30,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                final isSelected =
                    state.selectedDate != null &&
                    state.selectedDate!.day == date.day &&
                    state.selectedDate!.month == date.month;

                return GestureDetector(
                  onTap: () =>
                      context.read<CreateBookingCubit>().selectDate(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 65.w,
                    margin: EdgeInsets.only(right: 10.w),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ColorsManager.primaryColor
                          : ColorsManager.grey100,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getDayShort(date.weekday, locale),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: isSelected
                                ? ColorsManager.white
                                : ColorsManager.darkGray300,
                          ),
                        ),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? ColorsManager.white
                                : ColorsManager.black,
                          ),
                        ),
                        Text(
                          _getMonthShort(date.month, locale),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: isSelected
                                ? ColorsManager.white.withValues(alpha: 0.8)
                                : ColorsManager.darkGray300,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            LocaleKeys.selectTime.tr(),
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: _generateTimeSlots(locale, state).map((slot) {
              final isSelected = state.selectedTime == slot;
              return GestureDetector(
                onTap: () =>
                    context.read<CreateBookingCubit>().selectTime(slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ColorsManager.primaryColor
                        : ColorsManager.grey100,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? ColorsManager.white
                          : ColorsManager.black,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep(BuildContext context, CreateBookingState state) {
    final selectedTable = state.availableTables
        .where((t) => state.selectedTableIds.contains(t.id))
        .firstOrNull;
    final formatDate = state.selectedDate != null
        ? '${state.selectedDate!.day}/${state.selectedDate!.month}/${state.selectedDate!.year}'
        : '';

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.bookingSummary.tr(),
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: ColorsManager.grey100,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                _summaryRow(
                  Icons.table_restaurant,
                  LocaleKeys.table.tr(),
                  selectedTable?.code ?? '-',
                ),
                Divider(height: 20.h, color: ColorsManager.grey200),
                _summaryRow(
                  Icons.people,
                  LocaleKeys.capacity.tr(),
                  '${selectedTable?.seats ?? 0} ${LocaleKeys.guests.tr()}',
                ),
                Divider(height: 20.h, color: ColorsManager.grey200),
                _summaryRow(
                  Icons.calendar_today,
                  LocaleKeys.date.tr(),
                  formatDate,
                ),
                Divider(height: 20.h, color: ColorsManager.grey200),
                _summaryRow(
                  Icons.access_time,
                  LocaleKeys.time.tr(),
                  state.selectedTime ?? '-',
                ),
              ],
            ),
          ),
          if (widget.orderId != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: ColorsManager.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: ColorsManager.primaryColor,
                    size: 20.r,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      LocaleKeys.orderWillBeLinked.tr(),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: ColorsManager.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: ColorsManager.white,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, size: 18.r, color: ColorsManager.primaryColor),
        ),
        SizedBox(width: 12.w),
        Text(
          label,
          style: TextStyle(fontSize: 14.sp, color: ColorsManager.darkGray300),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, CreateBookingState state) {
    final canProceed = _canProceed(state);
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  side: const BorderSide(color: ColorsManager.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  LocaleKeys.back.tr(),
                  style: TextStyle(
                    color: ColorsManager.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: 12.w),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canProceed ? () => _onNext(context, state) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorsManager.primaryColor,
                disabledBackgroundColor: ColorsManager.grey200,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: state.creatingReservation
                  ? SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ColorsManager.white,
                      ),
                    )
                  : Text(
                      _currentStep == 2
                          ? LocaleKeys.confirm.tr()
                          : LocaleKeys.next.tr(),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: canProceed
                            ? ColorsManager.white
                            : ColorsManager.darkGray300,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed(CreateBookingState state) {
    switch (_currentStep) {
      case 0:
        return state.selectedDate != null && state.selectedTime != null;
      case 1:
        return state.selectedTableIds.isNotEmpty && state.hasEnoughSeats;
      case 2:
        return true;
      default:
        return false;
    }
  }

  void _onNext(BuildContext context, CreateBookingState state) async {
    if (_currentStep == 0) {
      await context.read<CreateBookingCubit>().checkAvailability();
      if (mounted) {
        final newState = context.read<CreateBookingCubit>().state;
        if (newState.availableTables.isNotEmpty && newState.error == null) {
          setState(() => _currentStep++);
        }
      }
    } else if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      context.read<CreateBookingCubit>().createReservation();
    }
  }

  void _showSuccessSheet(BuildContext context, CreateBookingState state) {
    if (state.createdReservation == null) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSuccessSheet(
        reservation: state.createdReservation!,
        restaurantName: state.restaurantName,
        onDone: () {
          Navigator.of(context).pop();
          widget.onClose?.call();
          widget.onSuccess?.call();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const MainNavScreen(initialIndex: 3),
            ),
            (route) => false,
          );
        },
      ),
    );
  }

  String _getDayShort(int day, String locale) {
    const en = ['', 'M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const ar = ['', 'إ', 'ث', 'أ', 'خ', 'ج', 'ب', 'أ'];
    return locale == 'ar' ? ar[day] : en[day];
  }

  String _getMonthShort(int month, String locale) {
    const en = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const ar = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return locale == 'ar' ? ar[month] : en[month];
  }

  List<String> _generateTimeSlots(String locale, CreateBookingState state) {
    final workingHours = state.availability?.workingHours;

    if (workingHours != null && !workingHours.isClosed) {
      return workingHours.generateTimeSlots();
    }

    final slots = <String>[];
    for (int h = 12; h <= 21; h++) {
      for (int m = 0; m < 60; m += 30) {
        final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        final period = h >= 12
            ? (locale == 'ar' ? 'م' : 'PM')
            : (locale == 'ar' ? 'ص' : 'AM');
        slots.add(
          '${hour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period',
        );
      }
    }
    return slots;
  }
}

class _StepData {
  final String title;
  final bool isCompleted;
  _StepData(this.title, this.isCompleted);
}

class GuestSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  const GuestSelector({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorsManager.grey100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            icon: Icons.remove,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorsManager.primaryColor,
              ),
            ),
          ),
          _buildButton(
            icon: Icons.add,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({required IconData icon, VoidCallback? onTap}) {
    final isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isEnabled ? ColorsManager.primaryColor : ColorsManager.grey200,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isEnabled ? ColorsManager.white : ColorsManager.darkGray300,
        ),
      ),
    );
  }
}

class _BookingSuccessSheet extends StatelessWidget {
  final BookingModel reservation;
  final String restaurantName;
  final VoidCallback onDone;

  const _BookingSuccessSheet({
    required this.reservation,
    required this.restaurantName,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(12.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: ColorsManager.grey200,
                borderRadius: BorderRadius.circular(3.r),
              ),
            ),
            SizedBox(height: 24.h),
            Container(
              width: 80.r,
              height: 80.r,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F7EB),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 48.r,
                color: const Color(0xFF22A83A),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              LocaleKeys.bookingCreated.tr(),
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8.h),
            Text(
              LocaleKeys.yourTableReserved.tr(),
              style: TextStyle(
                fontSize: 14.sp,
                color: ColorsManager.darkGray300,
              ),
            ),
            SizedBox(height: 24.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: ColorsManager.grey100,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                children: [
                  _infoRow(Icons.restaurant, restaurantName),
                  Divider(height: 16.h),
                  _infoRow(
                    Icons.calendar_today,
                    reservation.getFormattedDate(context.locale.languageCode),
                  ),
                  Divider(height: 16.h),
                  _infoRow(
                    Icons.access_time,
                    reservation.getTimeRange(context.locale.languageCode),
                  ),
                  Divider(height: 16.h),
                  _infoRow(
                    Icons.people,
                    '${reservation.guestsCount} ${LocaleKeys.guests.tr()}',
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsManager.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  LocaleKeys.done.tr(),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: ColorsManager.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: ColorsManager.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, size: 18.r, color: ColorsManager.primaryColor),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
