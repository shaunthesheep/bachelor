from django.contrib.auth.models import User
from positions.models import Position
from django.db import models
from datetime import date
from common import common


class Occupation(models.Model):
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