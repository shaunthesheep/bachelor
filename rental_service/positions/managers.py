from django.db import models
from django.db.models import Q
from common import common


class PositionManager(models.Manager):

    def get_queryset(self):
        return super(PositionManager, self).get_queryset().filter(active=True)


class FreeManager(models.Manager):

    def get_queryset(self):
        return super(FreeManager, self).get_queryset().filter(active=True)

    def get_free(self):
        from django.db import connection
        cursor = connection.cursor()
        cursor.execute(common.free_positions)
        result_list = list()
        for row in cursor.fetchall():
            p = self.model(id=row[0], name=row[1], responsibilities=row[2], active=row[3])
            #p.num_responses = row[3]
            result_list.append(p)
        return result_list

    def get_taken(self):
        from django.db import connection
        cursor = connection.cursor()
        cursor.execute(common.taken_positions)
        result_list = []
        for row in cursor.fetchall():
            p = self.model(id=row[0], name=row[1], responsibilities=row[2], active=row[3])
            #p.num_responses = row[3]
            result_list.append(p)
        return result_list