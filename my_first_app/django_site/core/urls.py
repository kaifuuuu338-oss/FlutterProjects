from django.urls import path
from . import views

app_name = 'core'

urlpatterns = [
    path('', views.index, name='index'),
    path('screening/', views.screening, name='screening'),
    path('results/', views.results, name='results'),
    path('monitoring/', views.monitoring_dashboard, name='monitoring'),
    path('monitoring/aww/', views.aww_dashboard, name='monitoring_aww'),
    path('monitoring/aww/action/mark-referral-done/', views.mark_referral_done_by_key, name='mark_referral_done_by_key'),
    path('monitoring/aww/action/schedule-followup/', views.schedule_followup_by_key, name='schedule_followup_by_key'),
    path('monitoring/aww/child/<int:child_id>/mark-referral-done/', views.mark_referral_done, name='mark_referral_done'),
    path('monitoring/aww/child/<int:child_id>/schedule-followup/', views.schedule_followup, name='schedule_followup'),
    path('monitoring/aww/child/<int:child_id>/', views.child_profile_view, name='child_profile'),
    path('monitoring/supervisor/', views.supervisor_dashboard, name='monitoring_supervisor'),
    path('monitoring/cdpo/', views.cdpo_dashboard, name='monitoring_cdpo'),
    path('monitoring/district/', views.district_dashboard, name='monitoring_district'),
    path('monitoring/state/', views.state_dashboard, name='monitoring_state'),
    path('impact/', views.impact_dashboard, name='impact'),
    path('impact/aww/', views.impact_aww_dashboard, name='impact_aww'),
    path('impact/supervisor/', views.impact_supervisor_dashboard, name='impact_supervisor'),
    path('impact/cdpo/', views.impact_cdpo_dashboard, name='impact_cdpo'),
    path('impact/district/', views.impact_district_dashboard, name='impact_district'),
    path('impact/state/', views.impact_state_dashboard, name='impact_state'),
    path('impact/child/<int:child_id>/', views.impact_child_profile, name='impact_child_profile'),
    path('problem-d/', views.problem_d_home, name='problem_d_home'),
    path('problem-d/aww/', views.impact_aww_dashboard, name='problem_d_aww'),
    path('problem-d/supervisor/', views.impact_supervisor_dashboard, name='problem_d_supervisor'),
    path('problem-d/cdpo/', views.impact_cdpo_dashboard, name='problem_d_cdpo'),
    path('problem-d/district/', views.impact_district_dashboard, name='problem_d_district'),
    path('problem-d/state/', views.impact_state_dashboard, name='problem_d_state'),
    path('api/monitoring/', views.monitoring_api, name='monitoring_api'),
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('register/', views.register, name='register'),
]
