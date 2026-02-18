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


def _screening_domain_details(screening_ids):
    rows = DomainScore.objects.filter(screening_id__in=screening_ids)
    grouped = defaultdict(list)
    for row in rows:
        grouped[row.screening_id].append(
            {
                'domain': row.domain,
                'risk': _normalize_risk(row.risk_label),
            }
        )
    return grouped


def build_monitoring_context(role: str = 'state', location_id: str = ''):
    children_qs = _filter_children(role, location_id)
    total_children = children_qs.count()
    latest_map = _latest_screenings_map(children_qs)
    screening_ids = [s.id for s in latest_map.values()]
    risk_by_screen = _screening_overall_risk(screening_ids)
    domain_details_by_screen = _screening_domain_details(screening_ids)

    risk_counter = Counter()
    domain_burden = Counter()
    age_risk_counter = Counter()
    latest_by_child_id = {}
    latest_by_screen_id = {}

    for child_id, screen in latest_map.items():
        risk = risk_by_screen.get(screen.id, 'Low')
        risk_counter[risk] += 1
        age_risk_counter[(_age_band(screen.age_months), risk)] += 1
        latest_by_child_id[child_id] = screen
        latest_by_screen_id[screen.id] = screen

    for row in DomainScore.objects.filter(screening_id__in=screening_ids):
        label = _normalize_risk(row.risk_label)
        if label in ('High', 'Critical'):
            domain_burden[row.domain] += 1

    referrals = ReferralAction.objects.filter(child__in=children_qs)
    followups = FollowupOutcome.objects.filter(child__in=children_qs)

    pending_referrals = referrals.filter(referral_required=True, referral_status='Pending').count()
    completed_referrals = referrals.filter(referral_status='Completed').count()
    under_treatment_referrals = referrals.filter(referral_status='Under Treatment').count()
    followup_due = followups.filter(followup_completed=False).count()
    followup_done = followups.filter(followup_completed=True).count()

    coverage_denominator = total_children or 1
    screening_coverage = round(len(latest_map) * 100 / coverage_denominator, 2)
    followup_compliance = round(followup_done * 100 / (followup_done + followup_due or 1), 2)
    referral_completion = round(completed_referrals * 100 / (completed_referrals + pending_referrals or 1), 2)

    overdue_cutoff = timezone.now().date() - timedelta(days=14)
    overdue_referrals_qs = referrals.filter(
        referral_required=True,
        referral_status='Pending',
        referral_date__isnull=False,
        referral_date__lt=overdue_cutoff,
    ).select_related('child')
    overdue_referrals = list(overdue_referrals_qs[:10])

    latest_referral_by_child = {}
    for r in referrals.select_related('child').order_by('child_id', '-created_at'):
        if r.child_id not in latest_referral_by_child:
            latest_referral_by_child[r.child_id] = r
    latest_followup_by_child = {}
    for f in followups.select_related('child').order_by('child_id', '-created_at'):
        if f.child_id not in latest_followup_by_child:
            latest_followup_by_child[f.child_id] = f

    high_risk_children = []
    for child_id, screen in latest_map.items():
        risk = risk_by_screen.get(screen.id, 'Low')
        if risk not in ('High', 'Critical'):
            continue
        child = screen.child
        domains = domain_details_by_screen.get(screen.id, [])
        affected = [d['domain'] for d in domains if d['risk'] in ('High', 'Critical')]
        referral = latest_referral_by_child.get(child_id)
        days_since_flagged = (timezone.now().date() - screen.date.date()).days
        high_risk_children.append({
            'child_db_id': child.id,
            'child_id': child.name,
            'child_name': child.name,
            'age_months': screen.age_months,
            'risk_category': risk,
            'domain_affected': ", ".join(affected) if affected else "General",
            'referral_status': referral.referral_status if referral else 'Pending',
            'days_since_flagged': days_since_flagged,
        })
    high_risk_children.sort(key=lambda x: (_risk_rank(x['risk_category']), x['days_since_flagged']), reverse=True)

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
        alerts.append({'level': 'red', 'message': 'High/Critical risk children detected. Immediate action required.'})
    if overdue_referrals_qs.exists():
        alerts.append({'level': 'yellow', 'message': f'{overdue_referrals_qs.count()} referral(s) pending for more than 14 days.'})
    if hotspots:
        alerts.append({'level': 'orange', 'message': f'{len(hotspots)} mandal hotspot(s) detected above 15% high-risk threshold.'})
    if followup_due > 0:
        alerts.append({'level': 'yellow', 'message': f'{followup_due} follow-up record(s) pending.'})

    priority_children = []
    for child_id, screen in latest_map.items():
        child = screen.child
        risk = risk_by_screen.get(screen.id, 'Low')
        referral = latest_referral_by_child.get(child_id)
        followup = latest_followup_by_child.get(child_id)
        improvement = (followup.improvement_status if followup else 'No Change') or 'No Change'
        referral_status = referral.referral_status if referral else 'Pending'
        followup_completed = bool(followup and followup.followup_completed)
        if risk == 'Critical':
            rank = 1
        elif risk == 'High' and referral_status == 'Pending':
            rank = 2
        elif risk == 'High' and not followup_completed:
            rank = 3
        elif risk == 'Medium' and improvement == 'Worsening':
            rank = 4
        else:
            rank = 9
        if rank >= 9:
            continue
        priority_children.append({
            'child_db_id': child.id,
            'child_id': child.name,
            'risk': risk,
            'age_months': screen.age_months,
            'mandal_id': child.mandal_id,
            'rank': rank,
        })
    priority_children.sort(key=lambda x: (x['rank'], -_risk_rank(x['risk'])))

    improving = followups.filter(improvement_status='Improving').count()
    worsening = followups.filter(improvement_status='Worsening').count()
    no_change = followups.filter(improvement_status='No Change').count()
    avg_referral_days = 0.0
    complete_with_dates = referrals.filter(
        referral_status='Completed',
        referral_date__isnull=False,
        completion_date__isnull=False,
    )
    if complete_with_dates.exists():
        diffs = [(r.completion_date - r.referral_date).days for r in complete_with_dates]
        avg_referral_days = round(sum(diffs) / len(diffs), 2)
    training = WorkforcePerformance.objects.filter(awc_id=location_id).order_by('-updated_at').first() if role == 'aww' and location_id else None

    return {
        'role': role,
        'location_id': location_id,
        'total_children': total_children,
        'total_screened': len(latest_map),
        'risk_distribution': dict(risk_counter),
        'domain_burden': dict(domain_burden),
        'pending_referrals': pending_referrals,
        'completed_referrals': completed_referrals,
        'under_treatment_referrals': under_treatment_referrals,
        'followup_due': followup_due,
        'followup_done': followup_done,
        'screening_coverage': screening_coverage,
        'followup_compliance': followup_compliance,
        'referral_completion': referral_completion,
        'priority_children': priority_children[:5],
        'overdue_referrals': list(overdue_referrals),
        'hotspots': hotspots,
        'aww_performance': performance_rows[:10],
        'age_band_risk_rows': age_band_rows,
        'alerts': alerts,
        'high_risk_children_rows': high_risk_children[:50],
        'total_referred_children': referrals.filter(referral_required=True).count(),
        'avg_referral_days': avg_referral_days,
        'followup_improving': improving,
        'followup_worsening': worsening,
        'followup_same': no_change,
        'coverage_warning': screening_coverage < 80,
        'aww_trained': bool(training.aww_trained) if training else False,
        'training_mode': training.training_mode if training else '',
    }


