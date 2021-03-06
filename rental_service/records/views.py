from annoying.decorators import render_to
from .models import Record
from .forms import AddRecordForm
from common import common

__author__ = 'Anna Bomersbach'
__credits__ = ['Anna Bomersbach', 'Tomasz Kubik']

__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = 'Anna Bomersbach'
__email__ = "184779@student.pwr.wroc.pl"
__status__ = 'Production'


@render_to('records/user_records.html')
def user_records(request):
    """Executes SQL function to obtain information on user rental history."""
    id = request.user.id
    records = Record.objects.raw(common.user_items(id))
    return {'records': records}


@render_to('records/add_new.html')
def add_record(request):
    """Creates an instance of a form, sets omitted value and saves and object if valid.
       Executes raw update SQL query to populate arrays of the tuple with temporal data."""
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