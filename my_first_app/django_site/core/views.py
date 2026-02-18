from pathlib import Path
import sqlite3

from django.shortcuts import render, redirect, get_object_or_404
from django.http import HttpResponse, JsonResponse
from django.contrib.auth import login, logout
from django.contrib.auth.decorators import login_required
from django.views.decorators.csrf import ensure_csrf_cookie
from django.utils import timezone
from .forms import RegisterForm, RoleLoginForm
from . import services
from .monitoring import build_monitoring_context, build_impact_context
from screenings.models import Child, Screening, DomainScore, ReferralAction, FollowupOutcome, WorkforcePerformance
from .models import UserRoleProfile


ROLE_TO_DASHBOARD = {
    'aww': 'core:monitoring_aww',
    'supervisor': 'core:monitoring_supervisor',
    'cdpo': 'core:monitoring_cdpo',
    'district': 'core:monitoring_district',
    'state': 'core:monitoring_state',
}

ROLE_TO_IMPACT = {
    'aww': 'core:impact_aww',
    'supervisor': 'core:impact_supervisor',
    'cdpo': 'core:impact_cdpo',
    'district': 'core:impact_district',
    'state': 'core:impact_state',
}


def _fastapi_db_path() -> Path:
    return Path(__file__).resolve().parents[2] / 'backend' / 'app' / 'ecd_data.db'


def _fastapi_mark_referral_done(child_key: str):
    db_path = _fastapi_db_path()
    if not db_path.exists():
        return
    conn = sqlite3.connect(db_path)
    try:
        cur = conn.cursor()
        cur.execute(
            """
            UPDATE referral_action
            SET referral_status='Completed',
                completion_date=DATE('now'),
                referral_required=1
            WHERE child_id=?
            """,
            (child_key,),
        )
        if cur.rowcount == 0:
            cur.execute(
                """
                INSERT INTO referral_action(referral_id, child_id, aww_id, referral_required, referral_type, urgency, referral_status, referral_date, completion_date)
                VALUES(?, ?, ?, 1, 'PHC', 'medium', 'Completed', DATE('now'), DATE('now'))
                """,
                (f"ref_{timezone.now().strftime('%Y%m%d%H%M%S%f')}", child_key, "aww_portal"),
            )
        conn.commit()
    finally:
        conn.close()


def _fastapi_schedule_followup(child_key: str):
    db_path = _fastapi_db_path()
    if not db_path.exists():
        return
    conn = sqlite3.connect(db_path)
    try:
        cur = conn.cursor()
        cur.execute(
            """
            UPDATE followup_outcome
            SET followup_completed=0,
                followup_date=DATE('now')
            WHERE child_id=?
            """,
            (child_key,),
        )
        if cur.rowcount == 0:
            cur.execute(
                """
                INSERT INTO followup_outcome(child_id, baseline_delay_months, followup_delay_months, improvement_status, followup_completed, followup_date)
                VALUES(?, 0, 0, 'No Change', 0, DATE('now'))
                """,
                (child_key,),
            )
        conn.commit()
    finally:
        conn.close()


def _get_user_role(user):
    if not user.is_authenticated:
        return None, ''
    profile = getattr(user, 'role_profile', None)
    if profile is None:
        return None, ''
    return profile.role, profile.location_id or ''


def _require_role(request, expected_role: str):
    role, location_id = _get_user_role(request.user)
    if role != expected_role:
        if role in ROLE_TO_DASHBOARD:
            return redirect(ROLE_TO_DASHBOARD[role])
        return redirect('core:login')
    return None


def index(request):
    role, _ = _get_user_role(request.user)
    if role in ROLE_TO_DASHBOARD:
        return redirect(ROLE_TO_DASHBOARD[role])
    return render(request, 'core/index.html')