def build_impact_context(role: str = 'state', location_id: str = ''):
    children_qs = _filter_children(role, location_id)
    followups = FollowupOutcome.objects.filter(child__in=children_qs)
    referrals = ReferralAction.objects.filter(child__in=children_qs)
    screenings = Screening.objects.filter(child__in=children_qs).order_by('child_id', 'date')

    latest_map = _latest_screenings_map(children_qs)
    latest_ids = [s.id for s in latest_map.values()]
    risk_by_screen = _screening_overall_risk(latest_ids)

    by_child_screens = defaultdict(list)
    for s in screenings:
        by_child_screens[s.child_id].append(s)

    improving = followups.filter(improvement_status='Improving').count()
    worsening = followups.filter(improvement_status='Worsening').count()
    no_change = followups.filter(improvement_status='No Change').count()
    total_followups = followups.count() or 1
    followup_done = followups.filter(followup_completed=True).count()
    compliance = round(followup_done * 100 / total_followups, 2)

    avg_reduction = 0.0
    if followups.exists():
        diffs = [f.baseline_delay_months - f.followup_delay_months for f in followups]
        avg_reduction = round(sum(diffs) / len(diffs), 2)

    high_to_lower = 0
    for _, screens in by_child_screens.items():
        if len(screens) < 2:
            continue
        risk_map = _screening_overall_risk([screens[0].id, screens[-1].id])
        start = risk_map.get(screens[0].id, 'Low')
        end = risk_map.get(screens[-1].id, 'Low')
        if start in ('High', 'Critical') and end in ('Medium', 'Low'):
            high_to_lower += 1

    six_month_counter = {}
    now = timezone.now().date()
    for i in range(5, -1, -1):
        month = (now.replace(day=1) - timedelta(days=31 * i)).strftime('%Y-%m')
        six_month_counter[month] = {'month': month, 'total': 0, 'high': 0}
    for s in screenings:
        month = s.date.strftime('%Y-%m')
        if month not in six_month_counter:
            continue
        six_month_counter[month]['total'] += 1
        rs = _normalize_risk(_screening_overall_risk([s.id]).get(s.id, 'Low'))
        if rs in ('High', 'Critical'):
            six_month_counter[month]['high'] += 1
    high_risk_trend_rows = []
    for month in sorted(six_month_counter.keys()):
        total = six_month_counter[month]['total']
        high = six_month_counter[month]['high']
        high_risk_trend_rows.append({
            'month': month,
            'high_risk_pct': round((high * 100 / total), 2) if total else 0.0,
            'screenings': total,
            'high_risk': high,
        })

    latest_followup_by_child = {}
    for f in followups.select_related('child').order_by('child_id', '-created_at'):
        if f.child_id not in latest_followup_by_child:
            latest_followup_by_child[f.child_id] = f
    latest_ref_by_child = {}
    for r in referrals.select_related('child').order_by('child_id', '-created_at'):
        if r.child_id not in latest_ref_by_child:
            latest_ref_by_child[r.child_id] = r

    child_trend_rows = []
    chronic_cases = 0
    for child in children_qs:
        latest_screen = latest_map.get(child.id)
        if not latest_screen:
            continue
        curr_risk = risk_by_screen.get(latest_screen.id, 'Low')
        latest_followup = latest_followup_by_child.get(child.id)
        trend = 'Stable'
        if latest_followup:
            if latest_followup.improvement_status == 'Improving':
                trend = 'Improving'
            elif latest_followup.improvement_status == 'Worsening':
                trend = 'Worsening'
        intervention_active = bool(
            latest_followup and not latest_followup.followup_completed
            or (latest_ref_by_child.get(child.id) and latest_ref_by_child[child.id].referral_status in ('Pending', 'Under Treatment'))
        )
        is_chronic = curr_risk in ('High', 'Critical') and trend != 'Improving'
        if is_chronic:
            chronic_cases += 1
        child_trend_rows.append({
            'child_id': child.id,
            'child_name': child.name,
            'age_months': latest_screen.age_months,
            'current_risk': curr_risk,
            'trend': trend,
            'intervention_active': intervention_active,
            'last_screening': latest_screen.date.date(),
            'chronic': is_chronic,
        })
    child_trend_rows.sort(key=lambda x: (_risk_rank(x['current_risk']), x['trend'] == 'Worsening'), reverse=True)

    improving_pct = round((improving * 100 / total_followups), 2) if total_followups else 0.0
    worsening_pct = round((worsening * 100 / total_followups), 2) if total_followups else 0.0

    avg_improvement_days = 0.0
    improvement_days = []
    for r in referrals.filter(referral_status='Completed', referral_date__isnull=False, completion_date__isnull=False):
        improvement_days.append((r.completion_date - r.referral_date).days)
    if improvement_days:
        avg_improvement_days = round(sum(improvement_days) / len(improvement_days), 2)

    awc_rows = []
    for item in children_qs.values('awc_id').annotate(total=Count('id')).exclude(awc_id=''):
        awc_children = children_qs.filter(awc_id=item['awc_id'])
        awc_followups = FollowupOutcome.objects.filter(child__in=awc_children)
        awc_improving = awc_followups.filter(improvement_status='Improving').count()
        awc_worsening = awc_followups.filter(improvement_status='Worsening').count()
        awc_total_follow = awc_followups.count() or 1
        awc_ref = ReferralAction.objects.filter(child__in=awc_children)
        ref_days = [(r.completion_date - r.referral_date).days for r in awc_ref.filter(referral_status='Completed', referral_date__isnull=False, completion_date__isnull=False)]
        awc_rows.append({
            'awc_id': item['awc_id'],
            'improving_pct': round(awc_improving * 100 / awc_total_follow, 2),
            'worsening_pct': round(awc_worsening * 100 / awc_total_follow, 2),
            'chronic_cases': sum(1 for c in child_trend_rows if c['chronic'] and c['child_name'] in list(awc_children.values_list('name', flat=True))),
            'avg_referral_days': round(sum(ref_days) / len(ref_days), 2) if ref_days else 0.0,
        })
    awc_rows.sort(key=lambda x: (x['improving_pct'], -x['worsening_pct']))

    sector_rows = []
    for item in children_qs.values('sector_id').annotate(total=Count('id')).exclude(sector_id=''):
        sector_children = children_qs.filter(sector_id=item['sector_id'])
        sector_followups = FollowupOutcome.objects.filter(child__in=sector_children)
        imp = sector_followups.filter(improvement_status='Improving').count()
        tot = sector_followups.count() or 1
        sector_rows.append({
            'sector_id': item['sector_id'],
            'improving_pct': round(imp * 100 / tot, 2),
        })
    sector_rows.sort(key=lambda x: x['improving_pct'], reverse=True)

    mandal_rows = []
    for item in children_qs.values('mandal_id').annotate(total=Count('id')).exclude(mandal_id=''):
        mandal_children = children_qs.filter(mandal_id=item['mandal_id'])
        mandal_followups = FollowupOutcome.objects.filter(child__in=mandal_children)
        imp = mandal_followups.filter(improvement_status='Improving').count()
        tot = mandal_followups.count() or 1
        mandal_ref = ReferralAction.objects.filter(child__in=mandal_children)
        done = mandal_ref.filter(referral_status='Completed').count()
        pending = mandal_ref.filter(referral_required=True, referral_status='Pending').count()
        mandal_rows.append({
            'mandal_id': item['mandal_id'],
            'improving_pct': round(imp * 100 / tot, 2),
            'risk_reduction_pct': round((high_to_lower * 100 / (len(latest_map) or 1)), 2),
            'referral_efficiency': round(done * 100 / ((done + pending) or 1), 2),
        })
    mandal_rows.sort(key=lambda x: x['improving_pct'], reverse=True)

    district_rows = []
    for item in children_qs.values('district_id').annotate(total=Count('id')).exclude(district_id=''):
        district_children = children_qs.filter(district_id=item['district_id'])
        district_followups = FollowupOutcome.objects.filter(child__in=district_children)
        imp = district_followups.filter(improvement_status='Improving').count()
        wor = district_followups.filter(improvement_status='Worsening').count()
        tot = district_followups.count() or 1
        district_rows.append({
            'district_id': item['district_id'],
            'improving_pct': round(imp * 100 / tot, 2),
            'worsening_pct': round(wor * 100 / tot, 2),
            'status_color': 'Green' if imp * 100 / tot >= 60 else 'Yellow' if imp * 100 / tot >= 40 else 'Red',
        })
    district_rows.sort(key=lambda x: x['improving_pct'], reverse=True)

    policy_insight = "Insufficient data to generate policy insight."
    if district_rows:
        top = district_rows[0]
        policy_insight = (
            f"District {top['district_id']} shows strongest longitudinal improvement "
            f"({top['improving_pct']}% improving cases). Prioritize its intervention patterns for replication."
        )

    return {
        'role': role,
        'location_id': location_id,
        'improving': improving,
        'worsening': worsening,
        'no_change': no_change,
        'improving_pct': improving_pct,
        'worsening_pct': worsening_pct,
        'avg_delay_reduction': avg_reduction,
        'avg_improvement_days': avg_improvement_days,
        'chronic_cases': chronic_cases,
        'followup_compliance': compliance,
        'exit_from_high_risk': high_to_lower,
        'trend_rows': high_risk_trend_rows,
        'current_screened': len(latest_map),
        'total_children': children_qs.count(),
        'child_trend_rows': child_trend_rows,
        'awc_rows': awc_rows,
        'sector_rows': sector_rows,
        'mandal_rows': mandal_rows,
        'district_rows': district_rows,
        'policy_insight': policy_insight,
    }
