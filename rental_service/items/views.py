from annoying.decorators import render_to
from django.db import connection
from django.shortcuts import get_object_or_404
from common import common
from .forms import AddItemForm
from .models import Item
from django.contrib.admin.views.decorators import staff_member_required
from django.views.decorators.http import require_POST
from django.http import HttpResponse
from records.models import Record

__author__ = 'Anna Bomersbach'
__credits__ = ['Anna Bomersbach', 'Tomasz Kubik']

__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = 'Anna Bomersbach'
__email__ = "184779@student.pwr.wroc.pl"
__status__ = 'Production'


@staff_member_required
@render_to('items/add_new_item.html')
def add_item(request):
    """Creates an instance of a form, sets omitted value and saves and object if valid."""
    item_form = AddItemForm(request.POST or None)

    if item_form.is_valid():
        obj = item_form.save(commit=False)
        obj.availability = True
        obj.save()

        return {'form': AddItemForm()}
    return {'form': item_form}


@render_to('items/free_item_list.html')
def free_item_list(request):
    """Gets list of currently not occupied items."""
    items = Item.objects.raw(common.free_items)
    counter = sum(1 for rec in items)
    return {'free_items': items,
            'counter': counter}


@render_to('items/item_list.html')
def item_list(request):
    """Gets whole list of items and passes it to a template."""
    items = Item.objects.all()
    return {'items': items}


@staff_member_required
@render_to('items/item_detailed_list.html')
def item_detailed_list(request):
    """Selects values of items its with information on dates of its rentals."""
    item_records = Item.objects.raw(common.item_details)
    return {'items': item_records}


@require_POST
def request_item(request, id):
    """Gets an instance of particular record if exists, else creates it. Updates arrays of the tuple."""
    obj, created = Record.objects.get_or_create(user=request.user, item=Item.objects.get(id=id))
    obj.save()
    period = Item.objects.get(id=id).period
    common.update_record(request.user.id, id, period)
    return HttpResponse('OK')


@staff_member_required
@render_to('items/edit_item.html')
def edit_item(request, id):
    """Creates an instance of a form with item object data, sets omitted value and saves and object if valid."""
    item = get_object_or_404(Item, pk=id)
    item_form = AddItemForm(request.POST or None, request.FILES or None, instance=item)

    if item_form.is_valid():
        obj = item_form.save(commit=False)
        obj.availability = True
        obj.save()

    return {'form': item_form}


@require_POST
def return_item(request, id):
    """Executes return_item function from common module"""
    cursor = connection.cursor()
    cursor.execute(common.return_item(request.user.id, id))
    return HttpResponse('OK')


@staff_member_required
@require_POST
def remove_item(request, id):
    """Deactivates chosen item."""
    obj = get_object_or_404(Item, id=id)
    obj.availability = False
    obj.save()
    return HttpResponse('OK')