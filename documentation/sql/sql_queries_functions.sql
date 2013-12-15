--most recent valid time value:
select vt[array_length(vt, 1):array_length(vt, 1)] from records_record;

--select rent date and return date YEAH!!!!!!!!!!!!!!!!!!NIE AKTUALNE
SELECT id, 
CASE WHEN array_length(tt, 1) = 1 
THEN to_char(CURRENT_DATE, 'MM/DD/YYYY')
ELSE rent_day(tt, vt) 
END AS rented,
CASE WHEN tt[array_length(tt, 1):array_length(tt, 1)] = ARRAY['0001-01-01']::date[]
THEN ''
ELSE to_char(unnest(tt[array_length(tt, 1):array_length(tt, 1)]), 'MM/DD/YYYY') END AS returned,
to_char(unnest(vt[array_length(vt, 1):array_length(vt, 1)]), 'MM/DD/YYYY') AS due
FROM records_record;

------------------------------------------------------------------------------------------------

-- FUNCTIONS

--XXXreturns transaction time of rent start YEAH@!!!!!!!!!!!!!!!!!!
CREATE OR REPLACE FUNCTION rent_day(date[], int)
RETURNS varchar
AS
$$
DECLARE
	valid ALIAS FOR $1;
	period ALIAS FOR $2;
	len int;
	idx int;
BEGIN
	IF valid IS NULL THEN
		RETURN '';
	END IF;

	len = array_length(valid, 1);

	IF len = 1 OR len = period THEN
		RETURN to_char(valid[1], 'MM/DD/YYYY');
	END IF;
	
	idx = len - period + 1;
	
RETURN to_char(unnest(valid[idx:idx]), 'MM/DD/YYYY');
END;
$$
LANGUAGE plpgsql;

--XXXindex
CREATE INDEX duration_idx ON occupations_occupation USING GIST(daterange(vs, ve));

--XXXindex
CREATE INDEX transaction_idx ON records_record USING GIN(tt);

--XXXindex
CREATE INDEX valid_idx ON records_record USING GIN(vt);

--XXXreturns last value of array or null if record doeas not exist YEAH@!!!!!!!!!!!!!!!!!!
CREATE OR REPLACE FUNCTION get_day_or_null(date[])
RETURNS varchar
AS
$$
DECLARE
	the_array ALIAS FOR $1;
BEGIN
	IF the_array IS NULL THEN
		RETURN '';
	END IF;
RETURN to_char(unnest(the_array[array_length(the_array, 1):array_length(the_array, 1)]), 'MM/DD/YYYY');
END;
$$
LANGUAGE plpgsql;

------------------------------------


CREATE OR REPLACE FUNCTION get_day_raw(date[])
RETURNS date
AS
$$
DECLARE
	the_array ALIAS FOR $1;
BEGIN
	IF the_array IS NULL THEN
		RETURN '';
	END IF;
RETURN unnest(the_array[array_length(the_array, 1):array_length(the_array, 1)]);
END;
$$
LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION raw_rent_day(date[], int)
RETURNS date
AS
$$
DECLARE
	valid ALIAS FOR $1;
	period ALIAS FOR $2;
	len int;
	idx int;
BEGIN
	IF valid IS NULL THEN
		RETURN '';
	END IF;

	len = array_length(valid, 1);

	IF len = 1 OR len = period THEN
		RETURN unnest(valid[1]);
	END IF;
	
	idx = len - period + 1;
	
RETURN unnest(valid[idx:idx]);
END;
$$
LANGUAGE plpgsql;



--XXXselect detailed info about items YEAH@!!!!!!!!!!!!!!!!!!
CREATE OR REPLACE FUNCTION distinct_item_details()
  RETURNS TABLE (
   id   	int
  ,name		varchar(128)
  ,model   	varchar(128)
  ,period 	int
  ,penalty	numeric(8,2)
  ,available	boolean
  ,rented	text
  ,returned	text
  ,due		text
  ) AS
$func$
BEGIN

   RETURN QUERY

SELECT rid AS id, rname AS name, rmodel AS model, rperiod AS period, rpenalty AS penalty, ravailable AS available, 
max(result.all_rented) AS rented,
max(result.all_returned) AS returned,
max(result.all_due) as due FROM (

SELECT i.id AS rid, i.name AS rname, i.model AS rmodel, i.period AS rperiod, i.penalty AS rpenalty, i.availability AS ravailable, 
	CASE WHEN array_length(r.tt, 1) = 1 THEN CURRENT_DATE ELSE raw_rent_day(r.vt, i.period) END AS all_rented,
	CASE WHEN r.tt[array_length(r.tt, 1):array_length(r.tt, 1)] = ARRAY['0001-01-01']::date[] 
	       THEN '3001-01-01' ELSE get_day_or_null(r.tt)
	        END AS all_returned,
	get_day_or_null(r.vt) AS all_due
FROM items_item i LEFT OUTER JOIN 
records_record r  ON i.id = r.item_id) AS result GROUP BY result.rid, result.rname, result.rmodel, result.rperiod, result.rpenalty, result.ravailable;


END
$func$  LANGUAGE plpgsql;



------------------------

--XXXselect detailed info about items YEAH@!!!!!!!!!!!!!!!!!!
CREATE OR REPLACE FUNCTION item_details()
  RETURNS TABLE (
   id   	int
  ,name		varchar(128)
  ,model   	varchar(128)
  ,period 	int
  ,penalty	numeric(8,2)
  ,available	boolean
  ,rented	varchar(10)
  ,returned	varchar(10)
  ,due		varchar(10)
  ) AS
