from django.contrib.auth.models import User
from django.db import models


class UserRoleProfile(models.Model):
    ROLE_CHOICES = [
        ('aww', 'AWW'),
        ('supervisor', 'Supervisor'),
        ('cdpo', 'CDPO'),
        ('district', 'District Officer'),
        ('state', 'State Officer'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='role_profile')
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)
    location_id = models.CharField(max_length=50, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.user.username} ({self.role})'
