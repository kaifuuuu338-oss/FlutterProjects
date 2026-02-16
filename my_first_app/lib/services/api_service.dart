import 'package:dio/dio.dart';
import 'package:my_first_app/core/constants/app_constants.dart';
import 'auth_service.dart';

class APIService {
  late Dio _dio;
  final AuthService _authService = AuthService();

  APIService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.apiTimeout,
        receiveTimeout: AppConstants.apiTimeout,
        contentType: 'application/json',
      ),
    );

    // Add interceptor for auth token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          String? token = await _authService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            bool refreshed = await _authService.refreshToken();
            if (refreshed) {
              return handler.resolve(await _retry(error.requestOptions));
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  /// Login and return JWT token from backend.
  /// Supported response shapes:
  /// { "token": "..." } OR { "access_token": "..." } OR { "data": { "token": "..." } }
  Future<String> login(String mobile, String password) async {
    try {
      final response = await _dio.post(
        AppConstants.loginEndpoint,
        data: {
          'mobile_number': mobile,
          'password': password,
        },
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final directToken = body['token'] ?? body['access_token'];
        if (directToken is String && directToken.isNotEmpty) {
          return directToken;
        }
        final nested = body['data'];
        if (nested is Map<String, dynamic>) {
          final nestedToken = nested['token'] ?? nested['access_token'];
          if (nestedToken is String && nestedToken.isNotEmpty) {
            return nestedToken;
          }
        }
      }
      throw Exception('Token not present in login response');
    } on DioException catch (e) {
      throw Exception('Login failed: ${e.message}');
    }
  }

  /// Submit screening
  Future<Map<String, dynamic>> submitScreening(Map<String, dynamic> screeningData) async {
    try {
      final response = await _dio.post(
        AppConstants.screeningEndpoint,
        data: screeningData,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      print('API Error: $e');
      throw Exception('Screening submission failed: ${e.message}');
    }
  }

  /// Get child details
  Future<Map<String, dynamic>> getChildDetails(String childId) async {
    try {
      final response = await _dio.get(
        '${AppConstants.childDetailEndpoint}/$childId',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      print('API Error: $e');
      throw Exception('Failed to fetch child details: ${e.message}');
    }
  }

  /// Create referral
  Future<Map<String, dynamic>> createReferral(Map<String, dynamic> referralData) async {
    try {
      final response = await _dio.post(
        AppConstants.referralEndpoint,
        data: referralData,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      print('API Error: $e');
      throw Exception('Referral creation failed: ${e.message}');
    }
  }

}
