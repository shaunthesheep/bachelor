from django import forms
from .models import Item


class AddItemForm(forms.ModelForm):
    class Meta:
        model = Item
        exclude = ('availability',)
