from django.contrib.auth.models import User
from positions.models import Position
from django.db import models
from datetime import date
from common import common

__author__ = 'Anna Bomersbach'
__credits__ = ['Anna Bomersbach', 'Tomasz Kubik']

__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = 'Anna Bomersbach'
__email__ = "184779@student.pwr.wroc.pl"
__status__ = 'Production'


class Occupation(models.Model):
    """Model of relation storing temporal data about users occupying positions in the company.

    Combines information on instances of User and Position classes with dates indicating start and end points
    of valid time period.
    Property: is_current used to denote whether the occupation is still valid.
    Property: duration computes the number of days the occupation was valid.
    """
    user = models.ForeignKey(User)
    position = models.ForeignKey(Position)
    vs = models.DateField(auto_now_add=True)
    ve = models.DateField(default=common.future_now)

    def __unicode__(self):
        return self.user + " as " + self.position.name

    @property
    def is_current(self):
        if self.ve > date.today():
            return True
        return False

    @property
    def duration(self):
        if self.is_current:
            return (date.today()-self.vs).days
        return (self.ve-self.vs).days