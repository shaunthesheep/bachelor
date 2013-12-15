from django.conf.urls import patterns,  url, include


urlpatterns = patterns('',
    url(r'^add/$', 'records.views.add_record', name='add_record'),
    url(r'^list/$', 'records.views.user_records', name='user_records'),
    url(r'^list/$', 'records.views.all_records', name='all_records'),
    (r'^logout/$', 'django.contrib.auth.views.logout', {'next_page': '/'}),
    url(r'', include('django.contrib.auth.urls')),
)