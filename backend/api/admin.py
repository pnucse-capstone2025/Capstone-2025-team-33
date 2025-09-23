from django.contrib import admin
from .models import Clothes, Event, Recommendation, CustomUser



@admin.register(CustomUser)
class CustomUserAdmin(admin.ModelAdmin):
    list_display = ("id", "username", "gender", "is_staff", "is_superuser")
    search_fields = ("username",)


@admin.register(Clothes)
class ClothesAdmin(admin.ModelAdmin):
    list_display = (
        "id",          # Django 自動生成の PK
        "custom_id",   # ★ 追加
        "owner",
        "gender",
        "masterCategory",
        "subCategory",
        "articleType",
        "baseColor",
        "usage",
    )
    search_fields = ("custom_id", "articleType", "baseColor", "owner__username")
    list_filter = ("gender", "masterCategory", "baseColor", "usage")

# 他のモデルも必要なら同様に登録
@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "date", "owner")
    search_fields = ("title", "description", "owner__username")

@admin.register(Recommendation)
class RecommendationAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "event", "temperature", "condition", "created_at")
    search_fields = ("user__username", "condition")
