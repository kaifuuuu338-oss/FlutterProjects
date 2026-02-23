import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class FollowUpScreen extends StatefulWidget {
  final String childId;
  final String referralId;
  final String baseUrl;
  final String userRole; // AWW or CAREGIVER

  const FollowUpScreen({
    super.key,
    required this.childId,
    required this.referralId,
    this.baseUrl = 'http://127.0.0.1:8000',
    this.userRole = 'AWW',
  });

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
  late Dio _dio;
  late FollowUpData _followUpData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: widget.baseUrl,
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    _loadFollowUp();
  }

  Future<void> _loadFollowUp() async {
    try {
      setState(() => _isLoading = true);

      final response = await _dio.get('/follow-up/${widget.referralId}');
      setState(() {
        _followUpData = FollowUpData.fromJson(response.data);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load follow-up data: $e';
      });
    }
  }

  Future<void> _completeActivity(Activity activity) async {
    try {
      await _dio.post(
        '/follow-up/${widget.referralId}/activity/${activity.id}/complete',
        data: {'remarks': 'Completed by ${widget.userRole}'},
      );

      // Refresh data
      _loadFollowUp();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${activity.title} marked complete'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark activity: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getDaysText() {
    if (_followUpData.daysRemaining > 0) {
      return 'in ${_followUpData.daysRemaining} days';
    } else if (_followUpData.daysRemaining == 0) {
      return 'Today';
    } else {
      return '${_followUpData.daysRemaining.abs()} days overdue';
    }
  }

  Color _getUrgencyColor() {
    switch (_followUpData.urgency.toUpperCase()) {
      case 'IMMEDIATE':
      case 'CRITICAL':
        return Colors.red;
      case 'PRIORITY':
      case 'HIGH':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        title: const Text('Follow-Up & Home Activities'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFollowUp,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Referral Summary Card
                      _buildReferralSummaryCard(),
                      const SizedBox(height: 24),

                      // Section 2: Progress Indicator
                      _buildProgressIndicator(),
                      const SizedBox(height: 24),

                      // Section 3: Caregiver Activities
                      _buildCaregiverActivitiesSection(),
                      const SizedBox(height: 24),

                      // Section 4: AWW Action Plan (only for AWW)
                      if (widget.userRole == 'AWW') ...[
                        _buildAWWActionPlanSection(),
                        const SizedBox(height: 24),
                      ],

                      // Section 5: Status & Escalation
                      _buildStatusSection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  // Section 1: Referral Summary Card
  Widget _buildReferralSummaryCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Referral Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getUrgencyColor(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _followUpData.urgency,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Facility', _followUpData.facility),
            _buildInfoRow('Status', _followUpData.status),
            _buildInfoRow('Deadline', _getDaysText()),
            const SizedBox(height: 12),
            // Overdue warning
            if (_followUpData.isOverdue)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'OVERDUE: Action required! This referral is ${_followUpData.daysRemaining.abs()} days past deadline.',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Progress Indicator
  Widget _buildProgressIndicator() {
    double progress = _followUpData.totalActivities > 0
        ? _followUpData.completedActivities / _followUpData.totalActivities
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Follow-Up Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_followUpData.completedActivities}/${_followUpData.totalActivities} Activities',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress < 0.5
                      ? Colors.orange
                      : progress < 0.8
                          ? Colors.amber
                          : Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section 3: Caregiver Activities
  Widget _buildCaregiverActivitiesSection() {
    final caregiverActivities = _followUpData.activities
        .where((a) => a.targetUser == 'CAREGIVER')
        .toList();

    if (caregiverActivities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏠 Home Activities for Caregiver',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: caregiverActivities.length,
          itemBuilder: (context, index) {
            final activity = caregiverActivities[index];
            return _buildActivityCard(activity);
          },
        ),
      ],
    );
  }

  // Activity Card
  Widget _buildActivityCard(Activity activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: activity.completed,
                  onChanged: activity.completed
                      ? null
                      : (_) => _completeActivity(activity),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    activity.domain,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    activity.frequency,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                if (activity.completed) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Completed',
                    style: TextStyle(fontSize: 11, color: Colors.green[700]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Section 4: AWW Action Plan
  Widget _buildAWWActionPlanSection() {
    final awwActivities =
        _followUpData.activities.where((a) => a.targetUser == 'AWW').toList();

    if (awwActivities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '👨‍⚕️ AWW Action Plan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: awwActivities.length,
          itemBuilder: (context, index) {
            final activity = awwActivities[index];
            return _buildActivityCard(activity);
          },
        ),
      ],
    );
  }

  // Section 5: Status & Escalation
  Widget _buildStatusSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Referral Status & Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Status: ${_followUpData.status}'),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusIcon(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_followUpData.isOverdue)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Escalation pending: This referral is overdue',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            if (_followUpData.escalationLevel > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Escalation Level: ${_followUpData.escalationLevel}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Escalated to: ${_followUpData.escalatedTo ?? 'N/A'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method to show info row
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Color _statusColor() {
    switch (_followUpData.status) {
      case 'SCHEDULED':
        return Colors.blue[100]!;
      case 'COMPLETED':
        return Colors.green[100]!;
      case 'MISSED':
        return Colors.red[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  String _statusIcon() {
    switch (_followUpData.status) {
      case 'SCHEDULED':
        return '📅 Scheduled';
      case 'COMPLETED':
        return '✅ Completed';
      case 'MISSED':
        return '❌ Missed';
      default:
        return '⏳ Pending';
    }
  }
}

// Data Models
class FollowUpData {
  final String referralId;
  final String childId;
  final String facility;
  final String urgency;
  final String status;
  final String createdOn;
  final String deadline;
  final int daysRemaining;
  final bool isOverdue;
  final int escalationLevel;
  final String? escalatedTo;
  final List<Activity> activities;
  final int totalActivities;
  final int completedActivities;

  FollowUpData({
    required this.referralId,
    required this.childId,
    required this.facility,
    required this.urgency,
    required this.status,
    required this.createdOn,
    required this.deadline,
    required this.daysRemaining,
    required this.isOverdue,
    required this.escalationLevel,
    this.escalatedTo,
    required this.activities,
    required this.totalActivities,
    required this.completedActivities,
  });

  factory FollowUpData.fromJson(Map<String, dynamic> json) {
    final activitiesList = (json['activities'] as List?)
            ?.map((a) => Activity.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];

    return FollowUpData(
      referralId: json['referral_id'] ?? '',
      childId: json['child_id'] ?? '',
      facility: json['facility'] ?? 'Not specified',
      urgency: json['urgency'] ?? 'NORMAL',
      status: json['status'] ?? 'PENDING',
      createdOn: json['created_on'] ?? '',
      deadline: json['deadline'] ?? '',
      daysRemaining: json['days_remaining'] ?? 0,
      isOverdue: json['is_overdue'] ?? false,
      escalationLevel: json['escalation_level'] ?? 0,
      escalatedTo: json['escalated_to'],
      activities: activitiesList,
      totalActivities: json['total_activities'] ?? 0,
      completedActivities: json['completed_activities'] ?? 0,
    );
  }
}

class Activity {
  final int id;
  final String targetUser;
  final String domain;
  final String title;
  final String description;
  final String frequency;
  final int durationDays;
  final bool completed;
  final String? completedOn;
  final String? remarks;

  Activity({
    required this.id,
    required this.targetUser,
    required this.domain,
    required this.title,
    required this.description,
    required this.frequency,
    required this.durationDays,
    this.completed = false,
    this.completedOn,
    this.remarks,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] ?? 0,
      targetUser: json['target_user'] ?? 'CAREGIVER',
      domain: json['domain'] ?? 'General',
      title: json['title'] ?? 'Activity',
      description: json['description'] ?? '',
      frequency: json['frequency'] ?? 'DAILY',
      durationDays: json['duration_days'] ?? 30,
      completed: (json['completed'] == true || json['completed'] == 1),
      completedOn: json['completed_on'],
      remarks: json['remarks'],
    );
  }
}
