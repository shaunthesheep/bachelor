from django.conf.urls import patterns,  url


urlpatterns = patterns('',
    url(r'^add/$', 'occupations.views.add_occupation', name='add_occupation'),
    url(r'^list/$', 'occupations.views.occupations', name='occupations'),
    url(r'^end_occupation/(?P<id>\d+)/$', 'occupations.views.end_occupation', name='end_occupation'),
    url(r'^renew_occupation/(?P<id>\d+)/$', 'occupations.views.renew_occupation', name='renew_occupation'),
    url(r'^employ/(?P<id>\d+)/$', 'occupations.views.employ', name='employ'),
)