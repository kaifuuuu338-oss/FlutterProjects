from __future__ import annotations

from collections import Counter, defaultdict
from datetime import timedelta

from django.db.models import Count, Q
from django.utils import timezone

from screenings.models import (
    Child,
    DomainScore,
    FollowupOutcome,
    ReferralAction,
    Screening,
    WorkforcePerformance,
)


RISK_ORDER = {'low': 0, 'medium': 1, 'high': 2, 'critical': 3}


def _risk_rank(label: str) -> int:
    return RISK_ORDER.get((label or '').strip().lower(), 0)


def _normalize_risk(label: str) -> str:
    label = (label or '').strip().lower()
    if label in ('critical', 'very high'):
        return 'Critical'
    if label == 'high':
        return 'High'
    if label in ('moderate', 'medium'):
        return 'Medium'
    return 'Low'


def _age_band(age_months: int) -> str:
    if age_months <= 12:
        return '0-12'
    if age_months <= 24:
        return '13-24'
    if age_months <= 36:
        return '25-36'
    if age_months <= 48:
        return '37-48'
    if age_months <= 60:
        return '49-60'
    return '61-72'


def _filter_children(role: str, location_id: str):
    queryset = Child.objects.all()
    if role == 'aww' and location_id:
        queryset = queryset.filter(awc_id=location_id)
    elif role == 'supervisor' and location_id:
        queryset = queryset.filter(sector_id=location_id)
    elif role == 'cdpo' and location_id:
        queryset = queryset.filter(mandal_id=location_id)
    elif role == 'district' and location_id:
        queryset = queryset.filter(district_id=location_id)
    return queryset


def _latest_screenings_map(children_qs):
    latest_by_child = {}
    for screen in Screening.objects.filter(child__in=children_qs).select_related('child').order_by('child_id', '-date'):
        if screen.child_id not in latest_by_child:
            latest_by_child[screen.child_id] = screen
    return latest_by_child


def _screening_overall_risk(screening_ids):
    domain_rows = DomainScore.objects.filter(screening_id__in=screening_ids)
    grouped = defaultdict(list)
    for row in domain_rows:
        grouped[row.screening_id].append(_normalize_risk(row.risk_label))
    result = {}
    for sid, labels in grouped.items():
        top = max(labels, key=_risk_rank) if labels else 'Low'
        result[sid] = top
    return result


