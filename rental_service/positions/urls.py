from django.conf.urls import patterns,  url


urlpatterns = patterns('',
    url(r'^add/$', 'positions.views.add_position', name='add_position'),
    url(r'^list/$', 'positions.views.positions', name='positions'),
    url(r'^free/$', 'positions.views.free_positions', name='free_positions'),
    url(r'^taken/$', 'positions.views.taken_positions', name='taken_positions'),
    url(r'^delete/(?P<id>\d+)/$', 'positions.views.delete_position', name='delete_position')
)