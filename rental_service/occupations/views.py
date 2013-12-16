from annoying.decorators import render_to
from datetime import date
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth.models import User
from django.shortcuts import get_object_or_404
from django.views.decorators.http import require_POST
from common import common
from .models import Occupation
from .forms import AddOccupationForm, EmployForm
from django.http import HttpResponse
from positions.models import Position


@render_to('occupations/add_new.html')
def add_occupation(request):
    """Creates an instance of a form, sets omitted value and saves and object if valid."""
    form = AddOccupationForm(request.POST or None)
    if form.is_valid():
        form.save()
        return {'form': AddOccupationForm()}

    return {'form': form}


@render_to('occupations/list_all.html')
def occupations(request):
    """Gets all history of employment."""
    occups = Occupation.objects.all().order_by('-vs')
    return {'occups': occups}


@require_POST
def end_occupation(request, id):
    """Sets occupation end date to current date. Used when dismissing an employee."""
    o_record = get_object_or_404(Occupation, id=id)
    o_record.ve = date.today()
    o_record.save()
    return HttpResponse('OK')


@staff_member_required
@require_POST
def renew_occupation(request, id):
    """Creates an new instance of occupation record that was already valid before."""
    o_record = get_object_or_404(Occupation, id=id)
    employee = o_record.user
    job = o_record.position
    obj = Occupation.objects.create(user=employee, position=job)
    obj.vs = date.today()
    obj.ve = common.future_now
    obj.save()
    return HttpResponse('OK')


@staff_member_required
@render_to('occupations/employ.html')
def employ(request, id):
    """Creates an instance of a form, with a set position, for admin to choose a user for the position."""
    position = get_object_or_404(Position, pk=id)
    form = EmployForm(request.POST or None)

    if form.is_valid():
        obj = form.save(commit=False)
        obj.position = position
        obj.vs = date.today()
        obj.ve = common.future_now
        obj.save()

    return {'form': form,
            'position': position}