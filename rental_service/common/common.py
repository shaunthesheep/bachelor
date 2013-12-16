"""Provides constants and functions for managing data in database using SQL language.

Logical_now is a constant used as 'Until Changed' chronon in Record relation.
Future_now is a constant used as 'now' chronon in Occupation relation. It needs to be always bigger
than current date in order for a proper index to be created.

Strings: free_items, occupied_items, item_details, free_positions, taken_positions
are defined for executing raw SQL commands to be more readable, as well as in order to keep all SQL code
in one place.

Functions: user_items(id_value), return_item(user_id, item_id) support retrieving filtered data from DB.

Function: update_record(user, item, period) is to construct a proper SQL query for DB update when:
- adding new rental record
- refreshing database
"""

from datetime import datetime, timedelta
from django.db import connection

logical_now = '0001-01-01'
future_now = datetime.strptime('3001-01-01', "%Y-%m-%d")

free_items = 'SELECT * FROM free_items()'

occupied_items = 'SELECT * FROM occupied_items()'

item_details = 'select * from item_details()'


def user_items(id_value):
    return 'select * from user_item_details(' + str(id_value) + ')'


def return_item(user_id, item_id):
    return 'select return_item(' + str(user_id) + ', ' + str(item_id) + ')'

free_positions = """
        SELECT DISTINCT p.id, p.name, p.responsibilities, p.active
        FROM positions_position p
        LEFT OUTER JOIN occupations_occupation o ON p.id = o.position_id
        WHERE p.active = True AND (o.ve IS NULL OR
        p.id NOT IN (SELECT o2.position_id FROM occupations_occupation o2 WHERE o2.ve = '3001-01-01'))"""

taken_positions = """
        SELECT DISTINCT p.id, p.name, p.responsibilities, p.active
        FROM positions_position p
        JOIN occupations_occupation o ON p.id = o.position_id
        WHERE p.active = True AND o.ve = '3001-01-01' """


def update_record(user, item, period):
    now = datetime.now().date()
    cursor = connection.cursor()
    update_tt = "UPDATE records_record SET tt = tt || array[ "
    update_vt = "UPDATE records_record SET vt = vt || array[ "
    #add tt - today + vt for each valid day
    for i in range(period):
        due = (datetime.now()+timedelta(days=i)).date()
        update_tt += "to_date(\'" + str(now) + "\', \'YYYY-MM-DD\'), "
        update_vt += "to_date(\'" + str(due) + "\', \'YYYY-MM-DD\'), "
    #add logical now at the end
    for i in range(period-1):
        due = (datetime.now()+timedelta(days=i)).date()
        update_tt += "to_date(\'" + logical_now + "\', \'YYYY-MM-DD\'), "
        update_vt += "to_date(\'" + str(due) + "\', \'YYYY-MM-DD\'), "
    due = (datetime.now()+timedelta(days=period-1)).date()
    selector = " WHERE user_id = " + str(user) + " AND item_id = " + str(item)
    update_tt += "to_date(\'" + logical_now + "\', \'YYYY-MM-DD\')]" + selector
    update_vt += "to_date(\'" + str(due) + "\', \'YYYY-MM-DD\')]" + selector

    cursor.execute(update_tt)
    cursor.execute(update_vt)