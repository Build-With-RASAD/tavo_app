import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tavo/core/cache/cache_helper.dart';
import 'api_constants.dart';

class DioFactory {
  DioFactory._();

  static Dio? _dio;

  static Dio get dio {
    if (_dio == null) {
      _dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 60),  // ✅ زيادة من 30 إلى 60
          receiveTimeout: const Duration(seconds: 60),  // ✅ زيادة من 30 إلى 60
          sendTimeout: const Duration(seconds: 60),     // ✅ زيادة من 30 إلى 60
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      _dio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            // Public guest calls (table QR) carry their own short-lived bearer
            // and must never be overwritten by the signed-in customer token.
            if (options.extra['skipAuth'] == true) {
              return handler.next(options);
            }

            final token = CacheHelper.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            
            if (kDebugMode) {
              print('REQUEST[${options.method}] => PATH: ${options.path}');
              print('REQUEST DATA => ${options.data}');
              print('REQUEST HEADERS => ${options.headers}');
            }
            
            return handler.next(options);
          },
          onResponse: (response, handler) {
            if (kDebugMode) {
              print('RESPONSE[${response.statusCode}] => DATA: ${response.data}');
            }
            return handler.next(response);
          },
          onError: (error, handler) {
            if (kDebugMode) {
              print('ERROR[${error.response?.statusCode}] => ${error.message}');
              print('ERROR DATA => ${error.response?.data}');
              print('ERROR TYPE => ${error.type}');
            }
            return handler.next(error);
          },
        ),
      );
    }
    return _dio!;
  }
}