"""Addresses' parts following /positionss/ in the url, as defined in rental_service/urls.py.

    Urlpatterns contains addresses combined with proper function from a view and unique identifier.
"""
from django.conf.urls import patterns,  url

__author__ = 'Anna Bomersbach'
__credits__ = ['Anna Bomersbach', 'Tomasz Kubik']

__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = 'Anna Bomersbach'
__email__ = "184779@student.pwr.wroc.pl"
__status__ = 'Production'


urlpatterns = patterns('',
    url(r'^add/$', 'positions.views.add_position', name='add_position'),
    url(r'^list/$', 'positions.views.positions', name='positions'),
    url(r'^free/$', 'positions.views.free_positions', name='free_positions'),
    url(r'^taken/$', 'positions.views.taken_positions', name='taken_positions'),
    url(r'^delete/(?P<id>\d+)/$', 'positions.views.delete_position', name='delete_position')
)