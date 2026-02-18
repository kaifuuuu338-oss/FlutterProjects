from django.shortcuts import render, redirect
from django.http import HttpResponse, JsonResponse
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.forms import AuthenticationForm
from django.utils import timezone
from .forms import RegisterForm
from . import services
from .monitoring import build_monitoring_context, build_impact_context
from screenings.models import Child, Screening, DomainScore, ReferralAction, FollowupOutcome, WorkforcePerformance


def index(request):
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


def login_view(request):
    if request.method == 'POST':
        form = AuthenticationForm(request, data=request.POST)
        if form.is_valid():
            user = form.get_user()
            login(request, user)
            return redirect('core:index')
    else:
        form = AuthenticationForm()
    return render(request, 'core/login.html', {'form': form})


def logout_view(request):
    logout(request)
    return redirect('core:login')


def register(request):
    if request.method == 'POST':
        form = RegisterForm(request.POST)
        if form.is_valid():
            user = form.save()
            login(request, user)
            return redirect('core:index')
    else:
        form = RegisterForm()
    return render(request, 'core/register.html', {'form': form})


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
    location_id = request.GET.get('location_id', '')
    try:
        context = services.fetch_monitoring_sync(role=role, location_id=location_id)
    except Exception:
        context = build_monitoring_context(role=role, location_id=location_id)
    context['role'] = role
    context['location_id'] = location_id
    return context


def aww_dashboard(request):
    context = _monitoring_context(request, role='aww')
    context['title'] = 'AWW Dashboard'
    return render(request, 'core/dashboard_aww.html', context)


def supervisor_dashboard(request):
    context = _monitoring_context(request, role='supervisor')
    context['title'] = 'Supervisor Dashboard'
    return render(request, 'core/dashboard_supervisor.html', context)


def cdpo_dashboard(request):
    context = _monitoring_context(request, role='cdpo')
    context['title'] = 'CDPO / Mandal Dashboard'
    return render(request, 'core/dashboard_cdpo.html', context)


def district_dashboard(request):
    context = _monitoring_context(request, role='district')
    context['title'] = 'District Dashboard'
    return render(request, 'core/dashboard_district.html', context)


def state_dashboard(request):
    context = _monitoring_context(request, role='state')
    context['title'] = 'State Dashboard'
    return render(request, 'core/dashboard_state.html', context)


def impact_dashboard(request):
    role = request.GET.get('role', 'state').lower()
    location_id = request.GET.get('location_id', '')
    try:
        context = services.fetch_impact_sync(role=role, location_id=location_id)
    except Exception:
        context = build_impact_context(role=role, location_id=location_id)
    context['title'] = 'Problem D - Longitudinal Impact'
    return render(request, 'core/impact.html', context)


def monitoring_api(request):
    role = request.GET.get('role', 'state').lower()
    location_id = request.GET.get('location_id', '')
    try:
        payload = services.fetch_monitoring_sync(role=role, location_id=location_id)
    except Exception:
        payload = build_monitoring_context(role=role, location_id=location_id)
    return JsonResponse(payload, safe=False)
