from django import forms
from .models import Item

__author__ = 'Anna Bomersbach'
__credits__ = ['Anna Bomersbach', 'Tomasz Kubik']

__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = 'Anna Bomersbach'
__email__ = "184779@student.pwr.wroc.pl"
__status__ = 'Production'

class AddItemForm(forms.ModelForm):
    """Constructs a form for items addition."""
    class Meta:
        model = Item
        exclude = ('availability',)
