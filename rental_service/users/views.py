from annoying.decorators import render_to
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.shortcuts import get_object_or_404
from django.views.generic import CreateView
from .forms import UserRegisterForm
from items.models import Item
from occupations.models import Occupation
from common import common


class UserRegister(CreateView):
    form_class = UserRegisterForm
    template_name = 'users/registration.html'


@login_required
@render_to('users/registration.html')
def edit_user(request, username):
    user = get_object_or_404(User, username=username)
    user_form = UserRegisterForm(request.POST or None, instance=user)
    if user_form.is_valid():
        user_form.save()
    return {'form': user_form}


@login_required
@render_to('users/profile.html')
def user_profile(request, username):
    user = get_object_or_404(User, username=username)
    timed_records = Item.objects.raw(common.user_items(user.id))
    counter = sum(1 for rec in timed_records)

    try:
        pos_record = Occupation.objects.get(user=request.user, ve=common.future_now)
        position = pos_record.position
    except Occupation.DoesNotExist:
        position = None


    return {'user': user,
            'count': counter,
            'timed_records' : timed_records,
            'position' : position}