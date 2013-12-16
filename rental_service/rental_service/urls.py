"""Urlpatterns contains addresses fragments and redirects to proper urls.py file."""
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

    # Uncomment the next line to enable the admin:
    url(r'^admin/', include(admin.site.urls)),
)
