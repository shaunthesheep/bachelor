"""Addresses' parts following /users/ in the url, as defined in rental_service/urls.py.

    Urlpatterns contains addresses combined with proper function from a view and unique identifier.
"""
from django.conf.urls import patterns, url
from .views import UserRegister


urlpatterns = patterns('',
    url(r'^registration/$', UserRegister.as_view(), name='registration'),
    url(r'^login/$', 'django.contrib.auth.views.login', name='login'),
    url(r'(?P<username>\w+)/$', 'users.views.user_profile', name='user_profile'),
    url(r'(?P<username>\w+)/edit/$', 'users.views.edit_user', name='edit_user')
)