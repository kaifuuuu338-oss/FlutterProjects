import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

// Models
class InterventionPhase {
  final String phaseId;
  final String childId;
  final String domain;
  final String severity;
  final double baselineDelay;
  final DateTime startDate;
  final DateTime reviewDate;
  final String status; // ACTIVE, COMPLETED, ESCALATED
  final int activitiesCount;
  final double compliance;

  InterventionPhase({
    required this.phaseId,
    required this.childId,
    required this.domain,
    required this.severity,
    required this.baselineDelay,
    required this.startDate,
    required this.reviewDate,
    required this.status,
    required this.activitiesCount,
    required this.compliance,
  });

  factory InterventionPhase.fromJson(Map<String, dynamic> json) {
    return InterventionPhase(
      phaseId: json['phase_id'] ?? '',
      childId: json['child_id'] ?? '',
      domain: json['domain'] ?? '',
      severity: json['severity'] ?? '',
      baselineDelay: (json['baseline_delay'] ?? 0.0).toDouble(),
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      reviewDate: DateTime.parse(json['review_date'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'ACTIVE',
      activitiesCount: json['activities_count'] ?? 0,
      compliance: (json['compliance'] ?? 0.0).toDouble(),
    );
  }
}

class ReviewDecision {
  final String reviewId;
  final double compliance;
  final double improvement;
  final String decision; // CONTINUE, INTENSIFY, ESCALATE
  final String reason;
  final int reviewCount;

  ReviewDecision({
    required this.reviewId,
    required this.compliance,
    required this.improvement,
    required this.decision,
    required this.reason,
    required this.reviewCount,
  });

  factory ReviewDecision.fromJson(Map<String, dynamic> json) {
    return ReviewDecision(
      reviewId: json['review_id'] ?? '',
      compliance: (json['compliance'] ?? 0.0).toDouble(),
      improvement: (json['improvement'] ?? 0.0).toDouble(),
      decision: json['decision'] ?? 'CONTINUE',
      reason: json['reason'] ?? '',
      reviewCount: json['review_count'] ?? 0,
    );
  }
}

// Exception
class InterventionException implements Exception {
  final String message;
  InterventionException(this.message);

  @override
  String toString() => message;
}

// Services
class InterventionService {
  final Dio dio;
  final String baseUrl = 'http://127.0.0.1:8000';

  InterventionService(this.dio);

  Future<InterventionPhase> createPhase({
    required String childId,
    required String domain,
    required String severity,
    required int baselineDelayMonths,
    required int ageMonths,
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/intervention/plan/create',
        data: {
          'child_id': childId,
          'domain': domain,
          'risk_level': severity,
          'baseline_delay_months': baselineDelayMonths,
          'age_months': ageMonths,
        },
      );

      if (response.statusCode == 200) {
        return InterventionPhase.fromJson(response.data);
      } else {
        throw InterventionException('Failed to create phase: ${response.statusCode}');
      }
    } catch (e) {
      throw InterventionException('Error creating phase: $e');
    }
  }

  Future<InterventionPhase> getPhaseStatus(String phaseId) async {
    try {
      final response = await dio.get(
        '$baseUrl/intervention/$phaseId/status',
      );

      if (response.statusCode == 200) {
        return InterventionPhase.fromJson(response.data);
      } else {
        throw InterventionException('Failed to get phase status: ${response.statusCode}');
      }
    } catch (e) {
      throw InterventionException('Error getting phase status: $e');
    }
  }

  Future<ReviewDecision> runReview({
    required String phaseId,
    required double currentDelayMonths,
    String notes = '',
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/intervention/$phaseId/review',
        data: {
          'phase_id': phaseId,
          'current_delay_months': currentDelayMonths,
          'notes': notes,
        },
      );

      if (response.statusCode == 200) {
        // The response contains review_decision nested
        return ReviewDecision.fromJson(response.data['review_decision'] ?? response.data);
      } else {
        throw InterventionException('Failed to run review: ${response.statusCode}');
      }
    } catch (e) {
      throw InterventionException('Error running review: $e');
    }
  }

  Future<void> completePhase({
    required String phaseId,
    String closureStatus = 'success',
    String notes = '',
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/intervention/$phaseId/complete',
        data: {
          'closure_status': closureStatus,
          'final_notes': notes,
        },
      );

      if (response.statusCode != 200) {
        throw InterventionException('Failed to complete phase: ${response.statusCode}');
      }
    } catch (e) {
      throw InterventionException('Error completing phase: $e');
    }
  }
}

// Providers
final dioProvider = Provider((ref) => Dio());

final interventionServiceProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return InterventionService(dio);
});

// State for current active phase
final activePhaseProvider = StateProvider<InterventionPhase?>((ref) => null);

// Async providers
final phaseStatusProvider = FutureProvider.family<InterventionPhase, String>(
  (ref, phaseId) async {
    final service = ref.watch(interventionServiceProvider);
    return service.getPhaseStatus(phaseId);
  },
);

final createPhaseProvider = FutureProvider.family<InterventionPhase, Map<String, dynamic>>(
  (ref, params) async {
    final service = ref.watch(interventionServiceProvider);
    final result = await service.createPhase(
      childId: params['childId'],
      domain: params['domain'],
      severity: params['severity'],
      baselineDelayMonths: params['baselineDelayMonths'],
      ageMonths: params['ageMonths'],
    );
    
    // Set as active phase
    ref.read(activePhaseProvider.notifier).state = result;
    
    return result;
  },
);

final reviewDecisionProvider = FutureProvider.family<ReviewDecision, Map<String, dynamic>>(
  (ref, params) async {
    final service = ref.watch(interventionServiceProvider);
    return service.runReview(
      phaseId: params['phaseId'],
      currentDelayMonths: params['currentDelayMonths'],
      notes: params['notes'] ?? '',
    );
  },
);
