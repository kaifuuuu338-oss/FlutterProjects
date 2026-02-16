import 'package:flutter/material.dart';

class QuestionCard extends StatelessWidget {
  final String question;
  final int? value; // 1 = yes, 0 = no, null = unanswered
  final ValueChanged<int> onChanged;
  final String yesLabel;
  final String noLabel;

  const QuestionCard({
    super.key,
    required this.question,
    required this.value,
    required this.onChanged,
    this.yesLabel = 'Yes',
    this.noLabel = 'No',
  });

  @override
  Widget build(BuildContext context) {
    final yesSelected = value == 1;
    final noSelected = value == 0;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB9DDF0), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              question,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFE7F4FA),
            ),
            child: Row(
              children: [
                _pillButton(
                  label: yesLabel.toUpperCase(),
                  selected: yesSelected,
                  color: const Color(0xFF3AB24A),
                  onTap: () => onChanged(1),
                ),
                const SizedBox(width: 2),
                _pillButton(
                  label: noLabel.toUpperCase(),
                  selected: noSelected,
                  color: const Color(0xFFE14B49),
                  onTap: () => onChanged(0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
