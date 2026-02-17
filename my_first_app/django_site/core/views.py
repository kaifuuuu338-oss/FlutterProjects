from django.shortcuts import render, redirect
from django.http import HttpResponse
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
