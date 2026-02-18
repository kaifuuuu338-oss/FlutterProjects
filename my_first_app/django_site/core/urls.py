from django.urls import path
from . import views

app_name = 'core'

urlpatterns = [
    path('', views.index, name='index'),
    path('screening/', views.screening, name='screening'),
    path('results/', views.results, name='results'),
    path('monitoring/', views.monitoring_dashboard, name='monitoring'),
    path('monitoring/aww/', views.aww_dashboard, name='monitoring_aww'),
    path('monitoring/supervisor/', views.supervisor_dashboard, name='monitoring_supervisor'),
    path('monitoring/cdpo/', views.cdpo_dashboard, name='monitoring_cdpo'),
    path('monitoring/district/', views.district_dashboard, name='monitoring_district'),
    path('monitoring/state/', views.state_dashboard, name='monitoring_state'),
    path('impact/', views.impact_dashboard, name='impact'),
    path('api/monitoring/', views.monitoring_api, name='monitoring_api'),
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('register/', views.register, name='register'),
]
