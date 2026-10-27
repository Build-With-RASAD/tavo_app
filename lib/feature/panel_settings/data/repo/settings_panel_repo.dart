// lib/feature/panel_settings/data/repo/settings_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';
import '../model/settings_models.dart';

class SettingsPanelRepo {
  SettingsPanelRepo({required this._api});
  final ApiService _api;

  String _q(String restaurantId) => '?restaurantId=$restaurantId';

  static Map<String, dynamic>? _mapOrNull(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  Future<
      ({
        List<WorkingDayEntry> workingHours,
        ReservationSettings reservationSettings,
        Map<String, dynamic> celebrationFeatures
      })> getSettings(String restaurantId) async {
    try {
      final res = await _api
          .get('${ApiConstants.panelBase}/settings${_q(restaurantId)}');
      final payload = panelPayload(res.data) as Map<String, dynamic>;
      final hours = payload['workingHours'];
      final celebration = _mapOrNull(payload['celebrationFeatures']);
      return (
        workingHours: hours is List
            ? List<WorkingDayEntry>.from(hours
                .whereType<Map<String, dynamic>>()
                .map(WorkingDayEntry.fromJson))
            : const <WorkingDayEntry>[],
        // The screen edits booking rules as one form, so the reservation half
        // is returned with the celebration half already folded in. The raw
        // celebration map stays in the record for callers that want it.
        reservationSettings: ReservationSettings.fromJson(
          _mapOrNull(payload['reservationSettings']) ?? const {},
        ).withCelebration(celebration),
        celebrationFeatures: celebration ?? const <String, dynamic>{},
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<List<WorkingDayEntry>> updateWorkingHours(
      String restaurantId, List<WorkingDayEntry> days) async {
    try {
      final res = await _api.put(
        '${ApiConstants.panelBase}/working-hours${_q(restaurantId)}',
        data: {
          'workingHours': [for (final d in days) d.toJson()],
        },
      );
      final payload = panelPayload(res.data);
      final rows = payload is List ? payload : panelUnwrapList(payload).items;
      return rows
          .whereType<Map<String, dynamic>>()
          .map(WorkingDayEntry.fromJson)
          .toList();
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<ReservationSettings> updateReservationSettings(
      String restaurantId, ReservationSettings rs) async {
    try {
      // One request, both halves: `PUT /settings` replaces the reservation
      // object wholesale, so a body carrying only the fields the old screen
      // knew about used to reset the other six to their schema defaults.
      final res = await _api.put(
        '${ApiConstants.panelBase}/settings${_q(restaurantId)}',
        data: {
          'reservationSettings': rs.toReservationJson(),
          'celebrationFeatures': rs.toCelebrationJson(),
        },
      );
      final payload = panelPayload(res.data) as Map<String, dynamic>;
      final saved = _mapOrNull(payload['reservationSettings']) ?? payload;
      return ReservationSettings.fromJson(saved)
          .withCelebration(_mapOrNull(payload['celebrationFeatures']));
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<
      ({
        ReservationSettings reservationSettings,
        List<WorkingDayEntry> workingHours
      })> getAvailability(String restaurantId) async {
    try {
      final res = await _api
          .get('${ApiConstants.panelBase}/availability${_q(restaurantId)}');
      final payload = panelPayload(res.data) as Map<String, dynamic>;
      final hours = payload['workingHours'];
      return (
        reservationSettings: payload['reservationSettings'] is Map
            ? ReservationSettings.fromJson(Map<String, dynamic>.from(
                payload['reservationSettings'] as Map))
            : const ReservationSettings(),
        workingHours: hours is List
            ? <WorkingDayEntry>[
                ...hours
                    .whereType<Map<String, dynamic>>()
                    .map(WorkingDayEntry.fromJson)
              ]
            : const <WorkingDayEntry>[],
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }
}
