from django.db import models


class Item(models.Model):
    name = models.CharField(max_length=128)
    model = models.CharField(max_length=128, null=True, blank=True)
    period = models.IntegerField(max_length=10)
    penalty = models.DecimalField(max_digits=8, decimal_places=2, default='0.00')
    availability = models.NullBooleanField(default=True)

    class Meta:
        unique_together = ("name", "model")

    def __unicode__(self):
        return self.name