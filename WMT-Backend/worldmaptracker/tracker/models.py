from django.db import models
from django.contrib.auth.models import User

class Country(models.Model):
    name = models.CharField(max_length=100)
    iso_code = models.CharField(max_length=3, unique=True)
    
    def __str__(self):
        return f"{self.name} ({self.iso_code})"
    
    class Meta:
        verbose_name_plural = "Countries"

class CountryStatus(models.Model):
    STATUS_CHOICES = (
        ('visited', 'Visited'),
        ('want_to_visit', 'Want to Visit'),
    )
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='country_statuses')
    country = models.ForeignKey(Country, on_delete=models.CASCADE)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES)
    latitude = models.FloatField()
    longitude = models.FloatField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ('user', 'country')
        verbose_name_plural = "Country Statuses"
    
    def __str__(self):
        return f"{self.user.username} - {self.country.name}: {self.status}"
