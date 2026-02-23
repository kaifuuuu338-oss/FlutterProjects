import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class ReferralDecisionScreen extends StatefulWidget {
  final String childId;
  final String baseUrl;

  const ReferralDecisionScreen({
    super.key,
    required this.childId,
    this.baseUrl = 'http://127.0.0.1:8000',
  });

  @override
  State<ReferralDecisionScreen> createState() => _ReferralDecisionScreenState();
}

class _ReferralDecisionScreenState extends State<ReferralDecisionScreen> {
  late Dio _dio;
  late ReferralData _referralData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: widget.baseUrl,
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));
    _loadReferral();
  }

  Future<void> _loadReferral() async {
    try {
      setState(() => _isLoading = true);
      
      // Fetch referral from child_id
      final response = await _dio.get(
        '/referral/by-child/${widget.childId}',
      );

      setState(() {
        _referralData = ReferralData.fromJson(response.data);
        _isLoading = false;
        _errorMessage = null;
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _extractErrorMessage(e);
      });
    }
  }

  Future<void> _updateStatus(String newStatus, {String? appointmentDate}) async {
    try {
      setState(() => _isUpdating = true);

      await _dio.put(
        '/referral/${_referralData.referralId}/status',
        data: {
          'status': newStatus,
          'appointment_date': appointmentDate,
        },
      );

      // Reload referral data
      await _loadReferral();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${_extractErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _escalate() async {
    try {
      setState(() => _isUpdating = true);

      await _dio.post(
        '/referral/${_referralData.referralId}/escalate',
      );

      await _loadReferral();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral escalated successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${_extractErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  String _extractErrorMessage(DioException error) {
    if (error.response != null) {
      return error.response?.data['detail'] ?? 'Request failed';
    }
    return error.message ?? 'Unknown error occurred';
  }

  bool _isOverdue() {
    final deadline = DateTime.parse(_referralData.followUpDeadline);
    return DateTime.now().isAfter(deadline) && 
           _referralData.status != 'COMPLETED';
  }

  int _daysUntilDeadline() {
    final deadline = DateTime.parse(_referralData.followUpDeadline);
    return deadline.difference(DateTime.now()).inDays;
  }

  bool _canSchedule() =>
      _referralData.status == 'PENDING' || _referralData.status == 'MISSED';

  bool _canComplete() => _referralData.status == 'SCHEDULED';

  bool _canMiss() =>
      _referralData.status == 'PENDING' || _referralData.status == 'SCHEDULED';

  bool _canEscalate() => _referralData.status == 'MISSED' || _isOverdue();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Decision & Status Tracker'),
        elevation: 0,
        backgroundColor: Colors.blue[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Error message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[400]!),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[900]),
                        ),
                      ),

                    // Referral decision card
                    _buildReferralDecisionCard(),
                    const SizedBox(height: 20),

                    // Action buttons
                    _buildActionButtons(),
                    const SizedBox(height: 20),

                    // Status history
                    _buildStatusHistorySection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReferralDecisionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Referral Decision',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildUrgencyBadge(_referralData.urgency),
              ],
            ),
            const SizedBox(height: 16),

            // Overdue warning
            if (_isOverdue())
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: const Border(
                    left: BorderSide(
                      color: Colors.red,
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'OVERDUE: Follow-up deadline has passed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Facility
            _buildInfoRow(
              'Facility',
              _referralData.facility,
              Icons.local_hospital,
            ),
            const SizedBox(height: 12),

            // Reason
            _buildInfoRow(
              'Reason',
              _referralData.reason ?? 'N/A',
              Icons.description,
            ),
            const SizedBox(height: 12),

            // Risk category
            _buildInfoRow(
              'Risk Category',
              _referralData.riskCategory,
              Icons.warning,
              color: _getRiskColor(_referralData.riskCategory),
            ),
            const SizedBox(height: 12),

            // Status
            _buildInfoRow(
              'Current Status',
              _referralData.status,
              Icons.info,
            ),
            const SizedBox(height: 12),

            // Deadline
            _buildInfoRow(
              'Follow-up Deadline',
              _referralData.followUpDeadline,
              Icons.calendar_today,
              suffix: _isOverdue()
                  ? ' (${_daysUntilDeadline()} days overdue)'
                  : ' (${_daysUntilDeadline()} days remaining)',
            ),
            const SizedBox(height: 12),

            // Escalation level
            if (_referralData.escalationLevel > 0)
              _buildInfoRow(
                'Escalation Level',
                '${_referralData.escalationLevel} - ${_referralData.escalatedTo ?? 'N/A'}',
                Icons.trending_up,
                color: Colors.orange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Update Status',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (_canSchedule())
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating
                        ? null
                        : () => _updateStatus(
                              'SCHEDULED',
                              appointmentDate:
                                  DateTime.now().toString().split(' ')[0],
                            ),
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Schedule'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (_canComplete())
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating
                        ? null
                        : () => _updateStatus('COMPLETED'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (_canMiss())
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating
                        ? null
                        : () => _updateStatus('MISSED'),
                    icon: const Icon(Icons.close),
                    label: const Text('Mark Missed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (_canEscalate())
                ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _escalate,
                  icon: const Icon(Icons.trending_up),
                  label: const Text('Escalate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status History & Audit Trail',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _referralData.statusHistory.length,
            itemBuilder: (context, index) {
              final item = _referralData.statusHistory[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item['old_status'] ?? 'INITIAL'} → ${item['new_status']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          item['changed_on'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (item['remarks'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        item['remarks'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (index < _referralData.statusHistory.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Divider(color: Colors.grey[300]),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
    String? suffix,
  }) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.blue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                suffix != null ? '$value$suffix' : value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUrgencyBadge(String urgency) {
    Color bgColor;
    Color textColor = Colors.white;

    switch (urgency.toUpperCase()) {
      case 'IMMEDIATE':
        bgColor = Colors.red;
        break;
      case 'PRIORITY':
        bgColor = Colors.orange;
        break;
      case 'ROUTINE':
        bgColor = Colors.green;
        break;
      default:
        bgColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        urgency.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'LOW':
        return Colors.green;
      case 'MEDIUM':
        return Colors.orange;
      case 'HIGH':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class ReferralData {
  final dynamic referralId; // Can be string or int
  final String childId;
  final String riskCategory;
  final String facility;
  final String urgency;
  final String status;
  final String? reason;
  final String followUpDeadline;
  final int escalationLevel;
  final String? escalatedTo;
  final List<Map<String, dynamic>> statusHistory;

  ReferralData({
    required this.referralId,
    required this.childId,
    required this.riskCategory,
    required this.facility,
    required this.urgency,
    required this.status,
    this.reason,
    required this.followUpDeadline,
    this.escalationLevel = 0,
    this.escalatedTo,
    this.statusHistory = const [],
  });

  factory ReferralData.fromJson(Map<String, dynamic> json) {
    // Normalize status from backend format to uppercase
    String normalizeStatus(dynamic status) {
      if (status == null) return 'PENDING';
      String s = status.toString().toUpperCase().trim();
      if (s.contains('APPOINTMENT') || s.contains('SCHEDULED')) return 'SCHEDULED';
      if (s == 'UNDER TREATMENT' || s == 'VISITED') return 'VISITED';
      if (s == 'COMPLETED') return 'COMPLETED';
      if (s == 'MISSED') return 'MISSED';
      if (s == 'PENDING') return 'PENDING';
      return 'PENDING';
    }

    return ReferralData(
      referralId: json['referral_id'], // Keep as-is (string or int)
      childId: json['child_id'] ?? '',
      riskCategory: json['risk_category'] ?? 'UNKNOWN',
      facility: json['facility'] ?? 'Not specified',
      urgency: json['urgency'] ?? 'NORMAL',
      status: normalizeStatus(json['status']),
      reason: json['reason'],
      followUpDeadline: json['followup_by'] ?? json['follow_up_deadline'] ?? DateTime.now().toString(),
      escalationLevel: json['escalation_level'] ?? 0,
      escalatedTo: json['escalated_to'],
      statusHistory: _extractStatusHistory(json),
    );
  }

  static List<Map<String, dynamic>> _extractStatusHistory(Map<String, dynamic> json) {
    if (json['status_history'] is List) {
      return List<Map<String, dynamic>>.from(json['status_history']);
    }
    return [];
  }
}
