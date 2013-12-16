"""Addresses' parts following /records/ in the url, as defined in rental_service/urls.py.

    Urlpatterns contains addresses combined with proper function from a view and unique identifier.
"""
from django.conf.urls import patterns,  url, include


urlpatterns = patterns('',
    url(r'^add/$', 'records.views.add_record', name='add_record'),
    url(r'^list/$', 'records.views.user_records', name='user_records'),
    (r'^logout/$', 'django.contrib.auth.views.logout', {'next_page': '/'}),
    url(r'', include('django.contrib.auth.urls')),
)