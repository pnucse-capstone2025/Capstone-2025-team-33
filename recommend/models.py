from django.db import models

# Create your models here.
class ClothingItem(models.Model):
    CATEGORY_CHOICES = [
        ('TOPS', '상의'),         # 상의
        ('BOTTOMS', '하의'),   # 하의
        ('OUTER', '아우터'),      # 아우터
        ('ONEPIECE', '원피스'), # 원피스
        ('ETC', '기타'),          # 기타
    ]

    user_uid = models.CharField(max_length=128)  # 사용자의 고유 식별자 (Firebase UID 등)
    name = models.CharField(max_length=100)      # 옷 이름 (예: 흰색 티셔츠)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)  # 옷 카테고리
    image_url = models.URLField(blank=True, null=True)  # 옷 이미지 URL (S3 등의 외부 저장소 URL)
    min_temp = models.IntegerField()  # 옷이 적합한 최소 기온
    max_temp = models.IntegerField()  # 옷이 적합한 최대 기온
    created_at = models.DateTimeField(auto_now_add=True)  # 등록 시간 (자동 저장)

    def __str__(self):
        return f"{self.name} ({self.category})"
    


class Schedule(models.Model):
    SOURCE_CHOICES = [
        ('manual', '수동 입력'),    # 사용자가 직접 입력
        ('google', '구글 캘린더'),  # 외부 캘린더에서 연동
        ('apple', '애플 캘린더'),   # 외부 캘린더에서 연동
    ]

    user_uid = models.CharField(max_length=128)  # 사용자의 고유 식별자 (Firebase UID 등)
    date = models.DateField()                    # 일정 날짜 (예: 2025-06-27)
    title = models.CharField(max_length=100)     # 일정 제목 (예: 면접, 결혼식)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default='manual')  # 일정 등록 출처
    created_at = models.DateTimeField(auto_now_add=True)  # 등록 시각

    def __str__(self):
        return f"{self.date}: {self.title}"
    
class RecommendationLog(models.Model):
    user_uid = models.CharField(max_length=128)  # 추천 대상 사용자 (Firebase UID 등)
    date = models.DateField()                    # 추천 날짜
    weather = models.TextField()                 # 날씨 정보 (예: 맑음, 25도, 습도 60%)
    schedule_title = models.CharField(max_length=100)  # 해당 일정 제목 (예: 면접, 결혼식)
    result_json = models.JSONField()             # 추천 결과 (코디네이션 JSON 데이터)
    created_at = models.DateTimeField(auto_now_add=True)  # 기록 생성 시각

    def __str__(self):
        return f"{self.date} - {self.user_uid} - {self.schedule_title}"