// test/api_error_parser_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/api_error_parser.dart';

DioException _withResponse(dynamic data, {int status = 400}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: data,
      ),
    );

void main() {
  test('maps validation errors list to joined messages', () {
    final msg = parseDioError(_withResponse({
      'errors': [
        {'msg': 'Invalid status'},
        {'msg': 'Another problem'},
      ],
    }));
    expect(msg, 'Invalid status, Another problem');
  });

  test('maps message map to its message', () {
    expect(
      parseDioError(_withResponse({'message': 'Cannot change status'})),
      'Cannot change status',
    );
  });

  test('maps HTML body to endpoint-not-found', () {
    expect(
      parseDioError(_withHtmlResponse('<!DOCTYPE html><html></html>')),
      'API endpoint not found',
    );
  });

  test('maps timeouts and connection errors', () {
    expect(
      parseDioError(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      )),
      'Connection timeout',
    );
    expect(
      parseDioError(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      )),
      'No internet connection',
    );
  });
}

DioException _withHtmlResponse(String html) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 404,
        data: html,
      ),
    );
