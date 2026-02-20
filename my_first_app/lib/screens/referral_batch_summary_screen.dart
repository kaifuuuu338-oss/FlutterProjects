import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/models/referral_model.dart';
import 'package:my_first_app/models/referral_summary_item.dart';
import 'package:my_first_app/screens/referral_details_screen.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';

class ReferralBatchSummaryScreen extends StatefulWidget {
  final List<ReferralSummaryItem>? referrals;
  final String? childId;

  const ReferralBatchSummaryScreen({
    super.key,
    this.referrals,
    this.childId,
  });

  @override
  State<ReferralBatchSummaryScreen> createState() => _ReferralBatchSummaryScreenState();
}

class _ReferralBatchSummaryScreenState extends State<ReferralBatchSummaryScreen> {
  bool _loading = true;
  List<ReferralModel> _models = [];
  List<ReferralSummaryItem> _provided = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.referrals != null && widget.referrals!.isNotEmpty) {
        _provided = widget.referrals!;
        return;
      }
      final db = LocalDBService();
      await db.initialize();
      if (widget.childId == null) {
        _models = db.getAllReferrals();
      } else {
        _models = db.getChildReferrals(widget.childId!);
      }
    } catch (e) {
      _models = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  Color _riskColor(String risk) {
    final r = risk.trim().toLowerCase();
    if (r == 'critical' || r == 'high') return const Color(0xFFE53935);
    if (r == 'medium') return const Color(0xFFF9A825);
    return const Color(0xFF43A047);
  }

  String _riskLabel(String risk, AppLocalizations l10n) {
    switch (risk.trim().toLowerCase()) {
      case 'critical':
        return l10n.t('critical');
      case 'high':
        return l10n.t('high');
      case 'medium':
        return l10n.t('medium');
      case 'low':
        return l10n.t('low');
      default:
        return risk;
    }
  }

  String _domainLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'GM':
        return l10n.t('domain_gm');
      case 'FM':
        return l10n.t('domain_fm');
      case 'LC':
        return l10n.t('domain_lc');
      case 'COG':
        return l10n.t('domain_cog');
      case 'SE':
        return l10n.t('domain_se');
      default:
        return key;
    }
  }

  String _urgencyLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'Immediate':
        return l10n.t('urgency_immediate');
      case 'Priority':
      case 'Urgent':
        return l10n.t('urgency_urgent');
      default:
        return l10n.t('urgency_normal');
    }
  }

  String _urgencyRaw(ReferralUrgency urgency) {
    switch (urgency) {
      case ReferralUrgency.immediate:
        return 'Immediate';
      case ReferralUrgency.priority:
        return 'Priority';
      default:
        return 'Normal';
    }
  }

  String? _extractDomainKey(List<String> reasons) {
    if (reasons.isEmpty) return null;
    const keys = ['GM', 'FM', 'LC', 'COG', 'SE'];
    for (final reason in reasons) {
      for (final key in keys) {
        if (reason.contains('($key)') || reason.contains(' $key ')) {
          return key;
        }
      }
    }
    return null;
  }

  List<String> _followUpActions(ReferralSummaryItem referral, AppLocalizations l10n) {
    final domainKey = _extractDomainKey(referral.reasons);
    final age = referral.ageMonths;
    switch (domainKey) {
      case 'GM':
        return _gmActivities(age);
      case 'FM':
        return _fmActivities(age);
      case 'LC':
        return _lcActivities(age);
      case 'COG':
        return _cogActivities(age);
      case 'SE':
        return _seActivities(age);
      default:
        return [l10n.t('followup_generic_1'), l10n.t('followup_generic_2')];
    }
  }

  List<String> _gmActivities(int ageMonths) {
    if (ageMonths <= 12) {
      return [
        'Daily tummy time',
        'Encourage rolling',
        'Supported sitting',
        'Crawling practice',
        'Pull to stand',
        'Reach for toys',
        'Assisted cruising',
        'Floor free movement',
        'Gentle stretching',
        'Avoid prolonged cradle use',
      ];
    }
    if (ageMonths <= 24) {
      return [
        'Independent walking practice',
        'Push–pull toys',
        'Ball kicking',
        'Squat & stand games',
        'Safe climbing',
        'Dancing',
        'Outdoor walking',
        'Mini obstacle play',
        'Stair practice (with support)',
        'Playground time',
      ];
    }
    if (ageMonths <= 36) {
      return [
        'Jump with both feet',
        'Running games',
        'Throw & catch large ball',
        'Tiptoe walking',
        'Tricycle attempt',
        'Balance walking',
        'Animal walk games',
        'Climbing steps',
        'Outdoor play daily',
        'Follow-the-leader',
      ];
    }
    if (ageMonths <= 48) {
      return [
        'Hop practice',
        'Stand on one foot',
        'Ride tricycle',
        'Jump forward',
        'Obstacle course',
        'Catch big ball',
        'Simple yoga',
        'Playground climbing',
        'Dance movements',
        'Ladder climbing',
      ];
    }
    if (ageMonths <= 60) {
      return [
        'Hop on one foot',
        'Skip attempt',
        'Catch bounce ball',
        'Somersault',
        'Balance beam',
        'Jump rope start',
        'Mini races',
        'Football kick',
        'Swing play',
        'Relay games',
      ];
    }
    return [
      'Bicycle riding',
      'Smooth skipping',
      'Jump rope',
      'Team sports',
      'Running drills',
      'Climbing wall',
      'Yoga balance poses',
      'Outdoor daily play',
      'Advanced obstacle games',
      'Coordination drills',
    ];
  }

  List<String> _fmActivities(int ageMonths) {
    if (ageMonths <= 12) {
      return [
        'Grasp rattles',
        'Transfer objects',
        'Reach & grab',
        'Finger play',
        'Crinkle paper',
        'Texture exploration',
        'Self-feeding practice',
        'Soft squeeze toys',
        'Hold caregiver finger',
        'Mirror hand play',
      ];
    }
    if (ageMonths <= 24) {
      return [
        'Scribbling',
        'Stack blocks',
        'Shape sorter',
        'Turn book pages',
        'Spoon practice',
        'Put objects in container',
        'Playdough squeeze',
        'Open/close boxes',
        'Large peg board',
        'Remove socks',
      ];
    }
    if (ageMonths <= 36) {
      return [
        'Tower 6 blocks',
        'Draw lines',
        'Large bead threading',
        'Clay rolling',
        'Sticker pasting',
        'Paper tearing',
        'Water pouring',
        'Peg boards',
        'Lid opening',
        'Simple puzzles',
      ];
    }
    if (ageMonths <= 48) {
      return [
        'Draw circle',
        'Use scissors',
        'Button practice',
        'Copy shapes',
        'Fold paper',
        'Clay modeling',
        'Tweezer picking',
        'Medium bead threading',
        'Coloring control',
        'Lacing cards',
      ];
    }
    if (ageMonths <= 60) {
      return [
        'Draw square',
        'Cut straight line',
        'Trace letters',
        'Zip/unzip',
        'Fork use',
        'Small bead threading',
        'Paste within lines',
        'Pattern copying',
        'Craft work',
        'Pencil grip correction',
      ];
    }
    return [
      'Write letters',
      'Draw triangle',
      'Tie shoelaces',
      'Detailed coloring',
      'Copy patterns',
      'Handwriting practice',
      'Model building',
      'Button small buttons',
      'Dot-to-dot',
      'Fine craft work',
    ];
  }

  List<String> _lcActivities(int ageMonths) {
    if (ageMonths <= 12) {
      return [
        'Talk frequently',
        'Name objects',
        'Sing rhymes',
        'Respond to babbling',
        'Read picture books',
        'Call by name',
        'Gesture games',
        'Imitate sounds',
        'Eye contact',
        'Reduce screen time',
      ];
    }
    if (ageMonths <= 24) {
      return [
        'Label objects',
        'Encourage 2-word phrases',
        'Ask simple questions',
        'Expand child’s words',
        'Body part naming',
        'Action songs',
        'Daily reading',
        'Follow simple commands',
        'Show & tell',
        'Avoid baby talk',
      ];
    }
    if (ageMonths <= 36) {
      return [
        'Encourage short sentences',
        'Ask “what” questions',
        'Role play',
        'Picture description',
        'Color naming',
        'Story time',
        'Daily conversation',
        'Correct gently',
        'Vocabulary games',
        'Reduce screen time',
      ];
    }
    return [
      'Story narration',
      'Ask “why/how” questions',
      'Teach opposites',
      'Rhyme games',
      'Grammar correction gently',
      '3-step commands',
      'Group conversation',
      'Show & tell',
      'Memory storytelling',
      'Reading habit daily',
    ];
  }

  List<String> _cogActivities(int ageMonths) {
    if (ageMonths <= 12) {
      return [
        'Peek-a-boo',
        'Hide & find toy',
        'Cause-effect toys',
        'Mirror play',
        'Sound recognition',
        'Sensory exploration',
        'Object permanence games',
        'Imitation games',
        'Big-small concept',
        'Touch exploration',
      ];
    }
    if (ageMonths <= 24) {
      return [
        'Shape sorter',
        'Simple puzzles',
        'Matching objects',
        'Sorting colors',
        'Identify animals',
        'Pretend play',
        'Stack blocks',
        'Follow instructions',
        'Memory play',
        'Daily routine learning',
      ];
    }
    return [
      'Counting games',
      'Pattern recognition',
      'Number & letter recognition',
      'Story sequencing',
      'Problem-solving tasks',
      'Classification activities',
      'Board games',
      'Building blocks',
      'Concept learning (big/small, hot/cold)',
      'Question-answer sessions',
    ];
  }

  List<String> _seActivities(int ageMonths) {
    if (ageMonths <= 12) {
      return [
        'Smile back',
        'Cuddle time',
        'Eye contact',
        'Respond to cries',
        'Mirror expressions',
        'Routine schedule',
        'Parent bonding',
        'Face games',
        'Gentle praise',
        'Safe environment',
      ];
    }
    if (ageMonths <= 24) {
      return [
        'Parallel play',
        'Sharing encouragement',
        'Emotion naming',
        'Praise good behavior',
        'Simple group play',
        'Turn-taking',
        'Comfort when upset',
        'Consistent routine',
        'Encourage independence',
        'Avoid harsh punishment',
      ];
    }
    return [
      'Role play',
      'Teach sharing',
      'Group activities',
      'Identify feelings',
      'Story about emotions',
      'Encourage empathy',
      'Set simple rules',
      'Positive reinforcement',
      'Conflict resolution guidance',
      'Reward charts',
    ];
  }

  List<ReferralSummaryItem> _buildReferrals(AppLocalizations l10n) {
    if (_provided.isNotEmpty) {
      final provided = List<ReferralSummaryItem>.from(_provided);
      provided.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return provided;
    }
    if (_models.isEmpty) {
      return [];
    }
    final list = _models.map((model) => _fromModel(model, l10n)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  ReferralSummaryItem _fromModel(ReferralModel model, AppLocalizations l10n) {
    final meta = model.metadata ?? {};
    final domainKey = (meta['domain'] as String?) ?? '';
    final domainRisk = (meta['domain_risk'] as String?) ?? (meta['risk_level'] as String?) ?? 'low';
    final overallRisk = (meta['risk_level'] as String?) ?? (meta['overall_risk'] as String?) ?? domainRisk;
    final referralTypeLabel = (meta['referral_type_label'] as String?) ?? _referralTypeFallback(model.referralType);
    final ageMonthsValue = meta['age_months'];
    final ageMonths = ageMonthsValue is int
        ? ageMonthsValue
        : int.tryParse(ageMonthsValue?.toString() ?? '') ?? 0;
    final reasons = <String>[];
    final domainReason = (meta['domain_reason'] as String?) ?? '';
    if (domainReason.isNotEmpty) {
      reasons.add(domainReason);
    } else if (domainKey.isNotEmpty) {
      final label = _domainLabel(domainKey, l10n);
      if (domainRisk.isNotEmpty) {
        reasons.add('$label (${_riskLabel(domainRisk, l10n)})');
      } else {
        reasons.add(label);
      }
    }

    return ReferralSummaryItem(
      referralId: model.referralId,
      childId: model.childId,
      awwId: model.awwId,
      ageMonths: ageMonths,
      overallRisk: overallRisk,
      referralType: referralTypeLabel,
      urgency: _urgencyRaw(model.urgency),
      status: model.status.toString().split('.').last,
      createdAt: model.createdAt,
      expectedFollowUpDate: model.expectedFollowUpDate,
      notes: model.notes,
      reasons: reasons,
    );
  }

  String _referralTypeFallback(ReferralType type) {
    switch (type) {
      case ReferralType.enhancedMonitoring:
        return 'Enhanced Monitoring';
      case ReferralType.specialistEvaluation:
        return 'Specialist Evaluation';
      case ReferralType.immediateSpecialistReferral:
        return 'Immediate Specialist Referral';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;
    final referrals = _loading ? <ReferralSummaryItem>[] : _buildReferrals(l10n);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FB), Color(0xFFE9F1F8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: isWide ? 180 : 150,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: const LanguageMenuButton(iconColor: Colors.white),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(6),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/ap_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Center(
                                child: Text(AppLocalizations.of(context).t('ap_short'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppLocalizations.of(context).t('govt_andhra_pradesh'),
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.t('referrals_created', {'count': referrals.length.toString()}),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isWide ? 22 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loading)
                            const Center(child: CircularProgressIndicator())
                          else if (referrals.isEmpty)
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(l10n.t('no_past_results')),
                              ),
                            )
                          else
                            for (final referral in referrals) ...[
                              Card(
                                elevation: 6,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _riskColor(referral.overallRisk),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Text(
                                              _riskLabel(referral.overallRisk, l10n).toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              l10n.t('referral_number', {'id': referral.referralId}),
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => ReferralDetailsScreen(
                                                    referralId: referral.referralId,
                                                    childId: referral.childId,
                                                    awwId: referral.awwId,
                                                    ageMonths: referral.ageMonths,
                                                    overallRisk: referral.overallRisk,
                                                    referralType: referral.referralType,
                                                    urgency: referral.urgency,
                                                    status: referral.status,
                                                    createdAt: referral.createdAt,
                                                    expectedFollowUpDate: referral.expectedFollowUpDate,
                                                    notes: referral.notes,
                                                    reasons: referral.reasons,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Text(l10n.t('open_details')),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _infoTile(l10n.t('child_id'), referral.childId),
                                          _infoTile(l10n.t('referral_type'), referral.referralType),
                                          _infoTile(l10n.t('urgency'), _urgencyLabel(referral.urgency, l10n)),
                                          _infoTile(l10n.t('created_on'), _formatDate(referral.createdAt)),
                                          _infoTile(l10n.t('follow_up_by'), _formatDate(referral.expectedFollowUpDate)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(l10n.t('reasons'), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[800])),
                                      const SizedBox(height: 6),
                                      if (referral.reasons.isEmpty)
                                        Text(l10n.t('no_specific_domain_triggers'))
                                      else
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: referral.reasons
                                              .map((r) => Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFF3E0),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(r, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                  ))
                                              .toList(),
                                        ),
                                      const SizedBox(height: 14),
                                      Text(l10n.t('follow_up_actions'),
                                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[800])),
                                      const SizedBox(height: 6),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: _followUpActions(referral, l10n)
                                            .map(
                                              (action) => Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('• '),
                                                    Expanded(child: Text(action)),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          if (!_loading && referrals.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(l10n.t('back_to_dashboard')),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF5D6B78), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