def build_monitoring_context(role: str = 'state', location_id: str = ''):
    children_qs = _filter_children(role, location_id)
    total_children = children_qs.count()
    latest_map = _latest_screenings_map(children_qs)
    screening_ids = [s.id for s in latest_map.values()]
    risk_by_screen = _screening_overall_risk(screening_ids)

    risk_counter = Counter()
    domain_burden = Counter()
    high_priority_children = []
    age_risk_counter = Counter()

    for child_id, screen in latest_map.items():
        risk = risk_by_screen.get(screen.id, 'Low')
        risk_counter[risk] += 1
        age_risk_counter[(_age_band(screen.age_months), risk)] += 1
        if risk in ('High', 'Critical'):
            high_priority_children.append(screen.child)

    for row in DomainScore.objects.filter(screening_id__in=screening_ids):
        label = _normalize_risk(row.risk_label)
        if label in ('High', 'Critical'):
            domain_burden[row.domain] += 1

    referrals = ReferralAction.objects.filter(child__in=children_qs)
    followups = FollowupOutcome.objects.filter(child__in=children_qs)

    pending_referrals = referrals.filter(referral_required=True, referral_status='Pending').count()
    completed_referrals = referrals.filter(referral_status='Completed').count()
    followup_due = followups.filter(followup_completed=False).count()
    followup_done = followups.filter(followup_completed=True).count()

    coverage_denominator = total_children or 1
    screening_coverage = round(len(latest_map) * 100 / coverage_denominator, 2)
    followup_compliance = round(followup_done * 100 / (followup_done + followup_due or 1), 2)
    referral_completion = round(completed_referrals * 100 / (completed_referrals + pending_referrals or 1), 2)

    overdue_cutoff = timezone.now().date() - timedelta(days=14)
    overdue_referrals = referrals.filter(
        referral_required=True,
        referral_status='Pending',
        referral_date__isnull=False,
        referral_date__lt=overdue_cutoff,
    ).select_related('child')[:10]

    hotspots = []
    mandal_stats = (
        Child.objects.values('mandal_id')
        .annotate(total=Count('id'))
        .exclude(mandal_id='')
    )
    for item in mandal_stats:
        mandal_children = Child.objects.filter(mandal_id=item['mandal_id'])
        mandal_latest = _latest_screenings_map(mandal_children)
        mandal_risks = _screening_overall_risk([s.id for s in mandal_latest.values()])
        high_count = sum(1 for r in mandal_risks.values() if r in ('High', 'Critical'))
        pct = (high_count * 100 / (item['total'] or 1))
        if pct > 15:
            hotspots.append({'mandal_id': item['mandal_id'], 'high_risk_pct': round(pct, 2)})

    aww_summary = (
        Child.objects.values('awc_id')
        .annotate(total_children=Count('id'))
        .order_by('-total_children')[:10]
    )
    training_map = {
        w.awc_id: w
        for w in WorkforcePerformance.objects.filter(awc_id__in=[x['awc_id'] for x in aww_summary if x['awc_id']])
    }

    performance_rows = []
    for row in aww_summary:
        awc_id = row['awc_id'] or 'N/A'
        children = Child.objects.filter(awc_id=row['awc_id']) if row['awc_id'] else Child.objects.none()
        child_count = children.count() or 1
        local_latest = _latest_screenings_map(children)
        local_coverage = len(local_latest) * 100 / child_count
        local_referrals = ReferralAction.objects.filter(child__in=children)
        local_followups = FollowupOutcome.objects.filter(child__in=children)
        local_ref_pending = local_referrals.filter(referral_required=True, referral_status='Pending').count()
        local_ref_done = local_referrals.filter(referral_status='Completed').count()
        local_ref_rate = local_ref_done * 100 / (local_ref_done + local_ref_pending or 1)
        local_follow_done = local_followups.filter(followup_completed=True).count()
        local_follow_due = local_followups.filter(followup_completed=False).count()
        local_follow_rate = local_follow_done * 100 / (local_follow_done + local_follow_due or 1)
        performance_score = round(local_ref_rate * 0.4 + local_follow_rate * 0.3 + local_coverage * 0.3, 2)
        training = training_map.get(row['awc_id'])
        performance_rows.append({
            'awc_id': awc_id,
            'total_children': row['total_children'],
            'screening_coverage': round(local_coverage, 2),
            'referral_completion_rate': round(local_ref_rate, 2),
            'followup_compliance_rate': round(local_follow_rate, 2),
            'performance_score': performance_score,
            'aww_trained': training.aww_trained if training else False,
        })

    performance_rows.sort(key=lambda x: x['performance_score'], reverse=True)

    age_band_rows = []
    for band in ['0-12', '13-24', '25-36', '37-48', '49-60', '61-72']:
        age_band_rows.append({
            'age_band': band,
            'low': age_risk_counter[(band, 'Low')],
            'medium': age_risk_counter[(band, 'Medium')],
            'high': age_risk_counter[(band, 'High')],
            'critical': age_risk_counter[(band, 'Critical')],
        })

    alerts = []
    if risk_counter['High'] + risk_counter['Critical'] > 0:
        alerts.append('High/Critical risk children detected. Prioritize referral and home follow-up.')
    if pending_referrals > 0:
        alerts.append(f'{pending_referrals} referrals pending completion.')
    if hotspots:
        alerts.append(f'{len(hotspots)} mandal hotspot(s) detected above 15% high-risk threshold.')
    if followup_due > 0:
        alerts.append(f'{followup_due} follow-up record(s) pending.')

    return {
        'role': role,
        'location_id': location_id,
        'total_children': total_children,
        'total_screened': len(latest_map),
        'risk_distribution': dict(risk_counter),
        'domain_burden': dict(domain_burden),
        'pending_referrals': pending_referrals,
        'completed_referrals': completed_referrals,
        'followup_due': followup_due,
        'followup_done': followup_done,
        'screening_coverage': screening_coverage,
        'followup_compliance': followup_compliance,
        'referral_completion': referral_completion,
        'priority_children': list(high_priority_children[:5]),
        'overdue_referrals': list(overdue_referrals),
        'hotspots': hotspots,
        'aww_performance': performance_rows[:10],
        'age_band_risk_rows': age_band_rows,
        'alerts': alerts,
    }


def build_impact_context(role: str = 'state', location_id: str = ''):
    children_qs = _filter_children(role, location_id)
    followups = FollowupOutcome.objects.filter(child__in=children_qs)

    improving = followups.filter(improvement_status='Improving').count()
    worsening = followups.filter(improvement_status='Worsening').count()
    no_change = followups.filter(improvement_status='No Change').count()
    total = followups.count() or 1

    avg_reduction = 0.0
    if followups.exists():
        diffs = [f.baseline_delay_months - f.followup_delay_months for f in followups]
        avg_reduction = round(sum(diffs) / len(diffs), 2)

    compliance = round(followups.filter(followup_completed=True).count() * 100 / total, 2)

    latest_map = _latest_screenings_map(children_qs)
    by_child = defaultdict(list)
    for s in Screening.objects.filter(child__in=children_qs).order_by('child_id', 'date'):
        by_child[s.child_id].append(s)
    high_to_lower = 0
    for _, screens in by_child.items():
        if len(screens) < 2:
            continue
        risk_map = _screening_overall_risk([screens[0].id, screens[-1].id])
        start = risk_map.get(screens[0].id, 'Low')
        end = risk_map.get(screens[-1].id, 'Low')
        if start in ('High', 'Critical') and end in ('Medium', 'Low'):
            high_to_lower += 1

    monthly_counter = Counter()
    for s in Screening.objects.filter(child__in=children_qs).order_by('date'):
        monthly_counter[s.date.strftime('%Y-%m')] += 1
    trend_rows = [{'month': month, 'screenings': count} for month, count in sorted(monthly_counter.items())]

    return {
        'role': role,
        'location_id': location_id,
        'improving': improving,
        'worsening': worsening,
        'no_change': no_change,
        'avg_delay_reduction': avg_reduction,
        'followup_compliance': compliance,
        'exit_from_high_risk': high_to_lower,
        'trend_rows': trend_rows,
        'current_screened': len(latest_map),
    }
