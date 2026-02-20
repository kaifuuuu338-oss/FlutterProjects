import 'package:dio/dio.dart';
import 'package:my_first_app/core/constants/app_constants.dart';
import 'package:my_first_app/models/child_model.dart';
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
      throw Exception('Screening submission failed: ${e.message}');
    }
  }

  /// Register/upsert child profile in backend source DB.
  Future<Map<String, dynamic>> registerChild(ChildModel child) async {
    try {
      final response = await _dio.post(
        AppConstants.childRegisterEndpoint,
        data: {
          'child_id': child.childId,
          'child_name': child.childName,
          'gender': child.gender,
          'age_months': child.ageMonths,
          'awc_id': child.awcCode,
          'sector_id': '',
          'mandal_id': child.mandal,
          'district_id': child.district,
          'created_at': child.createdAt.toIso8601String(),
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Child registration sync failed: ${e.message}');
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
      throw Exception('Referral creation failed: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> generateProblemBInterventionPlan(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('/problem-b/intervention-plan', data: payload);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Problem B intervention generation failed: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getProblemBTrend({
    required int baselineDelay,
    required int followupDelay,
  }) async {
    try {
      final response = await _dio.post(
        '/problem-b/trend',
        data: {
          'baseline_delay': baselineDelay,
          'followup_delay': followupDelay,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Problem B trend calculation failed: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> adjustProblemBIntensity({
    required String currentIntensity,
    required String trend,
    required int delayReduction,
  }) async {
    try {
      final response = await _dio.post(
        '/problem-b/adjust-intensity',
        data: {
          'current_intensity': currentIntensity,
          'trend': trend,
          'delay_reduction': delayReduction,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Problem B intensity adjustment failed: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getProblemBRules() async {
    try {
      final response = await _dio.get('/problem-b/rules');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Problem B rules fetch failed: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getProblemBSchema() async {
    try {
      final response = await _dio.get('/problem-b/schema');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Problem B schema fetch failed: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> generateProblemBActivities(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('/problem-b/activities/generate', data: payload);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Problem B activity generation failed: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getProblemBActivities(String childId) async {
    try {
      final response = await _dio.get('/problem-b/activities/$childId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Problem B activities fetch failed: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> markProblemBActivityStatus({
    required String childId,
    required String activityId,
    required String status,
  }) async {
    try {
      final response = await _dio.post(
        '/problem-b/activities/mark-status',
        data: {
          'child_id': childId,
          'activity_id': activityId,
          'status': status,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Problem B activity status update failed: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getProblemBCompliance(String childId) async {
    try {
      final response = await _dio.get('/problem-b/compliance/$childId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Problem B compliance fetch failed: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> resetProblemBFrequency({
    required String childId,
    required String frequencyType,
  }) async {
    try {
      final response = await _dio.post(
        '/problem-b/activities/reset-frequency',
        data: {
          'child_id': childId,
          'frequency_type': frequencyType,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Problem B frequency reset failed: ${e.message}');
    }
  }

}
