from django.shortcuts import render, redirect
from django.http import HttpResponse
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.forms import AuthenticationForm
from .forms import RegisterForm
from . import services


def index(request):
    return render(request, 'core/index.html')


def screening(request):
    if request.method == 'POST':
        # receive form data and proxy to FastAPI
        payload = request.POST.dict()
        try:
            resp = services.submit_screening_sync(payload)
        except Exception as e:
            return HttpResponse(f"Error submitting: {e}", status=500)
        return redirect('core:results')

    # GET: render a simple screening form
    return render(request, 'core/screening.html')


def results(request):
    # Placeholder: in practice, fetch result from backend or session
    return render(request, 'core/results.html', context={})


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
