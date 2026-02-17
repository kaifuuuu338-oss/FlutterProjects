import 'package:flutter/material.dart';

/// A reusable question card that supports three options (left, middle, right)
/// and returns an int value (0/1/2) via onChanged.
class TriStateQuestionCard extends StatelessWidget {
  final String question;
  final int? value; // 0/1/2 or null
  final List<String> labels; // length must be 3
  final ValueChanged<int> onChanged;
  final IconData? icon;
  final VoidCallback? onSpeak;

  const TriStateQuestionCard({
    super.key,
    required this.question,
    required this.value,
    required this.labels,
    required this.onChanged,
    this.icon,
    this.onSpeak,
  }) : assert(labels.length == 3);

  @override
  Widget build(BuildContext context) {
    final selected = value;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EEF3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Icon(icon, size: 20, color: const Color(0xFF6A7580)),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(question, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (onSpeak != null)
                      IconButton(
                        icon: const Icon(Icons.volume_up, size: 20),
                        onPressed: onSpeak,
                        tooltip: 'Listen',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(3, (i) {
                    final isSelected = selected == i;
                    final color = isSelected ? (i == 0 ? const Color(0xFF43A047) : (i == 1 ? const Color(0xFFF9A825) : const Color(0xFFE53935))) : const Color(0xFF6A7580);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InkWell(
                          onTap: () => onChanged(i),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF6F8FA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? color : const Color(0xFFECEFF1)),
                            ),
                            child: Center(
                              child: Text(
                                labels[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? color : const Color(0xFF6A7580),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
