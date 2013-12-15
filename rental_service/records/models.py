from django.contrib.auth.models import User
from django.utils.timezone import now
from items.models import Item
from django.db import models
import dbarray


class Record(models.Model):
        user = models.ForeignKey(User)
        item = models.ForeignKey(Item)
        tt = dbarray.DateArrayField(blank=True, null=True)
        vt = dbarray.DateArrayField(blank=True, null=True)

        def __unicode__(self):
            return self.user + " " + self.item.name