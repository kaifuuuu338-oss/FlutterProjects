import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

class FollowupCompleteScreen extends StatefulWidget {
  final String referralId;
  final String childId;
  final String userRole; // AWW or CAREGIVER

  const FollowupCompleteScreen({
    Key? key,
    required this.referralId,
    required this.childId,
    this.userRole = 'AWW',
  }) : super(key: key);

  @override
  State<FollowupCompleteScreen> createState() => _FollowupCompleteScreenState();
}

class _FollowupCompleteScreenState extends State<FollowupCompleteScreen> {
  late Dio _dio;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _referralData;
  List<Activity>? _activities;
  List<Activity>? _caregiverActivities;
  List<Activity>? _awwActivities;

  @override
  void initState() {
    super.initState();
    _initDio();
    _loadFollowUpData();
  }

  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:8000',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  Future<void> _loadFollowUpData() async {
    try {
      setState(() => _isLoading = true);

      final response = await _dio.get('/follow-up/${widget.referralId}');
      final data = response.data as Map<String, dynamic>;

      // Parse referral data
      _referralData = {
        'facility': data['facility'] ?? 'PHC',
        'urgency': data['urgency'] ?? 'Priority',
        'status': data['status'] ?? 'PENDING',
        'deadline': data['deadline'] ?? DateTime.now().toString().split(' ')[0],
        'days_remaining': _calculateDaysRemaining(data['deadline']),
        'is_overdue': _isOverdue(data['deadline']),
        'escalation_level': data['escalation_level'] ?? 0,
        'escalated_to': data['escalated_to'] ?? 'Unknown',
        'total_activities': data['total_activities'] ?? 0,
        'completed_activities': data['completed_activities'] ?? 0,
        'progress': data['progress'] ?? 0.0,
      };

      // Parse activities
      _activities = <Activity>[];
      if (data['activities'] is List) {
        for (final act in data['activities'] as List) {
          _activities!.add(Activity.fromJson(act as Map<String, dynamic>));
        }
      }

      // Split by target user
      _caregiverActivities = _activities!
          .where((a) => a.targetUser.toUpperCase() == 'CAREGIVER')
          .toList();
      _awwActivities =
          _activities!.where((a) => a.targetUser.toUpperCase() == 'AWW').toList();

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load follow-up: ${e.toString()}';
      });
    }
  }

  int _calculateDaysRemaining(String? deadline) {
    if (deadline == null) return 0;
    try {
      final deadlineDate = DateTime.parse(deadline);
      final today = DateTime.now();
      return deadlineDate.difference(today).inDays;
    } catch (e) {
      return 0;
    }
  }

  bool _isOverdue(String? deadline) {
    if (deadline == null) return false;
    try {
      final deadlineDate = DateTime.parse(deadline);
      return DateTime.now().isAfter(deadlineDate);
    } catch (e) {
      return false;
    }
  }

  Future<void> _completeActivity(Activity activity) async {
    try {
      await _dio.post(
        '/follow-up/${widget.referralId}/activity/${activity.id}/complete',
        data: {'remarks': 'Completed by ${widget.userRole}'},
      );

      // Reload data
      await _loadFollowUpData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity marked as completed!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Follow-Up & Home Activities'),
          backgroundColor: const Color(0xFF1565C0),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Follow-Up & Home Activities'),
          backgroundColor: const Color(0xFF1565C0),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadFollowUpData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-Up & Home Activities'),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1️⃣ REFERRAL SUMMARY CARD
            _buildReferralSummaryCard(),

            const SizedBox(height: 16),

            // 2️⃣ PROGRESS INDICATOR
            _buildProgressIndicator(),

            const SizedBox(height: 16),

            // 3️⃣ CAREGIVER ACTIVITIES
            if (_caregiverActivities!.isNotEmpty) ...[
              _buildActivitySection(
                title: 'Caregiver Activities (Home Exercises)',
                activities: _caregiverActivities!,
              ),
              const SizedBox(height: 16),
            ],

            // 4️⃣ AWW ACTION PLAN
            if (widget.userRole.toUpperCase() == 'AWW' && _awwActivities!.isNotEmpty)
              _buildActivitySection(
                title: 'AWW Action Plan (Monitoring)',
                activities: _awwActivities!,
              ),

            const SizedBox(height: 16),

            // 5️⃣ STATUS & ESCALATION
            _buildStatusAndEscalationSection(),
          ],
        ),
      ),
    );
  }

  // SECTION 1: Referral Summary
  Widget _buildReferralSummaryCard() {
    final days = _referralData!['days_remaining'] as int;
    final isOverdue = _referralData!['is_overdue'] as bool;
    int daysOverdue = 0;
    if (isOverdue) {
      daysOverdue = days.abs();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Facility: ${_referralData!['facility']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${_referralData!['status']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_referralData!['urgency']),
                  backgroundColor: _getUrgencyColor(_referralData!['urgency']),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const Divider(height: 16),
            // Deadline Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deadline',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      _referralData!['deadline'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isOverdue)
                      Text(
                        '$daysOverdue days overdue',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text(
                        '$days days remaining',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Overdue Warning
            if (isOverdue)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'OVERDUE: This referral is $daysOverdue days past deadline!',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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

  // SECTION 2: Progress Indicator
  Widget _buildProgressIndicator() {
    final progress = _referralData!['progress'] as double;
    final completed = _referralData!['completed_activities'] as int;
    final total = _referralData!['total_activities'] as int;

    Color progressColor = Colors.red;
    if (progress >= 80) {
      progressColor = Colors.green;
    } else if (progress >= 50) {
      progressColor = Colors.orange;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Activity Progress',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$completed/$total',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total > 0 ? progress / 100 : 0,
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${progress.toStringAsFixed(0)}% Complete',
              style: TextStyle(
                fontSize: 12,
                color: progressColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SECTION 3 & 4: Activities List
  Widget _buildActivitySection({
    required String title,
    required List<Activity> activities,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF243445),
          ),
        ),
        const SizedBox(height: 12),
        ...activities.map((activity) => _buildActivityCard(activity)),
      ],
    );
  }

  // Activity Card
  Widget _buildActivityCard(Activity activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Checkbox(
              value: activity.completed,
              onChanged: (_) {
                if (!activity.completed) {
                  _completeActivity(activity);
                }
              },
            ),
            // Activity Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: activity.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(
                        label: Text(activity.domain),
                        backgroundColor: Colors.blue.shade100,
                        labelStyle: TextStyle(fontSize: 10),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(activity.frequency),
                        backgroundColor: Colors.green.shade100,
                        labelStyle: TextStyle(fontSize: 10),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status Icon
            if (activity.completed)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, color: Colors.green),
              ),
          ],
        ),
      ),
    );
  }

  // SECTION 5: Status & Escalation
  Widget _buildStatusAndEscalationSection() {
    final escalationLevel = _referralData!['escalation_level'] as int;
    final escalatedTo = _referralData!['escalated_to'] as String;
    final isOverdue = _referralData!['is_overdue'] as bool;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escalation Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: escalationLevel > 0 ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level: $escalationLevel',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Escalated to: $escalatedTo',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            if (isOverdue)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: const Text(
                          'Escalation pending: This referral is overdue',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toUpperCase()) {
      case 'CRITICAL':
      case 'EMERGENCY':
        return Colors.red;
      case 'PRIORITY':
      case 'HIGH':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}

// Activity Model
class Activity {
  final int id;
  final String targetUser;
  final String domain;
  final String title;
  final String description;
  final String frequency;
  final int durationDays;
  bool completed;
  final String? completedOn;

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
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] ?? 0,
      targetUser: json['target_user'] ?? 'CAREGIVER',
      domain: json['domain'] ?? 'GM',
      title: json['activity_title'] ?? 'Activity',
      description: json['activity_description'] ?? '',
      frequency: json['frequency'] ?? 'DAILY',
      durationDays: json['duration_days'] ?? 30,
      completed: (json['completed'] ?? 0) == 1,
      completedOn: json['completed_on'],
    );
  }
}
