class BaselineRiskBreakdown {
  final int gmDelay;
  final int fmDelay;
  final int lcDelay;
  final int cogDelay;
  final int seDelay;
  final int totalDelays;
  final int delayPoints;
  final int autismPoints;
  final int adhdPoints;
  final int behaviorPoints;
  final int score;
  final String category;

  const BaselineRiskBreakdown({
    required this.gmDelay,
    required this.fmDelay,
    required this.lcDelay,
    required this.cogDelay,
    required this.seDelay,
    required this.totalDelays,
    required this.delayPoints,
    required this.autismPoints,
    required this.adhdPoints,
    required this.behaviorPoints,
    required this.score,
    required this.category,
  });
}

BaselineRiskBreakdown calculateBaselineRisk({
  required String autismRisk,
  required String adhdRisk,
  required String behaviorRisk,
  required Map<String, int>? delaySummary,
}) {
  final gm = delaySummary?['GM_delay'] ?? 0;
  final fm = delaySummary?['FM_delay'] ?? 0;
  final lc = delaySummary?['LC_delay'] ?? 0;
  final cog = delaySummary?['COG_delay'] ?? 0;
  final se = delaySummary?['SE_delay'] ?? 0;
  final total = delaySummary?['num_delays'] ?? (gm + fm + lc + cog + se);

  final delayPoints = total * 5;
  final autismPoints = _riskBonus(autismRisk, high: 15, moderate: 8);
  final adhdPoints = _riskBonus(adhdRisk, high: 8, moderate: 4);
  final behaviorPoints = _riskBonus(behaviorRisk, high: 7, moderate: 0);
  final score = delayPoints + autismPoints + adhdPoints + behaviorPoints;

  return BaselineRiskBreakdown(
    gmDelay: gm,
    fmDelay: fm,
    lcDelay: lc,
    cogDelay: cog,
    seDelay: se,
    totalDelays: total,
    delayPoints: delayPoints,
    autismPoints: autismPoints,
    adhdPoints: adhdPoints,
    behaviorPoints: behaviorPoints,
    score: score,
    category: _baselineCategory(score),
  );
}

int _riskBonus(String risk, {required int high, required int moderate}) {
  final r = risk.trim().toLowerCase();
  if (r == 'high' || r == 'critical') return high;
  if (r == 'moderate' || r == 'medium') return moderate;
  return 0;
}

String _baselineCategory(int score) {
  if (score <= 10) return 'Low';
  if (score <= 25) return 'Medium';
  return 'High';
}
