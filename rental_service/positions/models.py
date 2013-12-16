from annoying.functions import get_object_or_None
from django.db import models
from common import common
from .managers import PositionManager, FreeManager

__author__ = 'Anna Bomersbach'
__credits__ = ['Anna Bomersbach', 'Tomasz Kubik']

__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = 'Anna Bomersbach'
__email__ = "184779@student.pwr.wroc.pl"
__status__ = 'Production'


class Position(models.Model):
    """Model of relation storing data on jobs in the company."""
    name = models.CharField(max_length=128)
    responsibilities = models.TextField(null=True, blank=True)
    active = models.BooleanField(default=True)

    objects = models.Manager()
    position = PositionManager()
    free = FreeManager()

    def __unicode__(self):
        return self.name

    def get_current_occupation(self):
        return get_object_or_None(self.occupation_set, ve=common.future_now)