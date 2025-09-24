import os
from dotenv import load_dotenv

load_dotenv()  # Load environment variables from .env file

from django.shortcuts import render

# Create your views here.
from rest_framework import generics
from .models import ClothingItem, Schedule, RecommendationLog
from .serializers import ClothingItemSerializer, ScheduleSerializer, RecommendationLogSerializer
from .weather import get_weather_by_city

# CRUD API 뷰를 위한 클래스 기반 뷰

# 의류 등록 및 목록 조회
class ClothingItemListCreateView(generics.ListCreateAPIView):
    queryset = ClothingItem.objects.all()
    serializer_class = ClothingItemSerializer

# 일정 등록 및 목록 조회
class ScheduleListCreateView(generics.ListCreateAPIView):
    queryset = Schedule.objects.all()
    serializer_class = ScheduleSerializer

# 추천 기록 조회 (읽기 전용)
class RecommendationLogListView(generics.ListAPIView):
    queryset = RecommendationLog.objects.all()
    serializer_class = RecommendationLogSerializer

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from datetime import date
import random

class RecommendAPIView(APIView):
    def get(self, request, *args, **kwargs):
        user_uid = request.query_params.get('user_uid')
        city = request.query_params.get('city')

        if not user_uid or not city:
            return Response({"error": "Missing user_uid or city"}, status=status.HTTP_400_BAD_REQUEST)

        # 1. Get today's schedule
        today = date.today()
        schedules = Schedule.objects.filter(user_uid=user_uid, date=today)
        if not schedules.exists():
            return Response({"error": "No schedule found for today"}, status=status.HTTP_404_NOT_FOUND)

        schedule = schedules.first()

        # 2. Get weather info
        weather_info = get_weather_by_city(city)

        # 3. Generate a prompt
        prompt = f"What should I wear for a '{schedule.title}' on a day like this: {weather_info}?"

        # 4. Mock recommendation (later replaced with LLM response)
        recommendation = random.choice([
            "Try a lightweight hoodie with jeans.",
            "A suit and tie would be great for this occasion.",
            "Go with a flowy dress and a trench coat.",
            "Opt for a casual shirt and khaki pants."
        ])

        # 5. Save log
        RecommendationLog.objects.create(
            user_uid=user_uid,
            date=today,
            weather=weather_info,
            schedule_title=schedule.title,
            result_json={"recommendation": recommendation}
        )

        return Response({
            "schedule": schedule.title,
            "weather": weather_info,
            "recommendation": recommendation
        }, status=status.HTTP_200_OK)
