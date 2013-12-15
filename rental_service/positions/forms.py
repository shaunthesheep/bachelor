from django import forms
from .models import Position


class AddPositionForm(forms.ModelForm):
    class Meta:
        model = Position