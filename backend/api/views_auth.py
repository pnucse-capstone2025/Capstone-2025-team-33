from rest_framework import generics, permissions
from rest_framework.response import Response
from django.contrib.auth import get_user_model
from .serializers import UserSerializer
from rest_framework.decorators import api_view
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from .serializers import UserSerializer
from django.contrib.auth import get_user_model


User = get_user_model()
# 👤 회원가입
class SignupView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer

# 👤 아이디 중복 체크
@api_view(["GET"])
def check_id(request):
    username = request.query_params.get("username")
    exists = User.objects.filter(username=username).exists()
    return Response({"exists": exists})

# 👤 로그인 → JWT 발급
@api_view(["POST"])
def login(request):
    username = request.data.get("username")
    password = request.data.get("password")
    try:
        user = User.objects.get(username=username)
        if not user.check_password(password):
            return Response({"error": "Invalid credentials"}, status=400)

        refresh = RefreshToken.for_user(user)
        return Response({
            "refresh": str(refresh),
            "access": str(refresh.access_token),
        })
    except User.DoesNotExist:
        return Response({"error": "Invalid credentials"}, status=400)

class MeView(APIView):
    permission_classes = [IsAuthenticated]  # JWT 인증 필요

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)