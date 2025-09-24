from django.contrib import admin
from .models import ClothingItem, Schedule, RecommendationLog

# Register your models here
admin.site.register(ClothingItem)
admin.site.register(Schedule)
admin.site.register(RecommendationLog)
