from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'users', views.UserViewSet)
router.register(r'countries', views.CountryViewSet)
router.register(r'country-statuses', views.CountryStatusViewSet, basename='countrystatus')

urlpatterns = [
    path('', include(router.urls)),
    path('register/', views.register_user, name='register'),
]
