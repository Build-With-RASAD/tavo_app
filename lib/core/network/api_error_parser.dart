// lib/core/network/api_error_parser.dart
import 'package:dio/dio.dart';

/// Converts [DioException]s into the plain-string errors the UI shows.
/// Single source of truth shared by AuthRepo / RestaurantAuthRepo /
/// RestaurantPanelRepo (behavior identical to the original private helper).
String parseDioError(DioException e) {
  if (e.response?.data != null) {
    final data = e.response?.data;
    if (data is String && data.contains('<!DOCTYPE html>')) {
      return 'API endpoint not found';
    }
    if (data is String) return data;
    if (data is Map<String, dynamic>) {
      if (data['errors'] != null && data['errors'] is List) {
        final errors = data['errors'] as List;
        if (errors.isNotEmpty) {
          return errors.map((e) => e['msg']?.toString() ?? '').join(', ');
        }
      }
      return data['message']?.toString() ??
          data['error']?.toString() ??
          'Something went wrong';
    }
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Connection timeout';
    case DioExceptionType.connectionError:
      return 'No internet connection';
    default:
      return 'Something went wrong';
  }
}
