import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import '../local/secure_storage.dart';
import '../../core/constants/api_constants.dart';

// Custom Exceptions
class ApiKeyException implements Exception {
  final String message;
  ApiKeyException(this.message);
}

class InsufficientCreditsException implements Exception {
  final String message;
  InsufficientCreditsException(this.message);
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class ValidationException implements Exception {
  final String message;
  final List<dynamic>? details;
  ValidationException(this.message, {this.details});
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
}

class ApiClient {
  final Dio _dio;
  final SecureStorageService _secureStorage;

  ApiClient(this._secureStorage) : _dio = Dio() {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(milliseconds: ApiConstants.defaultTimeout);
    _dio.options.receiveTimeout = const Duration(milliseconds: ApiConstants.defaultTimeout);
    _dio.options.headers = {
      'Content-Type': 'application/json',
    };

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final fbUser = fb.FirebaseAuth.instance.currentUser;
            if (fbUser != null) {
              final token = await fbUser.getIdToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
                return handler.next(options);
              }
            }
          } catch (e) {
            debugPrint('Failed to get Firebase token dynamically: $e');
          }

          final token = await _secureStorage.getAuthToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final response = error.response;
          final status = response?.statusCode;

          // Handle 401 Unauthorized (Token Refresh)
          if (status == 401) {
            fb.User? fbUser;
            try {
              fbUser = fb.FirebaseAuth.instance.currentUser;
            } catch (e) {
              debugPrint('Firebase uninitialized in API client: $e');
            }
            if (fbUser != null) {
              try {
                // Force refresh token
                final newToken = await fbUser.getIdToken(true);
                if (newToken != null) {
                  await _secureStorage.setAuthToken(newToken);
                  
                  // Retry the request with the new token
                  final options = error.requestOptions;
                  options.headers['Authorization'] = 'Bearer $newToken';
                  
                  // Clone options for retry
                  final retryResponse = await _dio.fetch(options);
                  return handler.resolve(retryResponse);
                }
              } catch (e) {
                debugPrint('Failed to refresh Firebase token: $e');
              }
            }
            await _secureStorage.clearAuthToken();
          }

          // Handle 402 Insufficient Credits
          if (status == 402) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: response,
                type: error.type,
                error: InsufficientCreditsException('INSUFFICIENT_CREDITS'),
              ),
            );
          }

          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  // Error handling mapper
  Exception _handleError(dynamic error) {
    if (error is DioException) {
      if (error.error is InsufficientCreditsException) {
        return error.error as InsufficientCreditsException;
      }
      
      final response = error.response;
      if (response != null) {
        final data = response.data;
        final message = data?['message'] ?? data?['error'] ?? data?['detail'] ?? 'An error occurred';
        
        if (response.statusCode == 422) {
          return ValidationException(message.toString(), details: data?['detail']);
        }
        if (response.statusCode == 402) {
          return InsufficientCreditsException('INSUFFICIENT_CREDITS');
        }
        return ServerException(message.toString());
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return NetworkException('Timeout de connexion. Veuillez réessayer.');
      }

      return NetworkException('Problème de connexion. Vérifiez votre internet.');
    }
    return ServerException(error.toString());
  }

  // GET Request
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters, options: options);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // POST Request
  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters, options: options);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // PUT Request
  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters, options: options);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE Request
  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.delete(path, data: data, queryParameters: queryParameters, options: options);
    } catch (e) {
      throw _handleError(e);
    }
  }
}
