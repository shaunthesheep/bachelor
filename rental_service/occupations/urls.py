"""Addresses' parts following /occupations/ in the url, as defined in rental_service/urls.py.

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
    url(r'^add/$', 'occupations.views.add_occupation', name='add_occupation'),
    url(r'^list/$', 'occupations.views.occupations', name='occupations'),
    url(r'^end_occupation/(?P<id>\d+)/$', 'occupations.views.end_occupation', name='end_occupation'),
    url(r'^renew_occupation/(?P<id>\d+)/$', 'occupations.views.renew_occupation', name='renew_occupation'),
    url(r'^employ/(?P<id>\d+)/$', 'occupations.views.employ', name='employ'),
)