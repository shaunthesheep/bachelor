from django import forms
from .models import Record


class AddRecordForm(forms.ModelForm):
    class Meta:
        model = Record
        exclude = ('tt', 'vt')