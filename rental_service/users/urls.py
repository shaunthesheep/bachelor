from django.conf.urls import patterns, include, url
from .views import UserRegister


urlpatterns = patterns('',
    url(r'^registration/$', UserRegister.as_view(), name='registration'),
    url(r'^login/$', 'django.contrib.auth.views.login', name='login'),
    url(r'(?P<username>\w+)/$', 'users.views.user_profile', name='user_profile'),
    url(r'(?P<username>\w+)/edit/$', 'users.views.edit_user', name='edit_user')
)