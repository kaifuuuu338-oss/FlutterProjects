import 'package:flutter/material.dart';
import 'package:my_first_app/services/api_service.dart';

class WeeklyProgressScreen extends StatefulWidget {
  final String planId;
  final String childId;

  const WeeklyProgressScreen({
    super.key,
    required this.planId,
    required this.childId,
  });

  @override
  State<WeeklyProgressScreen> createState() => _WeeklyProgressScreenState();
}

class _WeeklyProgressScreenState extends State<WeeklyProgressScreen> {
  late TextEditingController _awwCompletedController;
  late TextEditingController _caregiverCompletedController;
  late TextEditingController _currentDelayController;
  late TextEditingController _notesController;

  int _weekNumber = 2;
  final int _awwTotal = 5;
  final int _caregiverTotal = 5;
  double _adherence = 0.0;
  bool _isLoading = false;
  String? _decision;
  String? _decisionReason;
  final APIService _api = APIService();

  @override
  void initState() {
    super.initState();
    _awwCompletedController = TextEditingController(text: '0');
    _caregiverCompletedController = TextEditingController(text: '0');
    _currentDelayController = TextEditingController(text: '2.0');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _awwCompletedController.dispose();
    _caregiverCompletedController.dispose();
    _currentDelayController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateAdherence() {
    try {
      int awwCompleted = int.parse(_awwCompletedController.text);
      int caregiverCompleted = int.parse(_caregiverCompletedController.text);

      setState(() {
        double awwAdherence = awwCompleted / _awwTotal;
        double caregiverAdherence = caregiverCompleted / _caregiverTotal;
        _adherence = ((awwAdherence + caregiverAdherence) / 2);
      });
    } catch (e) {
      // Invalid input
    }
  }

  Future<void> _submitProgress() async {
    if (_awwCompletedController.text.isEmpty ||
        _caregiverCompletedController.text.isEmpty ||
        _currentDelayController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await _api.logInterventionProgress(
        phaseId: widget.planId,
        currentDelayMonths: double.parse(_currentDelayController.text),
        awwCompleted: int.parse(_awwCompletedController.text),
        caregiverCompleted: int.parse(_caregiverCompletedController.text),
        notes: _notesController.text,
      );
      setState(() {
        _decision =
            data['decision']?.toString() ??
            data['review_decision']?['decision']?.toString();
        _decisionReason =
            data['reason']?.toString() ??
            data['review_decision']?['reason']?.toString();
      });

      // Show success dialog
      if (!mounted) return;
      _showDecisionDialog(data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDecisionDialog(Map<String, dynamic> decision) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weekly Review Decision'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              decision['decision'] ?? 'Decision',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(decision['reason'] ?? ''),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    'Adherence: ${((((decision['adherence'] ?? decision['compliance'] ?? 0.0) as num).toDouble()) * 100).toStringAsFixed(1)}%',
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Improvement: ${(decision['improvement'] ?? decision['review_decision']?['improvement'] ?? 0)}mo',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Weekly Progress'),
        backgroundColor: const Color(0xFF6200EE),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week Selection
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Week Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _weekNumber > 1
                              ? () => setState(() => _weekNumber--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Week $_weekNumber / 8',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _weekNumber < 8
                              ? () => setState(() => _weekNumber++)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    LinearProgressIndicator(
                      value: _weekNumber / 8,
                      minHeight: 6,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6200EE),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // AWW Activities Completion
            Text(
              'AWW Activities Completion',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _awwCompletedController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateAdherence(),
                      decoration: InputDecoration(
                        labelText: 'Days Completed',
                        hintText: 'Out of $_awwTotal days',
                        border: const OutlineInputBorder(),
                        suffixText: '/ $_awwTotal',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value:
                            int.tryParse(_awwCompletedController.text) != null
                            ? int.parse(_awwCompletedController.text) /
                                  _awwTotal
                            : 0,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF81C784),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Caregiver Activities Completion
            Text(
              'Caregiver Activities Completion',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _caregiverCompletedController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateAdherence(),
                      decoration: InputDecoration(
                        labelText: 'Days Completed',
                        hintText: 'Out of $_caregiverTotal days',
                        border: const OutlineInputBorder(),
                        suffixText: '/ $_caregiverTotal',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value:
                            int.tryParse(_caregiverCompletedController.text) !=
                                null
                            ? int.parse(_caregiverCompletedController.text) /
                                  _caregiverTotal
                            : 0,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF81C784),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Combined Adherence
            Card(
              elevation: 2,
              color: const Color(0xFF81C784).withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Combined Adherence',
                      style: TextStyle(fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF81C784),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(_adherence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Current Delay
            Text(
              'Current Developmental Delay',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _currentDelayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Current Delay (months)',
                    hintText: 'e.g., 2.0',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Notes
            Text(
              'Observations & Notes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText:
                        'e.g., Child shows interest, caregiver away this week',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitProgress,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_isLoading ? 'Submitting...' : 'Submit Progress'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6200EE),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            // Decision Display
            if (_decision != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Card(
                  elevation: 2,
                  color: const Color(0xFF81C784).withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Decision',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _decision ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF81C784),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_decisionReason ?? ''),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
