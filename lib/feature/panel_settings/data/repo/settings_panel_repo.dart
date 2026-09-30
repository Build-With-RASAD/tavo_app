// lib/feature/panel_settings/data/repo/settings_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';
import '../model/settings_models.dart';

class SettingsPanelRepo {
  SettingsPanelRepo({required ApiService api}) : _api = api;
  final ApiService _api;

  String _q(String restaurantId) => '?restaurantId=$restaurantId';

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
      return (
        workingHours: hours is List
            ? List<WorkingDayEntry>.from(hours
                .whereType<Map<String, dynamic>>()
                .map(WorkingDayEntry.fromJson))
            : const <WorkingDayEntry>[],
        reservationSettings: payload['reservationSettings'] is Map
            ? ReservationSettings.fromJson(Map<String, dynamic>.from(
                payload['reservationSettings'] as Map))
            : const ReservationSettings(),
        celebrationFeatures: payload['celebrationFeatures'] is Map
            ? Map<String, dynamic>.from(
                payload['celebrationFeatures'] as Map)
            : const <String, dynamic>{},
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
      final res = await _api.put(
        '${ApiConstants.panelBase}/settings${_q(restaurantId)}',
        data: {'reservationSettings': rs.toJson()},
      );
      final payload = panelPayload(res.data) as Map<String, dynamic>;
      final out = payload['reservationSettings'] ?? payload;
      return ReservationSettings.fromJson(
          Map<String, dynamic>.from(out as Map));
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
