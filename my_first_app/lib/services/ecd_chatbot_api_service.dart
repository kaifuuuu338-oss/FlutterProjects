import 'package:dio/dio.dart';
import 'package:my_first_app/core/constants/app_constants.dart';

class EcdChatbotApiService {
  EcdChatbotApiService();

  List<String> _candidateBaseUrls() {
    final urls = <String>[AppConstants.baseUrl];
    if (AppConstants.baseUrl.contains('127.0.0.1:8001')) {
      urls.add(
        AppConstants.baseUrl.replaceFirst('127.0.0.1:8001', '127.0.0.1:8000'),
      );
    } else if (AppConstants.baseUrl.contains('127.0.0.1:8000')) {
      urls.add(
        AppConstants.baseUrl.replaceFirst('127.0.0.1:8000', '127.0.0.1:8001'),
      );
    }
    return urls.toSet().toList();
  }

  Dio _dioForBaseUrl(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConstants.apiTimeout,
        receiveTimeout: AppConstants.apiTimeout,
        contentType: 'application/json',
      ),
    );
  }

  Future<Map<String, dynamic>> _requestJson({
    required String method,
    required String path,
    Object? data,
  }) async {
    DioException? lastError;
    final tried = <String>[];

    for (final baseUrl in _candidateBaseUrls()) {
      tried.add(baseUrl);
      final client = _dioForBaseUrl(baseUrl);
      try {
        final response = await client.request(
          path,
          data: data,
          options: Options(method: method),
        );
        return response.data as Map<String, dynamic>;
      } on DioException catch (e) {
        lastError = e;
        // If server responded, surface that HTTP error immediately instead
        // of masking it with a fallback host retry.
        if (e.response?.statusCode != null) {
          throw Exception('${_formatDioError(e)} (tried: ${tried.join(', ')})');
        }
      }
    }

    if (lastError != null) {
      throw Exception(
        '${_formatDioError(lastError)} (tried: ${tried.join(', ')})',
      );
    }
    throw Exception('Unknown network error (tried: ${tried.join(', ')})');
  }

  String _formatDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    String? detail;

    if (responseData is Map<String, dynamic>) {
      detail =
          responseData['detail']?.toString() ??
          responseData['message']?.toString() ??
          responseData['error']?.toString();
    } else if (responseData is String && responseData.trim().isNotEmpty) {
      detail = responseData.trim();
    }

    if (statusCode != null && detail != null && detail.isNotEmpty) {
      return 'HTTP $statusCode: $detail';
    }
    if (statusCode != null) {
      return 'HTTP $statusCode';
    }
    return error.message ?? 'Network error';
  }

  Future<Map<String, dynamic>> registerChild({
    required String childId,
    required DateTime dateOfBirth,
    List<String> birthHistory = const [],
    List<String> healthHistory = const [],
  }) async {
    final payload = {
      'child_id': childId,
      'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
      'birth_history': birthHistory,
      'health_history': healthHistory,
    };

    try {
      return await _requestJson(
        method: 'POST',
        path: '/api/child/register',
        data: payload,
      );
    } catch (e) {
      throw Exception('Child chatbot registration failed: $e');
    }
  }

  Future<Map<String, dynamic>> getMilestones(String childId) async {
    try {
      return await _requestJson(
        method: 'GET',
        path: '/api/milestones/$childId',
      );
    } catch (e) {
      throw Exception('Milestone fetch failed: $e');
    }
  }

  Future<Map<String, dynamic>> submitDomainResponses({
    required String childId,
    required Map<String, List<int>> responses,
    bool useLlm = true,
  }) async {
    final payload = {
      'child_id': childId,
      'responses': responses,
      'use_llm': useLlm,
    };

    try {
      return await _requestJson(
        method: 'POST',
        path: '/api/domain/submit',
        data: payload,
      );
    } catch (e) {
      throw Exception('Domain submit failed: $e');
    }
  }

  Future<Map<String, dynamic>> saveProgress({
    required String childId,
    required Map<String, dynamic> responses,
    String? currentDomain,
    int? currentQuestionIndex,
    bool completed = false,
  }) async {
    final payload = {
      'child_id': childId,
      'responses': responses,
      'current_domain': currentDomain,
      'current_question_index': currentQuestionIndex,
      'completed': completed,
    };

    try {
      return await _requestJson(
        method: 'POST',
        path: '/api/domain/progress',
        data: payload,
      );
    } catch (e) {
      throw Exception('Progress save failed: $e');
    }
  }

  Future<Map<String, dynamic>> getProgress(String childId) async {
    try {
      return await _requestJson(
        method: 'GET',
        path: '/api/domain/progress/$childId',
      );
    } catch (e) {
      throw Exception('Progress fetch failed: $e');
    }
  }

  Future<Map<String, dynamic>> startAdaptiveSession({
    required String childId,
    String? dateOfBirth,
    int? ageMonths,
    double? weightKg,
    double? heightCm,
    Map<String, dynamic> basicDetails = const {},
    List<String> birthHistory = const [],
    List<String> healthHistory = const [],
  }) async {
    final payload = {
      'child_id': childId,
      'date_of_birth': dateOfBirth,
      'age_months': ageMonths,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'basic_details': basicDetails,
      'birth_history': birthHistory,
      'health_history': healthHistory,
    };

    try {
      return await _requestJson(
        method: 'POST',
        path: '/api/chat/session/start',
        data: payload,
      );
    } catch (e) {
      throw Exception('Adaptive session start failed: $e');
    }
  }

  Future<Map<String, dynamic>> getAdaptiveSession(String sessionId) async {
    final safeId = sessionId.trim();
    if (safeId.isEmpty) {
      throw Exception('Adaptive session id is required');
    }
    try {
      return await _requestJson(
        method: 'GET',
        path: '/api/chat/session/$safeId',
      );
    } catch (e) {
      throw Exception('Adaptive session fetch failed: $e');
    }
  }

  Future<Map<String, dynamic>> answerAdaptiveSession({
    required String sessionId,
    required String questionId,
    required dynamic answer,
    bool useLlm = true,
  }) async {
    final safeSessionId = sessionId.trim();
    final safeQuestionId = questionId.trim();
    if (safeSessionId.isEmpty) {
      throw Exception('Adaptive session id is required');
    }
    if (safeQuestionId.isEmpty) {
      throw Exception('Adaptive question id is required');
    }
    final payload = {
      'question_id': safeQuestionId,
      'answer': answer,
      'use_llm': useLlm,
    };
    try {
      return await _requestJson(
        method: 'POST',
        path: '/api/chat/session/$safeSessionId/answer',
        data: payload,
      );
    } catch (e) {
      throw Exception('Adaptive answer submit failed: $e');
    }
  }
}
