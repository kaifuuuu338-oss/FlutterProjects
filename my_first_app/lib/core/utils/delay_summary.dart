import 'dart:math' as math;

import 'package:my_first_app/core/constants/question_bank.dart';

Map<String, int>? buildDelaySummaryFromResponses(
  Map<String, List<int>> domainResponses, {
  required int ageMonths,
}) {
  const domains = ['GM', 'FM', 'LC', 'COG', 'SE'];
  bool hasAny = false;
  for (final d in domains) {
    final values = domainResponses[d];
    if (values != null && values.isNotEmpty) {
      hasAny = true;
      break;
    }
  }
  if (!hasAny) return null;

  final questions = QuestionBank.byAgeMonths(ageMonths);
  final bandKey = _ageBandKey(ageMonths);
  var totalDelays = 0;
  final summary = <String, int>{};

  for (final domain in domains) {
    final answers = domainResponses[domain] ?? const <int>[];
    final qList = questions[domain] ?? const <String>[];
    final weights = _weightsForDomain(bandKey, domain, qList.length);
    final isRedFlag = qList.map((q) => q.toLowerCase().contains('red flag')).toList();

    final binary = _domainBinary(
      answers: answers,
      weights: weights,
      isRedFlag: isRedFlag,
    );
    summary['${domain}_delay'] = binary;
    totalDelays += binary;
  }

  summary['num_delays'] = totalDelays;
  return summary;
}

int _domainBinary({
  required List<int> answers,
  required List<int> weights,
  required List<bool> isRedFlag,
}) {
  final len = math.min(answers.length, math.min(weights.length, isRedFlag.length));
  if (len == 0) return 0;

  var s = 0.0;
  var sMax = 0.0;
  for (var i = 0; i < len; i++) {
    final w = weights[i].toDouble();
    sMax += w;
    final ans = answers[i];
    final delay = isRedFlag[i] ? (ans == 1) : (ans == 0);
    if (delay) s += w;
  }

  final t = 0.5 * sMax;
  final p = 1.0 / (1.0 + math.exp(-(s - t)));
  return p >= 0.5 ? 1 : 0;
}

String _ageBandKey(int ageMonths) {
  if (ageMonths <= 12) return '0-12';
  final years = ageMonths ~/ 12;
  if (years <= 2) return '13-24';
  if (years == 3) return '25-36';
  if (years == 4) return '37-48';
  if (years == 5) return '49-60';
  return '61-72';
}

List<int> _weightsForDomain(String bandKey, String domain, int len) {
  final band = _weightBank[bandKey];
  final weights = band?[domain];
  if (weights == null || weights.length != len) {
    return List<int>.generate(len, (_) => 2);
  }
  return weights;
}

const Map<String, Map<String, List<int>>> _weightBank = {
  '0-12': {
    'GM': [3, 3, 2, 4, 8],
    'FM': [3, 3, 2, 2, 8],
    'LC': [3, 2, 3, 2, 8],
    'COG': [2, 3, 3, 2, 8],
    'SE': [3, 3, 3, 2, 8],
  },
  '13-24': {
    'GM': [3, 3, 3, 2, 8],
    'FM': [3, 3, 2, 2, 8],
    'LC': [3, 3, 3, 2, 8],
    'COG': [3, 3, 3, 3, 8],
    'SE': [2, 2, 3, 3, 8],
  },
  '25-36': {
    'GM': [3, 3, 3, 2, 8],
    'FM': [3, 2, 3, 3, 8],
    'LC': [3, 3, 3, 3, 8],
    'COG': [3, 3, 3, 3, 8],
    'SE': [3, 3, 3, 2, 8],
  },
  '37-48': {
    'GM': [3, 3, 3, 4, 8],
    'FM': [3, 3, 3, 3, 8],
    'LC': [3, 3, 3, 3, 8],
    'COG': [3, 3, 3, 3, 8],
    'SE': [3, 3, 3, 3, 8],
  },
  '49-60': {
    'GM': [3, 3, 3, 4, 8],
    'FM': [3, 3, 3, 3, 8],
    'LC': [3, 3, 3, 3, 8],
    'COG': [3, 2, 3, 3, 8],
    'SE': [3, 3, 3, 2, 8],
  },
  '61-72': {
    'GM': [3, 3, 3, 3, 3],
    'FM': [3, 3, 3, 3, 3],
    'LC': [3, 3, 3, 3, 3],
    'COG': [3, 3, 3, 3, 3],
    'SE': [3, 3, 3, 3, 3],
  },
};

int delayValueForDomain(Map<String, int>? delaySummary, String domain) {
  if (delaySummary == null) return 0;
  return delaySummary['${domain}_delay'] ??
      delaySummary[domain] ??
      delaySummary['${domain.toLowerCase()}_delay'] ??
      0;
}
