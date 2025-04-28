from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Country, CountryStatus

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'username', 'email')

class CountrySerializer(serializers.ModelSerializer):
    class Meta:
        model = Country
        fields = ('id', 'name', 'iso_code')

class CountryStatusSerializer(serializers.ModelSerializer):
    country_name = serializers.ReadOnlyField(source='country.name')
    
    class Meta:
        model = CountryStatus
        fields = ('id', 'country', 'country_name', 'status', 'latitude', 'longitude', 'created_at', 'updated_at')
        read_only_fields = ('created_at', 'updated_at')
    
    def validate(self, data):
        user = self.context['request'].user
        country = data.get('country')
        
        
        if not country:
            raise serializers.ValidationError("Country must be specified")
        
        
        if self.instance is None:  # только при создании
            existing = CountryStatus.objects.filter(user=user, country=country).exists()
            if existing:
                raise serializers.ValidationError(f"You already marked {country.name}")
        
        return data

class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    
    class Meta:
        model = User
        fields = ('username', 'email', 'password')
    
    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password']
        )
        return user
