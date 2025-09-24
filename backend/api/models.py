import random



from django.contrib.auth import get_user_model

from django.contrib.auth.models import AbstractUser
from django.db import models


class CustomUser(AbstractUser):
    gender = models.CharField(
        max_length=10,
        choices=[("Men", "Men"), ("Women", "Women")],
        null=True,
        blank=True,
    )

    def __str__(self):
        return self.username
    
User = get_user_model()

# 👕 옷 정보 테이블
class Clothes(models.Model):
    id = models.AutoField(primary_key=True)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="clothes")  # 사용자와 연결
    image = models.ImageField(upload_to="clothes/", blank=True, null=True)
    gender = models.CharField(max_length=10)
    masterCategory = models.CharField(max_length=50)
    subCategory = models.CharField(max_length=50)
    articleType = models.CharField(max_length=50)
    baseColor = models.CharField(max_length=30)
    season = models.CharField(max_length=20)
    usage = models.CharField(max_length=50)

    custom_id = models.PositiveIntegerField(
        unique=True,
        editable=False,
        null=True,
        blank=True
    )

    def save(self, *args, **kwargs):
        if not self.custom_id:
            # 60001以上でユニークなIDを生成
            while True:
                new_id = random.randint(60001, 999999)
                if not Clothes.objects.filter(custom_id=new_id).exists():
                    self.custom_id = new_id
                    break
        super().save(*args, **kwargs)    

    def __str__(self):
        return f"{self.articleType} ({self.baseColor})"


# 📅 일정(이벤트) 정보 테이블
class Event(models.Model):
    id = models.AutoField(primary_key=True)  # 고유 ID
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="events")  # 사용자와 연결
    date = models.DateField()  # 날짜
    start_time = models.TimeField(null=True, blank=True)  # 시작 시간 (종일일 경우 null)
    end_time = models.TimeField(null=True, blank=True)    # 종료 시간 (종일일 경우 null)
    all_day = models.BooleanField(default=False)  # 종일 여부
    title = models.CharField(max_length=100)      # 일정 제목
    description = models.TextField(blank=True)    # 상세 설명
    created_at = models.DateTimeField(auto_now_add=True)  # 등록 시간

    def __str__(self):
        return f"{self.title} ({self.date})"


# 🤖 추천 결과 로그 테이블
class Recommendation(models.Model):
    id = models.AutoField(primary_key=True)  # 고유 ID
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="recommendations")  # 사용자와 연결
    event = models.ForeignKey(Event, on_delete=models.SET_NULL, null=True, blank=True)  # 연결된 이벤트 (없을 수도 있음)
    temperature = models.FloatField()    # 기온
    condition = models.CharField(max_length=50)  # 날씨 상태 (Clear, Rainy 등)
    gender = models.CharField(max_length=10)     # 성별
    recommended_items = models.JSONField()       # 추천된 아이템 ID 목록 (예: { "ids": [123,456] })
    reason = models.TextField()                  # 추천 이유
    created_at = models.DateTimeField(auto_now_add=True)  # 생성 시간

    def __str__(self):
        return f"Rec {self.id} for {self.user.username}"