def screening(request):
    if request.method == 'POST':
        # receive form data and proxy to FastAPI
        payload = request.POST.dict()
        child_name = (payload.get('child_name') or '').strip()
        age_months = int(payload.get('age_months') or 0)
        gender = (payload.get('gender') or 'Unknown').strip()
        awc_id = (payload.get('awc_id') or 'AWC001').strip()
        sector_id = (payload.get('sector_id') or 'SEC001').strip()
        mandal_id = (payload.get('mandal_id') or 'MANDAL001').strip()
        district_id = (payload.get('district_id') or 'DISTRICT001').strip()

        api_result = None
        try:
            api_payload = {
                'child_id': child_name or f'child_{timezone.now().strftime("%Y%m%d%H%M%S")}',
                'age_months': age_months,
                'domain_responses': {
                    # Simple default placeholders for web demo flow.
                    'GM': [1, 0, 1, 1, 0],
                    'FM': [1, 1, 0, 1, 0],
                    'LC': [1, 0, 0, 1, 0],
                    'COG': [1, 1, 1, 0, 0],
                    'SE': [1, 0, 1, 0, 0],
                },
                'gender': gender,
                'awc_id': awc_id,
                'sector_id': sector_id,
                'mandal': mandal_id,
                'district': district_id,
                'assessment_cycle': 'Baseline',
            }
            api_result = services.submit_screening_sync(api_payload)
        except Exception as e:
            return HttpResponse(f"Error submitting to Problem A backend: {e}", status=500)

        child, _ = Child.objects.get_or_create(
            name=child_name or f'Child-{timezone.now().strftime("%H%M%S")}',
            defaults={
                'gender': gender,
                'awc_id': awc_id,
                'sector_id': sector_id,
                'mandal_id': mandal_id,
                'district_id': district_id,
            },
        )
        child.gender = gender
        child.awc_id = awc_id
        child.sector_id = sector_id
        child.mandal_id = mandal_id
        child.district_id = district_id
        child.save()

        screening = Screening.objects.create(child=child, age_months=age_months)

        domain_labels = {}
        score_map = {'Low': 0.2, 'Medium': 0.5, 'High': 0.75, 'Critical': 0.92}
        for domain, label_raw in (api_result.get('domain_scores') or {}).items():
            label = str(label_raw).strip().capitalize()
            if label == 'Moderate':
                label = 'Medium'
            if label not in score_map:
                label = 'Low'
            domain_labels[domain] = label
            DomainScore.objects.create(
                screening=screening,
                domain=domain,
                probability=score_map[label],
                risk_label=label,
            )

        overall_rank = max(domain_labels.values(), key=lambda x: {'Low': 0, 'Medium': 1, 'High': 2, 'Critical': 3}[x])
        referral_required = overall_rank in ('High', 'Critical')
        ReferralAction.objects.create(
            child=child,
            referral_required=referral_required,
            referral_date=timezone.now().date(),
            referral_status='Pending' if referral_required else 'Completed',
            completion_date=None if referral_required else timezone.now().date(),
        )
        FollowupOutcome.objects.create(
            child=child,
            baseline_delay_months=6 if overall_rank in ('High', 'Critical') else 2,
            followup_delay_months=6 if overall_rank in ('High', 'Critical') else 1,
            improvement_status='No Change' if overall_rank in ('High', 'Critical') else 'Improving',
            followup_completed=False if overall_rank in ('High', 'Critical') else True,
            followup_date=timezone.now().date(),
        )
        WorkforcePerformance.objects.get_or_create(
            awc_id=awc_id,
            defaults={
                'aww_trained': True,
                'supervisor_trained': True,
                'cdpo_trained': False,
                'training_mode': 'blended',
                'parents_sensitized': 0,
                'parents_assigned_intervention': 0,
            },
        )
        return redirect('core:results')

    # GET: render a simple screening form
    return render(request, 'core/screening.html')


def results(request):
    latest = Screening.objects.select_related('child').order_by('-date').first()
    context = {}
    if latest:
        domain_scores = DomainScore.objects.filter(screening=latest).order_by('domain')
        risk_order = {'Low': 0, 'Medium': 1, 'High': 2, 'Critical': 3}
        overall = 'Low'
        for row in domain_scores:
            if risk_order.get(row.risk_label, 0) > risk_order.get(overall, 0):
                overall = row.risk_label
        context = {
            'has_data': True,
            'child_name': latest.child.name,
            'age_months': latest.age_months,
            'overall_risk': overall,
            'domain_scores': domain_scores,
        }
    else:
        context = {'has_data': False}
    return render(request, 'core/results.html', context=context)


