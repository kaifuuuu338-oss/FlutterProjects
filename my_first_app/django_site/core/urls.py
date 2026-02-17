from django.urls import path
from . import views

app_name = 'core'

urlpatterns = [
    path('', views.index, name='index'),
    path('screening/', views.screening, name='screening'),
    path('results/', views.results, name='results'),
]
