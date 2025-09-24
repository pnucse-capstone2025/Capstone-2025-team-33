from rest_framework import viewsets, permissions
from .models import Clothes, Event, Recommendation
from .serializers import ClothesSerializer, EventSerializer, RecommendationSerializer

# 👕 옷 API 뷰셋
class ClothesViewSet(viewsets.ModelViewSet):
    queryset = Clothes.objects.all()  # ★ 기본 queryset 추가
    serializer_class = ClothesSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # 👤 로그인한 사용자 본인 옷만 조회
        return Clothes.objects.filter(owner=self.request.user)

    def perform_create(self, serializer):
        # 👤 로그인한 사용자를 owner로 자동 지정
        serializer.save(owner=self.request.user)

# 📅 일정 API 뷰셋
class EventViewSet(viewsets.ModelViewSet):
    queryset = Event.objects.none()  
    serializer_class = EventSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = Event.objects.filter(owner=self.request.user)
        date_str = self.request.query_params.get("date")
        if date_str:
            qs = qs.filter(date=date_str)
        year = self.request.query_params.get("year")
        month = self.request.query_params.get("month")
        if year and month:
            qs = qs.filter(date__year=year, date__month=month)
        return qs



    def perform_create(self, serializer):
        # 👤 생성 시 자동으로 owner 지정
        serializer.save(owner=self.request.user)


# 🤖 추천 결과 API 뷰셋
class RecommendationViewSet(viewsets.ModelViewSet):
    queryset = Recommendation.objects.none()  
    serializer_class = RecommendationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # 👤 로그인 사용자 본인의 추천만 반환
        return Recommendation.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        # 👤 생성 시 자동으로 user 지정
        serializer.save(user=self.request.user)
