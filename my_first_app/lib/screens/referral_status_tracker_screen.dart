import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_first_app/services/referral_api_service.dart';

class ReferralStatusTrackerScreen extends StatefulWidget {
  final String childId;
  final int referralId;
  final String riskCategory; // LOW / MEDIUM / HIGH
  final String urgency; // ROUTINE / PRIORITY / IMMEDIATE
  final String facilityType;
  final String? reason;
  final ReferralApiService apiService;

  const ReferralStatusTrackerScreen({
    super.key,
    required this.childId,
    required this.referralId,
    required this.riskCategory,
    required this.urgency,
    required this.facilityType,
    this.reason,
    required this.apiService,
  });

  @override
  State<ReferralStatusTrackerScreen> createState() =>
      _ReferralStatusTrackerScreenState();
}

class _ReferralStatusTrackerScreenState
    extends State<ReferralStatusTrackerScreen> {
  late ReferralStatusTrackerViewModel _viewModel;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewModel = ReferralStatusTrackerViewModel(
      apiService: widget.apiService,
      referralId: widget.referralId,
      childId: widget.childId,
    );
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    try {
      setState(() => _isLoading = true);
      await _viewModel.loadReferral();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      setState(() => _isLoading = true);
      await _viewModel.updateStatus(
        newStatus,
        appointmentDate: newStatus == 'SCHEDULED'
            ? DateTime.now().toString().split(' ')[0]
            : null,
      );
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _escalate() async {
    try {
      setState(() => _isLoading = true);
      await _viewModel.escalate();
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral escalated successfully')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Status Tracker'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Error message
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.red[100],
                      child: Text(
                        'Error: $_errorMessage',
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ),

                  // Main referral card
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with urgency badge
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
                                _buildUrgencyBadge(widget.urgency),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Facility information
                            _buildInfoRow(
                              'Facility',
                              widget.facilityType,
                              Icons.local_hospital,
                            ),
                            const SizedBox(height: 12),

                            // Risk category
                            _buildInfoRow(
                              'Risk Category',
                              widget.riskCategory,
                              Icons.warning,
                              color: _getRiskColor(widget.riskCategory),
                            ),
                            const SizedBox(height: 12),

                            // Reason
                            if (widget.reason != null)
                              Column(
                                children: [
                                  _buildInfoRow(
                                    'Reason',
                                    widget.reason!,
                                    Icons.description,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // Deadline
                            _buildInfoRow(
                              'Follow-up Deadline',
                              _viewModel.referral?['follow_up_deadline'] ?? 'N/A',
                              Icons.calendar_today,
                            ),
                            const SizedBox(height: 12),

                            // Current status
                            _buildInfoRow(
                              'Current Status',
                              _viewModel.referral?['status'] ?? 'PENDING',
                              Icons.info,
                            ),
                            const SizedBox(height: 12),

                            // Escalation level if applicable
                            if (_viewModel.referral?['escalation_level'] != null &&
                                _viewModel.referral?['escalation_level'] > 0)
                              _buildInfoRow(
                                'Escalation Level',
                                '${_viewModel.referral?['escalation_level']} - ${_viewModel.referral?['escalated_to'] ?? 'N/A'}',
                                Icons.trending_up,
                                color: Colors.orange,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const Text(
                          'Update Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildActionButtons(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // Status history
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatusHistory(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildInfoRow(String label, String value, IconData icon,
      {Color? color}) {
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
                value,
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

  Widget _buildActionButtons() {
    final status = _viewModel.referral?['status'] ?? 'PENDING';
    final buttons = <Widget>[];

    // Determine which buttons should be enabled based on status
    if (status == 'PENDING' || status == 'MISSED') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateStatus('SCHEDULED'),
            icon: const Icon(Icons.calendar_today),
            label: const Text('Schedule'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ),
      );
      buttons.add(const SizedBox(width: 8));
    }

    if (status == 'SCHEDULED') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateStatus('COMPLETED'),
            icon: const Icon(Icons.check_circle),
            label: const Text('Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ),
      );
      buttons.add(const SizedBox(width: 8));
    }

    if (status == 'PENDING' || status == 'SCHEDULED') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateStatus('MISSED'),
            icon: const Icon(Icons.close),
            label: const Text('Mark Missed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ),
      );
    }

    if (status == 'MISSED' && buttons.length < 3) {
      buttons.add(const SizedBox(width: 8));
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _escalate,
            icon: const Icon(Icons.trending_up),
            label: const Text('Escalate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const Text('No actions available for this status');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }

  Widget _buildStatusHistory() {
    final history = _viewModel.referral?['history'] as List? ?? [];

    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No status history yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.left(
                color: Colors.blue,
                width: 4,
              ),
              color: Colors.grey[50],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item['old_status']} → ${item['new_status']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      item['changed_on'] ?? 'N/A',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (item['remarks'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item['remarks'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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

class ReferralStatusTrackerViewModel {
  final ReferralApiService apiService;
  final int referralId;
  final String childId;

  Map<String, dynamic>? _referral;

  ReferralStatusTrackerViewModel({
    required this.apiService,
    required this.referralId,
    required this.childId,
  });

  Map<String, dynamic>? get referral => _referral;

  Future<void> loadReferral() async {
    final data = await apiService.getReferral(referralId);
    _referral = data;
  }

  Future<void> updateStatus(String newStatus,
      {String? appointmentDate}) async {
    await apiService.updateStatus(
      referralId: referralId,
      status: newStatus,
      appointmentDate: appointmentDate,
    );
    await loadReferral();
  }

  Future<void> escalate() async {
    await apiService.escalate(referralId: referralId);
    await loadReferral();
  }
}
