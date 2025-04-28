from rest_framework import viewsets, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.contrib.auth.models import User
from .models import Country, CountryStatus
from .serializers import (
    UserSerializer, CountrySerializer, CountryStatusSerializer,
    UserRegistrationSerializer
)

@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register_user(request):
    """Endpoint для регистрации нового пользователя"""
    serializer = UserRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class UserViewSet(viewsets.ReadOnlyModelViewSet):
    """API endpoint для просмотра пользователей"""
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAdminUser]

class CountryViewSet(viewsets.ReadOnlyModelViewSet):
    """API endpoint для просмотра стран"""
    queryset = Country.objects.all()
    serializer_class = CountrySerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        queryset = Country.objects.all()
        name = self.request.query_params.get('name', None)
        iso_code = self.request.query_params.get('iso_code', None)
        
        if name:
            queryset = queryset.filter(name__icontains=name)
        if iso_code:
            queryset = queryset.filter(iso_code__iexact=iso_code)
            
        return queryset

class CountryStatusViewSet(viewsets.ModelViewSet):
    """API endpoint для управления статусами стран пользователя"""
    serializer_class = CountryStatusSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return CountryStatus.objects.filter(user=self.request.user)
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
    
    def create(self, request, *args, **kwargs):
        # Проверка на существование страны по ISO коду
        country_id = request.data.get('country')
        try:
            country = Country.objects.get(pk=country_id)
        except Country.DoesNotExist:
            return Response(
                {"error": "Country with this ID does not exist"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Проверка на дубликаты
        if CountryStatus.objects.filter(user=request.user, country=country).exists():
            return Response(
                {"error": f"You already marked {country.name}"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        return super().create(request, *args, **kwargs)
    
    def update(self, request, *args, **kwargs):
        # Проверка на существование страны по ISO коду
        country_id = request.data.get('country')
        if country_id:
            try:
                country = Country.objects.get(pk=country_id)
            except Country.DoesNotExist:
                return Response(
                    {"error": "Country with this ID does not exist"},
                    status=status.HTTP_404_NOT_FOUND
                )
        
        return super().update(request, *args, **kwargs)
