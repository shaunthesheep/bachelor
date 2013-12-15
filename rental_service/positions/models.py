from annoying.functions import get_object_or_None
from django.db import models
from common import common
from .managers import PositionManager, FreeManager


class Position(models.Model):
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