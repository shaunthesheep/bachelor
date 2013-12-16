from django import forms
from .models import Item


class AddItemForm(forms.ModelForm):
    """Constructs a form for items addition."""
    class Meta:
        model = Item
        exclude = ('availability',)
