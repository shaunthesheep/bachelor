from django.conf.urls import patterns, url


urlpatterns = patterns('',
    url(r'^add/$', 'items.views.add_item', name='add_item'),
    url(r'^list/$', 'items.views.item_list', name='item_list'),
    url(r'^free/$', 'items.views.free_item_list', name='free_item_list'),
    url(r'^history/$', 'items.views.item_detailed_list', name='stock'),
    url(r'^edit/(?P<id>\d+)/$', 'items.views.edit_item', name='edit_item'),
    url(r'^request/(?P<id>\d+)/$', 'items.views.request_item', name='request_item'),
    url(r'^return/(?P<id>\d+)/$', 'items.views.return_item', name='return_item'),
    url(r'^remove/(?P<id>\d+)/$', 'items.views.remove_item', name='remove_item'),
)