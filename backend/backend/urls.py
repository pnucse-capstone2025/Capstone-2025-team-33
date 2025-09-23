from django.contrib import admin
from django.urls import path, include
from api.views_auth import SignupView, check_id, login, MeView
from api.views import ClothesViewSet, EventViewSet, RecommendationViewSet
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from django.conf import settings
from django.conf.urls.static import static

router = DefaultRouter()
router.register(r'clothes', ClothesViewSet)
router.register(r'events', EventViewSet)
router.register(r'recommendations', RecommendationViewSet)

urlpatterns = [
    path('admin/', admin.site.urls),  # ★ 管理画面の追加
    path('api/auth/login/', login, name='login'),
    path("api/auth/signup/", SignupView.as_view(), name="signup"),
    path("api/auth/check-id/", check_id, name="check_id"),
    path("api/auth/login/", login, name="login"),
    path("api/auth/me/", MeView.as_view(), name="me"),
    path("api/", include(router.urls)),
    # ⬇️ refresh token으로 access token 재발급
    path('api/auth/refresh/', TokenRefreshView.as_view(), name='token_refresh')
]
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)