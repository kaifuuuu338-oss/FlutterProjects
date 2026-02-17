from rest_framework import serializers
from .models import Child, Question, Screening, Response, DomainScore

class ChildSerializer(serializers.ModelSerializer):
    class Meta:
        model = Child
        fields = '__all__'

class QuestionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Question
        fields = '__all__'

class ScreeningSerializer(serializers.ModelSerializer):
    class Meta:
        model = Screening
        fields = '__all__'

class ResponseSerializer(serializers.ModelSerializer):
    class Meta:
        model = Response
        fields = '__all__'

class DomainScoreSerializer(serializers.ModelSerializer):
    class Meta:
        model = DomainScore
        fields = '__all__'
