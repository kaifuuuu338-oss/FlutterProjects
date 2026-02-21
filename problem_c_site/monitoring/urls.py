from django.urls import path

from . import views

urlpatterns = [
    path('', views.home, name='monitoring_home'),
    path('monitoring/', views.home, name='monitoring_home_alias'),
    path('monitoring/aww/', views.aww_dashboard, name='monitoring_aww'),
    path('monitoring/supervisor/', views.supervisor_dashboard, name='monitoring_supervisor'),
    path('monitoring/cdpo/', views.cdpo_dashboard, name='monitoring_cdpo'),
    path('monitoring/district/', views.district_dashboard, name='monitoring_district'),
    path('monitoring/state/', views.state_dashboard, name='monitoring_state'),
    path('api/monitoring/', views.monitoring_api_proxy, name='monitoring_api_proxy'),
]
