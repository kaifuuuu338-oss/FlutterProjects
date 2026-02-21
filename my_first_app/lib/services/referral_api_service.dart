import 'package:dio/dio.dart';
import 'package:my_first_app/models/referral_model.dart';

class ReferralApiService {
  final Dio _dio;
  final String baseUrl;

  ReferralApiService({
    required this.baseUrl,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.headers = {
      'Content-Type': 'application/json',
    };
  }

  /// Create a referral for a child based on risk profile
  Future<Map<String, dynamic>> createReferral({
    required String childId,
    required String riskCategory, // LOW / MEDIUM / HIGH
    int domainsDelayed = 0,
    String? autismRisk,
    String? adhdRisk,
    String? behavioralRisk,
    String? nutritionRisk,
  }) async {
    try {
      final response = await _dio.post(
        '/referral/create',
        data: {
          'child_id': childId,
          'risk_category': riskCategory,
          'domains_delayed': domainsDelayed,
          'autism_risk': autismRisk,
          'adhd_risk': adhdRisk,
          'behavioral_risk': behavioralRisk,
          'nutrition_risk': nutritionRisk,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get active referral for a child
  Future<Map<String, dynamic>> getActiveReferral(String childId) async {
    try {
      final response = await _dio.get(
        '/referral/by-child/$childId',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {};
      }
      throw _handleError(e);
    }
  }

  /// Get referral by ID
  Future<Map<String, dynamic>> getReferral(int referralId) async {
    try {
      final response = await _dio.get(
        '/referral/$referralId',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update referral status
  Future<Map<String, dynamic>> updateStatus({
    required int referralId,
    required String status, // SCHEDULED / COMPLETED / MISSED / ESCALATED
    String? appointmentDate,
    String? workerId,
    String? remarks,
  }) async {
    try {
      final response = await _dio.post(
        '/referral/$referralId/status',
        data: {
          'status': status,
          'appointment_date': appointmentDate,
          'worker_id': workerId,
          'remarks': remarks,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Escalate referral to next level
  Future<Map<String, dynamic>> escalate({
    required int referralId,
    String? workerId,
  }) async {
    try {
      final response = await _dio.post(
        '/referral/$referralId/escalate',
        data: {
          'worker_id': workerId,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Override facility
  Future<Map<String, dynamic>> overrideFacility({
    required int referralId,
    required String newFacility,
    required String overrideReason,
    String? workerId,
  }) async {
    try {
      final response = await _dio.post(
        '/referral/$referralId/override-facility',
        data: {
          'new_facility': newFacility,
          'override_reason': overrideReason,
          'worker_id': workerId,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get status history
  Future<Map<String, dynamic>> getStatusHistory(int referralId) async {
    try {
      final response = await _dio.get(
        '/referral/$referralId/history',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      final message = error.response?.data['detail'] ?? 
                     error.response?.data['message'] ?? 
                     'Unknown error';
      return message.toString();
    } else if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      return 'Receive timeout';
    } else {
      return error.message ?? 'Unknown error occurred';
    }
  }
}
