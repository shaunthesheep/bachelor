from django import forms
from .models import Occupation


class AddOccupationForm(forms.ModelForm):
    class Meta:
        model = Occupation
        exclude = ('ve',)


class EmployForm(forms.ModelForm):
    class Meta:
        model = Occupation
        exclude = ('ve', 'position')