@ensure_csrf_cookie
def login_view(request):
    if request.method == 'POST':
        form = RoleLoginForm(request, data=request.POST)
        if form.is_valid():
            user = form.get_user()
            selected_role = form.cleaned_data.get('role')
            profile = getattr(user, 'role_profile', None)
            if not profile or profile.role != selected_role:
                form.add_error('role', 'Selected role does not match this account.')
            else:
                login(request, user)
                return redirect(ROLE_TO_DASHBOARD.get(profile.role, 'core:index'))
    else:
        form = RoleLoginForm()
    return render(request, 'core/login.html', {'form': form})


@login_required(login_url='core:login')
def logout_view(request):
    logout(request)
    return redirect('core:login')


@ensure_csrf_cookie
def register(request):
    if request.method == 'POST':
        form = RegisterForm(request.POST)
        if form.is_valid():
            user = form.save()
            role = form.cleaned_data['role']
            location_id = (form.cleaned_data.get('location_id') or '').strip()
            UserRoleProfile.objects.create(
                user=user,
                role=role,
                location_id=location_id,
            )
            login(request, user)
            return redirect(ROLE_TO_DASHBOARD.get(role, 'core:index'))
    else:
        form = RegisterForm()
    return render(request, 'core/register.html', {'form': form})


@login_required(login_url='core:login')
def monitoring_dashboard(request):
    role = request.GET.get('role', 'state').lower()
    location_id = request.GET.get('location_id', '')
    try:
        context = services.fetch_monitoring_sync(role=role, location_id=location_id)
    except Exception:
        context = build_monitoring_context(role=role, location_id=location_id)
    context['title'] = 'Problem C - Decision Support & Monitoring'
    return render(request, 'core/monitoring.html', context)


def _monitoring_context(request, role: str):
    _, default_location = _get_user_role(request.user)
    location_id = request.GET.get('location_id', '') or default_location
    try:
        context = services.fetch_monitoring_sync(role=role, location_id=location_id)
    except Exception:
        context = build_monitoring_context(role=role, location_id=location_id)
    fallback = build_monitoring_context(role=role, location_id=location_id)
    defaults = {
        'high_risk_children_rows': [],
        'total_referred_children': 0,
        'avg_referral_days': 0,
        'followup_improving': 0,
        'followup_worsening': 0,
        'followup_same': 0,
        'coverage_warning': False,
        'aww_trained': False,
        'training_mode': '',
        'intervention_active_children': 0,
        'overdue_referrals': [],
        'domain_burden': {},
        'alerts': [],
        'priority_children': [],
        'under_treatment_referrals': 0,
        'risk_distribution': {'Low': 0, 'Medium': 0, 'High': 0, 'Critical': 0},
    }
    for key, value in defaults.items():
        if key not in context:
            context[key] = fallback.get(key, value)
    if not context.get('high_risk_children_rows'):
        context['high_risk_children_rows'] = fallback.get('high_risk_children_rows', [])
    if isinstance(context.get('high_risk_children'), list):
        if not context.get('high_risk_children_rows'):
            context['high_risk_children_rows'] = context.get('high_risk_children', [])
        context['high_risk_children'] = len(context.get('high_risk_children_rows', []))
    elif context.get('high_risk_children') is None:
        context['high_risk_children'] = fallback.get('high_risk_children', 0)
    context['coverage_warning'] = bool(context.get('screening_coverage', 0) < 80)
    context['role'] = role
    context['location_id'] = location_id
    return context


@login_required(login_url='core:login')
def aww_dashboard(request):
    guard = _require_role(request, 'aww')
    if guard:
        return guard
    context = _monitoring_context(request, role='aww')
    context['title'] = 'AWW Dashboard'
    return render(request, 'core/dashboard_aww.html', context)


