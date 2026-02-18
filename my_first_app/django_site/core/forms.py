from django import forms
from django.contrib.auth.forms import AuthenticationForm, UserCreationForm
from django.contrib.auth.models import User
from .models import UserRoleProfile

class RegisterForm(UserCreationForm):
    email = forms.EmailField(required=True)
    role = forms.ChoiceField(choices=UserRoleProfile.ROLE_CHOICES, required=True)
    location_id = forms.CharField(
        required=False,
        help_text='AWC/Sector/Mandal/District code based on role',
    )

    class Meta:
        model = User
        fields = ["username", "email", "role", "location_id", "password1", "password2"]


class RoleLoginForm(AuthenticationForm):
    role = forms.ChoiceField(choices=UserRoleProfile.ROLE_CHOICES, required=True)
