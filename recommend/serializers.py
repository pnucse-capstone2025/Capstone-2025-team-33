from rest_framework import serializers
from .models import ClothingItem, Schedule, RecommendationLog

class ClothingItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = ClothingItem
        fields = '__all__'

class ScheduleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Schedule
        fields = '__all__'

class RecommendationLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = RecommendationLog
        fields = '__all__'