@login_required(login_url='core:login')
def mark_referral_done_by_key(request):
    guard = _require_role(request, 'aww')
    if guard:
        return guard
    if request.method != 'POST':
        return redirect('core:monitoring_aww')
    child_key = (request.POST.get('child_key') or '').strip()
    if child_key:
        child = Child.objects.filter(name=child_key).first()
        if child:
            referral = ReferralAction.objects.filter(child=child).order_by('-created_at').first()
            if referral:
                referral.referral_required = True
                referral.referral_status = 'Completed'
                referral.completion_date = timezone.now().date()
                referral.save()
            else:
                ReferralAction.objects.create(
                    child=child,
                    referral_required=True,
                    referral_status='Completed',
                    referral_date=timezone.now().date(),
                    completion_date=timezone.now().date(),
                )
        _fastapi_mark_referral_done(child_key)
    location_id = request.GET.get('location_id') or request.POST.get('location_id') or ''
    return redirect(f"{ROLE_TO_DASHBOARD['aww']}?location_id={location_id}" if location_id else ROLE_TO_DASHBOARD['aww'])


@login_required(login_url='core:login')
def schedule_followup_by_key(request):
    guard = _require_role(request, 'aww')
    if guard:
        return guard
    if request.method != 'POST':
        return redirect('core:monitoring_aww')
    child_key = (request.POST.get('child_key') or '').strip()
    if child_key:
        child = Child.objects.filter(name=child_key).first()
        if child:
            followup = FollowupOutcome.objects.filter(child=child).order_by('-created_at').first()
            if followup:
                followup.followup_completed = False
                followup.followup_date = timezone.now().date()
                followup.save()
            else:
                FollowupOutcome.objects.create(
                    child=child,
                    baseline_delay_months=0,
                    followup_delay_months=0,
                    improvement_status='No Change',
                    followup_completed=False,
                    followup_date=timezone.now().date(),
                )
        _fastapi_schedule_followup(child_key)
    location_id = request.GET.get('location_id') or request.POST.get('location_id') or ''
    return redirect(f"{ROLE_TO_DASHBOARD['aww']}?location_id={location_id}" if location_id else ROLE_TO_DASHBOARD['aww'])


@login_required(login_url='core:login')
def mark_referral_done(request, child_id: int):
    guard = _require_role(request, 'aww')
    if guard:
        return guard
    if request.method != 'POST':
        return redirect('core:monitoring_aww')
    child = get_object_or_404(Child, id=child_id)
    referral = ReferralAction.objects.filter(child=child).order_by('-created_at').first()
    if referral:
        referral.referral_required = True
        referral.referral_status = 'Completed'
        referral.completion_date = timezone.now().date()
        referral.save()
    else:
        ReferralAction.objects.create(
            child=child,
            referral_required=True,
            referral_status='Completed',
            referral_date=timezone.now().date(),
            completion_date=timezone.now().date(),
        )
    location_id = request.GET.get('location_id') or request.POST.get('location_id') or ''
    return redirect(f"{ROLE_TO_DASHBOARD['aww']}?location_id={location_id}" if location_id else ROLE_TO_DASHBOARD['aww'])


@login_required(login_url='core:login')
def schedule_followup(request, child_id: int):
    guard = _require_role(request, 'aww')
    if guard:
        return guard
    if request.method != 'POST':
        return redirect('core:monitoring_aww')
    child = get_object_or_404(Child, id=child_id)
    followup = FollowupOutcome.objects.filter(child=child).order_by('-created_at').first()
    if followup:
        followup.followup_completed = False
        followup.followup_date = timezone.now().date()
        followup.save()
    else:
        FollowupOutcome.objects.create(
            child=child,
            baseline_delay_months=0,
            followup_delay_months=0,
            improvement_status='No Change',
            followup_completed=False,
            followup_date=timezone.now().date(),
        )
    location_id = request.GET.get('location_id') or request.POST.get('location_id') or ''
    return redirect(f"{ROLE_TO_DASHBOARD['aww']}?location_id={location_id}" if location_id else ROLE_TO_DASHBOARD['aww'])


@login_required(login_url='core:login')
def child_profile_view(request, child_id: int):
    child = get_object_or_404(Child, id=child_id)
    latest_screening = Screening.objects.filter(child=child).order_by('-date').first()
    domain_scores = DomainScore.objects.filter(screening=latest_screening).order_by('domain') if latest_screening else []
    referral = ReferralAction.objects.filter(child=child).order_by('-created_at').first()
    followup = FollowupOutcome.objects.filter(child=child).order_by('-created_at').first()
    context = {
        'title': 'Child Profile',
        'child': child,
        'latest_screening': latest_screening,
        'domain_scores': domain_scores,
        'referral': referral,
        'followup': followup,
    }
    return render(request, 'core/child_profile.html', context)


