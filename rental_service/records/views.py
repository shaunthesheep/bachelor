from annoying.decorators import render_to
from .models import Record
from .forms import AddRecordForm
from common import common
from django.contrib.admin.views.decorators import staff_member_required


@render_to('records/user_records.html')
def user_records(request):
    id = request.user.id
    records = Record.objects.raw(common.user_items(id))
    return {'records': records}


# @render_to('records/user_records.html')
# def available_records(request):
#     records = Record.objects.filter(user=request.user)
#     return {'records': records}


@render_to('records/add_new.html')
def add_record(request):
    form = AddRecordForm(request.POST or None)

    if form.is_valid():
        obj = form.save(commit=False)
        item = obj.item
        period = item.period
        record = Record.objects.filter(user=request.user.id, item=obj.item.id)
        if record.count() == 0:
            obj.save()

        common.update_record(request.user.id, obj.item.id, period)
        return {'form': AddRecordForm()}

    return {'form': form}


#TODO
@staff_member_required
@render_to('records/user_records.html')
def all_records(request):
    #records = Record.objects.all()
    records = Record.objects.raw(common.user_items(request.user.id))
    return {'records': records}