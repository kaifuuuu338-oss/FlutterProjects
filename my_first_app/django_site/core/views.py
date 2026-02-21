from django.shortcuts import render, redirect
from django.contrib.auth import login, logout
from django.contrib.auth.decorators import login_required
from django.views.decorators.csrf import ensure_csrf_cookie

from .forms import RegisterForm, RoleLoginForm
from screenings.models import Screening, DomainScore
from .models import UserRoleProfile


def index(request):
    return render(request, 'core/index.html')


def screening(request):
    context = {
        'title': 'Problem A/B Screening Source',
        'external_only': True,
    }
    if request.method == 'POST':
        context['error_message'] = (
            'Screening submission is disabled on this Django portal. '
            'Please run screening in Problem A/B app only.'
        )
    return render(request, 'core/screening.html', context)


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
                return redirect('core:index')
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
            return redirect('core:index')
    else:
        form = RegisterForm()
    return render(request, 'core/register.html', {'form': form})