@login_required(login_url='core:login')
def supervisor_dashboard(request):
    guard = _require_role(request, 'supervisor')
    if guard:
        return guard
    context = _monitoring_context(request, role='supervisor')
    context['title'] = 'Supervisor Dashboard'
    return render(request, 'core/dashboard_supervisor.html', context)


@login_required(login_url='core:login')
def cdpo_dashboard(request):
    guard = _require_role(request, 'cdpo')
    if guard:
        return guard
    context = _monitoring_context(request, role='cdpo')
    context['title'] = 'CDPO / Mandal Dashboard'
    return render(request, 'core/dashboard_cdpo.html', context)


@login_required(login_url='core:login')
def district_dashboard(request):
    guard = _require_role(request, 'district')
    if guard:
        return guard
    context = _monitoring_context(request, role='district')
    context['title'] = 'District Dashboard'
    return render(request, 'core/dashboard_district.html', context)


@login_required(login_url='core:login')
def state_dashboard(request):
    guard = _require_role(request, 'state')
    if guard:
        return guard
    context = _monitoring_context(request, role='state')
    context['title'] = 'State Dashboard'
    return render(request, 'core/dashboard_state.html', context)


@login_required(login_url='core:login')
def impact_dashboard(request):
    role_user, _ = _get_user_role(request.user)
    if role_user in ROLE_TO_IMPACT:
        return redirect(ROLE_TO_IMPACT[role_user])
    role = request.GET.get('role', 'state').lower()
    location_id = request.GET.get('location_id', '')
    try:
        context = services.fetch_impact_sync(role=role, location_id=location_id)
    except Exception:
        context = build_impact_context(role=role, location_id=location_id)
    context['title'] = 'Problem D - Longitudinal Impact'
    return render(request, 'core/impact.html', context)


@login_required(login_url='core:login')
def problem_d_home(request):
    role, _ = _get_user_role(request.user)
    current_url = ROLE_TO_IMPACT.get(role, 'core:impact')
    context = {
        'title': 'Problem D - Role Entry',
        'current_url_name': current_url,
    }
    return render(request, 'core/problem_d_home.html', context)


def _impact_context(request, role: str):
    _, default_location = _get_user_role(request.user)
    location_id = request.GET.get('location_id', '') or default_location
    try:
        context = services.fetch_impact_sync(role=role, location_id=location_id)
    except Exception:
        context = build_impact_context(role=role, location_id=location_id)
    fallback = build_impact_context(role=role, location_id=location_id)
    defaults = {
        'improving': 0,
        'worsening': 0,
        'no_change': 0,
        'improving_pct': 0,
        'worsening_pct': 0,
        'avg_delay_reduction': 0,
        'avg_improvement_days': 0,
        'chronic_cases': 0,
        'followup_compliance': 0,
        'exit_from_high_risk': 0,
        'trend_rows': [],
        'total_children': 0,
        'child_trend_rows': [],
        'awc_rows': [],
        'sector_rows': [],
        'mandal_rows': [],
        'district_rows': [],
        'policy_insight': '',
    }
    for key, value in defaults.items():
        if key not in context or context.get(key) in (None, ''):
            context[key] = fallback.get(key, value)
    if context.get('trend_rows'):
        first = context['trend_rows'][0]
        if isinstance(first, dict) and 'high_risk_pct' not in first:
            context['trend_rows'] = fallback.get('trend_rows', [])
    else:
        context['trend_rows'] = fallback.get('trend_rows', [])
    context['role'] = role
    context['location_id'] = location_id
    return context


@login_required(login_url='core:login')
def impact_aww_dashboard(request):
    guard = _require_role(request, 'aww')
    if guard:
        return guard
    context = _impact_context(request, role='aww')
    context['title'] = 'Problem D - AWW Impact Dashboard'
    return render(request, 'core/impact_aww.html', context)


