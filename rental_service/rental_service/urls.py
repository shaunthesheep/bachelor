from django.conf.urls import patterns, include, url

# Uncomment the next two lines to enable the admin:
from django.contrib import admin
from django.views.generic import TemplateView

admin.autodiscover()


urlpatterns = patterns('',
    url(r'^items/', include('items.urls')),
    url(r'^records/', include('records.urls')),
    url(r'^$', TemplateView.as_view(template_name='index.html'), name='index'),
    url(r'^users/', include('users.urls')),
    url(r'^positions/', include('positions.urls')),
    url(r'^occupations/', include('occupations.urls')),
    #url(r'^items/', include('items.urls')),
    #url(r'^contacts/', include('contacts.urls')),
    #url(r'^wall/', include('wall.urls')),
    # Examples:
    # url(r'^$', 'rental_service.views.home', name='home'),
    # url(r'^rental_service/', include('rental_service.foo.urls')),

    # Uncomment the admin/doc line below to enable admin documentation:
    # url(r'^admin/doc/', include('django.contrib.admindocs.urls')),

    # Uncomment the next line to enable the admin:
    url(r'^admin/', include(admin.site.urls)),
)
