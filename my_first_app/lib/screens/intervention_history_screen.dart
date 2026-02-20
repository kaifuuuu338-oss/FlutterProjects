import 'package:flutter/material.dart';
import 'package:my_first_app/services/api_service.dart';

class InterventionHistoryScreen extends StatefulWidget {
  final String phaseId;

  const InterventionHistoryScreen({super.key, required this.phaseId});

  @override
  State<InterventionHistoryScreen> createState() =>
      _InterventionHistoryScreenState();
}

class _InterventionHistoryScreenState extends State<InterventionHistoryScreen> {
  final APIService _api = APIService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _history = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getInterventionHistory(widget.phaseId);
      if (!mounted) return;
      setState(() => _history = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic raw) {
    final text = (raw ?? '').toString();
    if (text.contains('T')) return text.split('T').first;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final phase = Map<String, dynamic>.from(_history['phase_status'] ?? {});
    final reviews = List<Map<String, dynamic>>.from(
      (_history['reviews'] as List? ?? const []).whereType<Map>().map(
        (e) => Map<String, dynamic>.from(e),
      ),
    );
    final activities = List<Map<String, dynamic>>.from(
      (_history['activities'] as List? ?? const []).whereType<Map>().map(
        (e) => Map<String, dynamic>.from(e),
      ),
    );
    final taskLogs = List<Map<String, dynamic>>.from(
      (_history['task_logs'] as List? ?? const []).whereType<Map>().map(
        (e) => Map<String, dynamic>.from(e),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Intervention History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phase ID: ${widget.phaseId}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text('Child ID: ${phase['child_id'] ?? '-'}'),
                          Text('Domain: ${phase['domain'] ?? '-'}'),
                          Text('Severity: ${phase['severity'] ?? '-'}'),
                          Text('Status: ${phase['status'] ?? '-'}'),
                          Text(
                            'Baseline Delay: ${phase['baseline_delay'] ?? '-'}',
                          ),
                          Text('Review Date: ${_fmt(phase['review_date'])}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Review Log',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (reviews.isEmpty) const Text('No reviews yet.'),
                          for (final r in reviews)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${_fmt(r['review_date'])} | ${r['decision_action']} | Compliance ${r['compliance']} | Improvement ${r['improvement']}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Activities',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (activities.isEmpty)
                            const Text('No activities found.'),
                          for (final a in activities)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${a['role']}: ${a['name']} (${a['frequency_per_week']}/week)',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Task Logs',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (taskLogs.isEmpty) const Text('No task logs yet.'),
                          for (final t in taskLogs.take(50))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${_fmt(t['date_logged'])} | ${t['role']} | ${t['name']} | ${t['completed'] == 1 ? 'Done' : 'Missed'}',
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
}
