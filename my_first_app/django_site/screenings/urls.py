from rest_framework import routers
from .views import ChildViewSet, QuestionViewSet, ScreeningViewSet, ResponseViewSet, DomainScoreViewSet

router = routers.DefaultRouter()
router.register(r'children', ChildViewSet)
router.register(r'questions', QuestionViewSet)
router.register(r'screenings', ScreeningViewSet)
router.register(r'responses', ResponseViewSet)
router.register(r'domain-scores', DomainScoreViewSet)

urlpatterns = router.urls
