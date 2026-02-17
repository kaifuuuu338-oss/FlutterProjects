from rest_framework import viewsets, status
from rest_framework.response import Response as DRFResponse
from rest_framework.decorators import action
from .models import Child, Question, Screening, Response, DomainScore
from .serializers import ChildSerializer, QuestionSerializer, ScreeningSerializer, ResponseSerializer, DomainScoreSerializer
from .services import compute_domain_score, domain_score_to_risk_label, overall_risk_from_domains

class ChildViewSet(viewsets.ModelViewSet):
    queryset = Child.objects.all()
    serializer_class = ChildSerializer

class QuestionViewSet(viewsets.ModelViewSet):
    queryset = Question.objects.all()
    serializer_class = QuestionSerializer

class ScreeningViewSet(viewsets.ModelViewSet):
    queryset = Screening.objects.all()
    serializer_class = ScreeningSerializer

    @action(detail=True, methods=['get'])
    def results(self, request, pk=None):
        screening = self.get_object()
        domain_scores = DomainScore.objects.filter(screening=screening)
        data = DomainScoreSerializer(domain_scores, many=True).data
        return DRFResponse({'domain_scores': data})

class ResponseViewSet(viewsets.ModelViewSet):
    queryset = Response.objects.all()
    serializer_class = ResponseSerializer

class DomainScoreViewSet(viewsets.ModelViewSet):
    queryset = DomainScore.objects.all()
    serializer_class = DomainScoreSerializer
