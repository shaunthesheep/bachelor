"""Addresses' parts following /records/ in the url, as defined in rental_service/urls.py.

    Urlpatterns contains addresses combined with proper function from a view and unique identifier.
"""
from django.conf.urls import patterns,  url, include

__author__ = 'Anna Bomersbach'
__credits__ = ['Anna Bomersbach', 'Tomasz Kubik']

__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = 'Anna Bomersbach'
__email__ = "184779@student.pwr.wroc.pl"
__status__ = 'Production'


urlpatterns = patterns('',
    url(r'^add/$', 'records.views.add_record', name='add_record'),
    url(r'^list/$', 'records.views.user_records', name='user_records'),
    (r'^logout/$', 'django.contrib.auth.views.logout', {'next_page': '/'}),
    url(r'', include('django.contrib.auth.urls')),
)