@login_required(login_url='core:login')
def impact_supervisor_dashboard(request):
    guard = _require_role(request, 'supervisor')
    if guard:
        return guard
    context = _impact_context(request, role='supervisor')
    context['title'] = 'Problem D - Supervisor Impact Dashboard'
    return render(request, 'core/impact_supervisor.html', context)


@login_required(login_url='core:login')
def impact_cdpo_dashboard(request):
    guard = _require_role(request, 'cdpo')
    if guard:
        return guard
    context = _impact_context(request, role='cdpo')
    context['title'] = 'Problem D - CDPO/Mandal Impact Dashboard'
    return render(request, 'core/impact_cdpo.html', context)


@login_required(login_url='core:login')
def impact_district_dashboard(request):
    guard = _require_role(request, 'district')
    if guard:
        return guard
    context = _impact_context(request, role='district')
    context['title'] = 'Problem D - District Impact Dashboard'
    return render(request, 'core/impact_district.html', context)


@login_required(login_url='core:login')
def impact_state_dashboard(request):
    guard = _require_role(request, 'state')
    if guard:
        return guard
    context = _impact_context(request, role='state')
    context['title'] = 'Problem D - State Impact Dashboard'
    return render(request, 'core/impact_state.html', context)


@login_required(login_url='core:login')
def impact_child_profile(request, child_id: int):
    child = get_object_or_404(Child, id=child_id)
    screens = Screening.objects.filter(child=child).order_by('date')
    screen_ids = [s.id for s in screens]
    risk_by_screen = {}
    if screen_ids:
        from .monitoring import _screening_overall_risk
        risk_by_screen = _screening_overall_risk(screen_ids)

    risk_timeline = [
        {
            'date': s.date.date(),
            'risk': risk_by_screen.get(s.id, 'Low'),
            'risk_score': {'Low': 1, 'Medium': 2, 'High': 3, 'Critical': 4}.get(risk_by_screen.get(s.id, 'Low'), 1),
        }
        for s in screens
    ]

    domain_timeline = []
    for s in screens:
        rows = DomainScore.objects.filter(screening=s).order_by('domain')
        domain_timeline.append({
            'date': s.date.date(),
            'GM': next((r.probability for r in rows if r.domain == 'GM'), 0),
            'FM': next((r.probability for r in rows if r.domain == 'FM'), 0),
            'LC': next((r.probability for r in rows if r.domain == 'LC'), 0),
            'COG': next((r.probability for r in rows if r.domain == 'COG'), 0),
            'SE': next((r.probability for r in rows if r.domain == 'SE'), 0),
        })

    referrals = ReferralAction.objects.filter(child=child).order_by('-created_at')
    followups = FollowupOutcome.objects.filter(child=child).order_by('-created_at')
    intervention_rows = []
    for f in followups:
        intervention_rows.append({
            'start_date': f.followup_date,
            'intervention_type': 'Home Stimulation Plan',
            'status': 'Active' if not f.followup_completed else 'Completed',
            'outcome': f.improvement_status,
        })

    insight = "No longitudinal insight available yet."
    if len(domain_timeline) >= 2:
        first = domain_timeline[0]
        last = domain_timeline[-1]
        lc_improve = round((last['LC'] - first['LC']) * 100, 1)
        if lc_improve > 0:
            insight = f"Child shows {lc_improve}% improvement in language domain over the tracked period."
        elif lc_improve < 0:
            insight = f"Language domain dropped by {abs(lc_improve)}%. Immediate intervention reinforcement recommended."
        else:
            insight = "Language domain is stable. Continue current intervention and follow-up schedule."

    return render(
        request,
        'core/impact_child_profile.html',
        {
            'title': 'Child Longitudinal Profile',
            'child': child,
            'risk_timeline': risk_timeline,
            'domain_timeline': domain_timeline,
            'intervention_rows': intervention_rows,
            'referrals': referrals,
            'followups': followups,
            'insight': insight,
        },
    )


@login_required(login_url='core:login')
def monitoring_api(request):
    role = request.GET.get('role', 'state').lower()
    location_id = request.GET.get('location_id', '')
    try:
        payload = services.fetch_monitoring_sync(role=role, location_id=location_id)
    except Exception:
        payload = build_monitoring_context(role=role, location_id=location_id)
    return JsonResponse(payload, safe=False)
