from django import forms
from .models import Occupation
from positions.models import Position


class AddOccupationForm(forms.ModelForm):
    class Meta:
        model = Occupation
        exclude = ('ve', 'position')

    def __init__(self, *args, **kwargs):
        self.position = kwargs.pop('position', None)
        super(AddOccupationForm, self).__init__(*args, **kwargs)
        #self.fields['position'].queryset = Position.free.all()  # owner.item_set.all()
        #self.fields['contact'].queryset = Contact.active.filter(borrower=owner)  # owner.contacts.all()