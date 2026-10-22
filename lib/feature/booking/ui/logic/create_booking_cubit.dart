// lib/feature/booking/ui/logic/create_booking_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/core/network/api_exception.dart';
import 'package:tavo/feature/Profile/data/repo/profile_repo.dart';
import 'package:tavo/feature/booking/data/repo/bookings_repo.dart';
import 'package:tavo/feature/booking/ui/logic/create_booking_state.dart';

class CreateBookingCubit extends Cubit<CreateBookingState> {
  final BookingsRepo _repo;
  final ProfileRepo? _profileRepo;

  CreateBookingCubit(this._repo, {this._profileRepo})
      : super(const CreateBookingState());

  void init({
    required String restaurantId,
    String? orderId,
    required String restaurantName,
    String? restaurantLogo,
    int? maxGuests,
  }) {
    emit(
      CreateBookingState(
        restaurantId: restaurantId,
        orderId: orderId,
        restaurantName: restaurantName,
        restaurantLogo: restaurantLogo ?? '',
        maxGuests: maxGuests ?? 10,
        guestsCount: 1,
      ),
    );
  }

  void selectDate(DateTime date) {
    emit(
      state.copyWith(
        selectedDate: date,
        selectedTime: null,
        selectedTableIds: {},
        clearAvailability: true,
        clearError: true,
      ),
    );
  }

  void selectTime(String time) {
    emit(
      state.copyWith(
        selectedTime: time,
        selectedTableIds: {},
        clearAvailability: true,
        clearError: true,
      ),
    );
  }

  void setGuestsCount(int count) {
    final clampedCount = count.clamp(1, 20);
    emit(state.copyWith(guestsCount: clampedCount, clearError: true));
  }

  void selectTable(String tableId) {
    emit(state.copyWith(selectedTableIds: {tableId}, clearError: true));
  }

  Future<void> checkAvailability() async {
    if (state.selectedDate == null || state.selectedTime == null) {
      emit(state.copyWith(error: 'Please select date and time'));
      return;
    }

    emit(state.copyWith(loadingAvailability: true, clearError: true));

    try {
      final dateStr = _formatDate(state.selectedDate!);
      final timeStr = _parseTimeForApi(state.selectedTime!);

      final response = await _repo.checkAvailability(
        restaurantId: state.restaurantId,
        date: dateStr,
        time: timeStr,
      );

      emit(
        state.copyWith(
          loadingAvailability: false,
          availability: response,
          availabilityChecked: true,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(loadingAvailability: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loadingAvailability: false, error: e.toString()));
    }
  }

  Future<void> createReservation() async {
    if (!state.canProceed) {
      emit(state.copyWith(error: 'Please complete all required fields'));
      return;
    }

    if (!state.hasEnoughSeats) {
      emit(
        state.copyWith(
          error:
              'Selected tables do not have enough seats for ${state.guestsCount} guests',
        ),
      );
      return;
    }

    emit(state.copyWith(creatingReservation: true, clearError: true));

    try {
      String? customerName;
      String? customerPhone;

      if (_profileRepo != null) {
        try {
          final user = await _profileRepo.getUserProfile();
          customerName = user.name;
          customerPhone = user.phone;
        } catch (_) {}
      }

      final startAt = _buildDateTime(state.selectedDate!, state.selectedTime!);
      final duration = _calculateDuration(state.guestsCount);
      final endAt = startAt.add(duration);

      final reservation = await _repo.createReservation(
        restaurantId: state.restaurantId,
        orderId: state.orderId,
        physicalTableIds: state.selectedTableIds.toList(),
        startAt: startAt,
        endAt: endAt,
        guestsCount: state.guestsCount,
        customerName: customerName,
        customerPhone: customerPhone,
      );

      emit(
        state.copyWith(
          creatingReservation: false,
          createdReservation: reservation,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(creatingReservation: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(creatingReservation: false, error: e.toString()));
    }
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  void reset() {
    emit(
      CreateBookingState(
        restaurantId: state.restaurantId,
        orderId: state.orderId,
        restaurantName: state.restaurantName,
        restaurantLogo: state.restaurantLogo,
        maxGuests: state.maxGuests,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _parseTimeForApi(String displayTime) {
    final parts = displayTime.split(' ');
    if (parts.length < 2) return displayTime;

    final timeParts = parts[0].split(':');
    var hour = int.parse(timeParts[0]);
    final minute = timeParts[1];
    final period = parts[1].toUpperCase();

    // Handle both English (AM/PM) and Arabic (ص/م) formats
    if ((period == 'PM' || period == 'م') && hour != 12) {
      hour += 12;
    } else if ((period == 'AM' || period == 'ص') && hour == 12) {
      hour = 0;
    }

    return '${hour.toString().padLeft(2, '0')}:$minute:00';
  }

  DateTime _buildDateTime(DateTime date, String displayTime) {
    final parts = displayTime.split(' ');
    final timeParts = parts[0].split(':');
    var hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final period = parts.length > 1 ? parts[1].toUpperCase() : 'PM';

    if ((period == 'PM' || period == 'م') && hour != 12) {
      hour += 12;
    } else if ((period == 'AM' || period == 'ص') && hour == 12) {
      hour = 0;
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Duration _calculateDuration(int guestsCount) {
    if (guestsCount <= 2) {
      return const Duration(hours: 1, minutes: 30);
    } else if (guestsCount <= 4) {
      return const Duration(hours: 2);
    } else if (guestsCount <= 6) {
      return const Duration(hours: 2, minutes: 30);
    } else {
      return const Duration(hours: 3);
    }
  }
}