$func$
BEGIN

   RETURN QUERY

SELECT i.id AS id, i.name AS name, i.model AS model, i.period AS period, i.penalty AS penalty, i.availability AS available, 
	CASE WHEN array_length(r.tt, 1) = 1 THEN to_char(CURRENT_DATE, 'MM/DD/YYYY') ELSE rent_day(r.vt, i.period) END AS all_rented,
	CASE WHEN r.tt[array_length(r.tt, 1):array_length(r.tt, 1)] = ARRAY['0001-01-01']::date[] 
	       THEN '3001-01-01' ELSE get_day_or_null(r.tt)
	        END AS all_returned,
	get_day_or_null(r.vt) AS all_due
FROM items_item i LEFT OUTER JOIN 
records_record r  ON i.id = r.item_id ORDER BY rented DESC;

END;
$func$  LANGUAGE plpgsql;



--XXXselect detailed info about items rented by particular person
CREATE OR REPLACE FUNCTION user_item_details(int)
  RETURNS TABLE (
  username	varchar(30)
  ,id   	int
  ,name		varchar(128)
  ,model   	varchar(128)
  ,period 	int
  ,penalty	numeric(8,2)
  ,available	boolean
  ,rented	varchar(10)
  ,returned	varchar(10)
  ,due		varchar(10)
  ) AS
$func$
DECLARE
	theid ALIAS FOR $1;
BEGIN

   RETURN QUERY
SELECT au.username AS username, i.id AS id, i.name AS name, i.model AS model, i.period AS period, i.penalty AS penalty, i.availability AS available, 
	CASE WHEN array_length(r.tt, 1) = 1 THEN to_char(CURRENT_DATE, 'MM/DD/YYYY') ELSE rent_day(r.vt, i.period) END AS rented,
	CASE WHEN r.tt[array_length(r.tt, 1):array_length(r.tt, 1)] = ARRAY['0001-01-01']::date[] 
	       THEN '' ELSE get_day_or_null(r.tt)
	        END AS returned,
	get_day_or_null(r.vt) AS due
FROM items_item i LEFT OUTER JOIN records_record r  ON i.id = r.item_id JOIN auth_user au ON au.id = r.user_id
WHERE au.id = theid;

END
$func$  LANGUAGE plpgsql;


--XXXselect free items
CREATE OR REPLACE FUNCTION free_items()
  RETURNS TABLE (
  id   	int
  ,name		varchar(128)
  ,model   	varchar(128)
  ,period 	int
  ,penalty	numeric(8,2)
  ,available	boolean
  ) AS
$func$
BEGIN

   RETURN QUERY
SELECT * FROM items_item i WHERE availability = TRUE AND i.id NOT IN (SELECT item_id FROM records_record WHERE tt @> ARRAY[to_date('0001-01-01','YYYY-MM-DD')]);

END
$func$  LANGUAGE plpgsql;
 
--XXXselect occupied items
CREATE OR REPLACE FUNCTION occupied_items()
  RETURNS TABLE (
  id   	int
  ,name		varchar(128)
  ,model   	varchar(128)
  ,period 	int
  ,penalty	numeric(8,2)
  ,available	boolean
  ) AS
$func$
BEGIN

   RETURN QUERY
SELECT * FROM items_item i WHERE availability = TRUE AND i.id IN (SELECT item_id FROM records_record WHERE tt @> ARRAY[to_date('0001-01-01','YYYY-MM-DD')]);

END
$func$  LANGUAGE plpgsql;


--XXXreturn item
CREATE OR REPLACE FUNCTION return_item(int, int)
RETURNS text AS
$$
DECLARE
	the_user ALIAS FOR $1;
	the_item ALIAS FOR $2;
	myoutput text :='OK';
BEGIN
	UPDATE records_record SET tt =  array_remove(
					(SELECT tt FROM records_record WHERE user_id = the_user AND item_id = the_item), to_date('0001-01-01','YYYY-MM-DD'))
					WHERE user_id = the_user AND item_id = the_item;
	UPDATE records_record SET vt = vt[1:array_length(tt,1)] WHERE user_id = the_user AND item_id = the_item;
	RETURN myoutput;
END;
$$
LANGUAGE plpgsql;



UPDATE records_record SET tt = tt || tt[(array_length(tt,1)):array_length(tt,1)] WHERE id=5;
PERFORM array_remove((select tt from records_record), to_date('0001-01-01','YYYY-MM-DD'));

-- trigger instead of delete records, update
 CREATE TRIGGER return_item_trigger
 INSTEAD OF DELETE ON records_record
 REFERENCING
 	OLD TABLE AS OldRecords,
 	NEW TABLE AS NewRecords
 FOR EACH STATEMENT
DECLARE 
	idx int;
	found boolean,
 --WHEN (NewPrice.price > (SELECT MIN(OldPrice.price) FROM OdlPrice WHERE NewPrice.speed = OldPrice.speed))
 BEGIN
	idx = array_length(tt,1);
	found = false;
	IF tt[1] = to_date('0001-01-01', 'YYYY-MM-DD') THEN
		idx = 1;
		found = true;
	ELSE
		WHILE idx > 0 AND found = False LOOP
    			IF tt[idx] <> to_date('0001-01-01', 'YYYY-MM-DD')
				found = true;
			ELSE
				idx = idx - 1;
			END IF;
		END LOOP;
	END IF;
	WHILE idx < array_length(tt,1);
		idx = idx + 1;
		UPDATE records_record SET tt[idx] = CURRENT_DATE;
	END LOOP;	
 END;


