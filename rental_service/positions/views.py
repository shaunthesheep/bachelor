from annoying.decorators import render_to
from django.shortcuts import get_object_or_404
from django.views.decorators.http import require_POST
from .models import Position
from .forms import AddPositionForm
from django.http import HttpResponse
from django.contrib.admin.views.decorators import staff_member_required


@staff_member_required
@render_to('positions/add_new.html')
def add_position(request):
    form = AddPositionForm(request.POST or None)

    if form.is_valid():
        form.save()
        return {'form': AddPositionForm()}

    return {'form': form}


@render_to('positions/list_all.html')
def positions(request):
    pos = Position.objects.all()
    return {'positions': pos}


@render_to('positions/free.html')
def free_positions(request):
    pos = Position.free.get_free()
    return {'positions': pos}


@render_to('positions/taken.html')
def taken_positions(request):
    pos = Position.free.get_taken()
    return {'positions': pos}


@staff_member_required
@require_POST
def delete_position(request, id):
    pos = get_object_or_404(Position.objects.filter(active=True), pk=id)
    pos.active = False
    pos.save()

    return HttpResponse('OK')