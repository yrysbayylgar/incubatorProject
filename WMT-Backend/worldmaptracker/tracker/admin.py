from django.contrib import admin
from .models import Country, CountryStatus

@admin.register(Country)
class CountryAdmin(admin.ModelAdmin):
    list_display = ('name', 'iso_code')
    search_fields = ('name', 'iso_code')
    ordering = ('name',)

@admin.register(CountryStatus)
class CountryStatusAdmin(admin.ModelAdmin):
    list_display = ('user', 'country', 'status', 'created_at')
    list_filter = ('status', 'user')
    search_fields = ('user__username', 'country__name')
    date_hierarchy = 'created_at'