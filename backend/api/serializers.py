from rest_framework import serializers
from .models import Clothes, Event, Recommendation, CustomUser

# 👤 사용자 시리얼라이저
class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = ("id", "username", "password", "gender")
        extra_kwargs = {"password": {"write_only": True}}

    def create(self, validated_data):
        # 👤 비밀번호 해시 적용
        user = CustomUser.objects.create_user(
            username=validated_data["username"],
            password=validated_data["password"],
            gender=validated_data.get("gender"),
        )
        return user


# 👕 옷 시리얼라이저
class ClothesSerializer(serializers.ModelSerializer):
    class Meta:
        model = Clothes
        fields = "__all__"
        read_only_fields = ["owner", "custom_id"]  # ★ custom_id を読み取り専用に



# 📅 일정 시리얼라이저
class EventSerializer(serializers.ModelSerializer):
    class Meta:
        model = Event
        fields = '__all__'
        read_only_fields = ['owner']  # ★ owner は自動で付与するので入力不要


# 🤖 추천 결과 시리얼라이저
class RecommendationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Recommendation
        fields = '__all__'
