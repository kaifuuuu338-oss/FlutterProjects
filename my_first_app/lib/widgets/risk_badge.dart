import 'package:flutter/material.dart';

enum RiskLevel { low, medium, high, critical }

class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  final String label;

  const RiskBadge({super.key, required this.level, required this.label});

  Color _colorOf(RiskLevel l) {
    switch (l) {
      case RiskLevel.low: return const Color(0xFF4CAF50);
      case RiskLevel.medium: return const Color(0xFFFFC107);
      case RiskLevel.high: return const Color(0xFFFF9800);
      case RiskLevel.critical: return const Color(0xFFF44336);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}