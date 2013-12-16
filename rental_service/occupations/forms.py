from django import forms
from .models import Occupation


class AddOccupationForm(forms.ModelForm):
    """Constructs a form for occupation record addition.

    The form contains Occupation model fields, with exception for valid time and date,
    which is set to 'future_now' constant defined in file common in module common.
    """
    class Meta:
        model = Occupation
        exclude = ('ve',)


class EmployForm(forms.ModelForm):
    """Constructs a form for user employment record addition.

    The form contains Occupation model fields, with exception for valid time and date,
    which is set to 'future_now' constant defined in file common in module common,
    and 'position' field, which is set with a parameter the function was evoked with.
    The form is used to add a user to a position from list of available jobs.
    """
    class Meta:
        model = Occupation
        exclude = ('ve', 'position')