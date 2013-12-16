from django.contrib.auth.models import User
from django.utils.timezone import now
from items.models import Item
from django.db import models
import dbarray

__author__ = 'Anna Bomersbach'
__credits__ = ['Anna Bomersbach', 'Tomasz Kubik']

__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = 'Anna Bomersbach'
__email__ = "184779@student.pwr.wroc.pl"
__status__ = 'Production'


class Record(models.Model):
    """Model of relation storing temporal data on rental records.

    Combines information on instances of User and Item classes with date arrays describing complete history of
    rentals particular user involving chosen item.
    """
    user = models.ForeignKey(User)
    item = models.ForeignKey(Item)
    tt = dbarray.DateArrayField(blank=True, null=True)
    vt = dbarray.DateArrayField(blank=True, null=True)

    def __unicode__(self):
        return self.user + " " + self.item.name