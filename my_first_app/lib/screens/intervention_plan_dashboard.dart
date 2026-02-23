import 'package:flutter/material.dart';

class InterventionPlanDashboard extends StatefulWidget {
  final String childId;
  final int ageMonths;

  const InterventionPlanDashboard({
    super.key,
    required this.childId,
    required this.ageMonths,
  });

  @override
  State<InterventionPlanDashboard> createState() =>
      _InterventionPlanDashboardState();
}

class _InterventionPlanDashboardState extends State<InterventionPlanDashboard> {
  @override
  void initState() {
    super.initState();
    // Load all data
    _loadPlanData();
  }

  void _loadPlanData() {
    // This would be called when navigating to a specific plan
    // For now, we'll need the plan_id from navigation
    // State.of() and route parameters
  }

  void _navigateToWeeklyProgress(String planId) {
    Navigator.pushNamed(
      context,
      '/weekly-progress',
      arguments: {'plan_id': planId, 'child_id': widget.childId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intervention Plan Dashboard'),
        backgroundColor: const Color(0xFF6200EE),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Overview Card
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Plan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPlanInfoRow('Domain:', 'Fine Motor'),
                    _buildPlanInfoRow('Severity:', 'HIGH'),
                    _buildPlanInfoRow('Phase:', 'Foundation (Weeks 1-4)'),
                    _buildPlanInfoRow('Progress:', '2 / 8 weeks'),
                  ],
                ),
              ),
            ),

            // Weekly Progress Section
            Text(
              'Weekly Progress',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildProgressChart(),
            const SizedBox(height: 20),

            // Current Week Activities
            Text(
              'This Week\'s Activities',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildActivitiesSection(),
            const SizedBox(height: 20),

            // Latest Decision
            Text(
              'Latest Decision',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildLatestDecisionCard(),
            const SizedBox(height: 20),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToWeeklyProgress('plan_123'),
                icon: const Icon(Icons.edit),
                label: const Text('Log Weekly Progress'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6200EE),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Weekly Adherence: 75%'),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF81C784).withOpacity(0.2),
                    border: Border.all(
                      color: const Color(0xFF81C784),
                      width: 3,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '75%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF81C784),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: 0.75,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF81C784),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AWW: 4/5 days | Caregiver: 3/5 days',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitiesSection() {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          _buildActivityTile(
            'Grip Strengthening',
            'AWW',
            'Daily',
            true,
          ),
          const Divider(),
          _buildActivityTile(
            'Play Dough Manipulation',
            'Caregiver',
            'Daily',
            false,
          ),
          const Divider(),
          _buildActivityTile(
            'Stacking Blocks',
            'AWW',
            '3x/week',
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(
    String title,
    String stakeholder,
    String frequency,
    bool completed,
  ) {
    return ListTile(
      leading: Checkbox(
        value: completed,
        onChanged: (_) {},
      ),
      title: Text(title),
      subtitle: Text('$stakeholder • $frequency'),
      trailing: completed
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
    );
  }

  Widget _buildLatestDecisionCard() {
    return Card(
      elevation: 2,
      color: const Color(0xFF81C784).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF81C784)),
                SizedBox(width: 8),
                Text(
                  'Continue Current Plan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF81C784),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Progress on track. Child shows improvement in fine motor skills with 75% adherence.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Week 2 Review',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
