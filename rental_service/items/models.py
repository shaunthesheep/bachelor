from django.db import models


class Item(models.Model):
    """Model of relation storing data about items available in the company.

    Fields: name and model combined create a unique designation for an item.
    Period: indicates a number of days the item can be rented for. Used when creating a rental record.
    Penalty: represents a fee to be paid for each day of return delay.
    """
    name = models.CharField(max_length=128)
    model = models.CharField(max_length=128, null=True, blank=True)
    period = models.IntegerField(max_length=10)
    penalty = models.DecimalField(max_digits=8, decimal_places=2, default='0.00')
    availability = models.NullBooleanField(default=True)

    class Meta:
        unique_together = ("name", "model")

    def __unicode__(self):
        return self.name