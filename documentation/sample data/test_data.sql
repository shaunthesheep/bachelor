--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: distinct_item_details(); Type: FUNCTION; Schema: public; Owner: anna
--

CREATE FUNCTION distinct_item_details() RETURNS TABLE(id integer, name character varying, model character varying, period integer, penalty numeric, available boolean, rented text, returned text, due text)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.distinct_item_details() OWNER TO anna;

--
-- Name: free_items(); Type: FUNCTION; Schema: public; Owner: anna
--

CREATE FUNCTION free_items() RETURNS TABLE(id integer, name character varying, model character varying, period integer, penalty numeric, available boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN

   RETURN QUERY
SELECT * FROM items_item i WHERE availability = TRUE AND i.id NOT IN (SELECT item_id FROM records_record WHERE tt @> ARRAY[to_date('0001-01-01','YYYY-MM-DD')]);

END
$$;


ALTER FUNCTION public.free_items() OWNER TO anna;

--
-- Name: get_day_or_null(date[]); Type: FUNCTION; Schema: public; Owner: anna
--

CREATE FUNCTION get_day_or_null(date[]) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
the_array ALIAS FOR $1;
BEGIN
IF the_array IS NULL THEN
RETURN '';
END IF;
RETURN to_char(unnest(the_array[array_length(the_array, 1):array_length(the_array, 1)]), 'MM/DD/YYYY');
END;
$_$;


ALTER FUNCTION public.get_day_or_null(date[]) OWNER TO anna;

--
-- Name: get_day_raw(date[]); Type: FUNCTION; Schema: public; Owner: anna
--

CREATE FUNCTION get_day_raw(date[]) RETURNS date
    LANGUAGE plpgsql
    AS $_$
DECLARE
the_array ALIAS FOR $1;
BEGIN
IF the_array IS NULL THEN
RETURN '';
END IF;
RETURN unnest(the_array[array_length(the_array, 1):array_length(the_array, 1)]);
END;
$_$;


ALTER FUNCTION public.get_day_raw(date[]) OWNER TO anna;

--
-- Name: item_details(); Type: FUNCTION; Schema: public; Owner: anna
--

CREATE FUNCTION item_details() RETURNS TABLE(id integer, name character varying, model character varying, period integer, penalty numeric, available boolean, rented character varying, returned character varying, due character varying)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.item_details() OWNER TO anna;

--
-- Name: occupied_items(); Type: FUNCTION; Schema: public; Owner: anna
--

CREATE FUNCTION occupied_items() RETURNS TABLE(id integer, name character varying, model character varying, period integer, penalty numeric, available boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN

   RETURN QUERY
SELECT * FROM items_item i WHERE availability = TRUE AND i.id IN (SELECT item_id FROM records_record WHERE tt @> ARRAY[to_date('0001-01-01','YYYY-MM-DD')]);

END
$$;


ALTER FUNCTION public.occupied_items() OWNER TO anna;

--
-- Name: raw_rent_day(date[], integer); Type: FUNCTION; Schema: public; Owner: anna
--

CREATE FUNCTION raw_rent_day(date[], integer) RETURNS date
    LANGUAGE plpgsql
    AS $_$
DECLARE
valid ALIAS FOR $1;
period ALIAS FOR $2;
len int;
idx int;
BEGIN
IF valid IS NULL THEN
RETURN NULL;
END IF;

len = array_length(valid, 1);

IF len = 1 OR len = period THEN
RETURN unnest(valid[1]);
END IF;

idx = len - period + 1;

RETURN unnest(valid[idx:idx]);
END;
$_$;


ALTER FUNCTION public.raw_rent_day(date[], integer) OWNER TO anna;

--
-- Name: rent_day(date[], integer); Type: FUNCTION; Schema: public; Owner: anna
--

CREATE FUNCTION rent_day(date[], integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.rent_day(date[], integer) OWNER TO anna;

--
-- Name: return_item(integer, integer); Type: FUNCTION; Schema: public; Owner: anna
--

CREATE FUNCTION return_item(integer, integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.return_item(integer, integer) OWNER TO anna;

--
-- Name: user_item_details(integer); Type: FUNCTION; Schema: public; Owner: anna
--

CREATE FUNCTION user_item_details(integer) RETURNS TABLE(username character varying, id integer, name character varying, model character varying, period integer, penalty numeric, available boolean, rented character varying, returned character varying, due character varying)
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.user_item_details(integer) OWNER TO anna;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: auth_group; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE auth_group (
    id integer NOT NULL,
    name character varying(80) NOT NULL
);


ALTER TABLE public.auth_group OWNER TO anna;

--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_group_id_seq OWNER TO anna;

--
-- Name: auth_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE auth_group_id_seq OWNED BY auth_group.id;


--
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE auth_group_permissions (
    id integer NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_group_permissions OWNER TO anna;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_group_permissions_id_seq OWNER TO anna;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE auth_group_permissions_id_seq OWNED BY auth_group_permissions.id;


--
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE auth_permission (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


ALTER TABLE public.auth_permission OWNER TO anna;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_permission_id_seq OWNER TO anna;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE auth_permission_id_seq OWNED BY auth_permission.id;


--
-- Name: auth_user; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE auth_user (
    id integer NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone NOT NULL,
    is_superuser boolean NOT NULL,
    username character varying(30) NOT NULL,
    first_name character varying(30) NOT NULL,
    last_name character varying(30) NOT NULL,
    email character varying(75) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL
);


ALTER TABLE public.auth_user OWNER TO anna;

--
-- Name: auth_user_groups; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE auth_user_groups (
    id integer NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


ALTER TABLE public.auth_user_groups OWNER TO anna;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE auth_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_user_groups_id_seq OWNER TO anna;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE auth_user_groups_id_seq OWNED BY auth_user_groups.id;


--
-- Name: auth_user_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE auth_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_user_id_seq OWNER TO anna;

--
-- Name: auth_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE auth_user_id_seq OWNED BY auth_user.id;


--
-- Name: auth_user_user_permissions; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE auth_user_user_permissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_user_user_permissions OWNER TO anna;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE auth_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_user_user_permissions_id_seq OWNER TO anna;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE auth_user_user_permissions_id_seq OWNED BY auth_user_user_permissions.id;


--
-- Name: dbarray_chars; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE dbarray_chars (
    id integer NOT NULL,
    arr character varying(10)[]
);


ALTER TABLE public.dbarray_chars OWNER TO anna;

--
-- Name: dbarray_chars_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE dbarray_chars_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dbarray_chars_id_seq OWNER TO anna;

--
-- Name: dbarray_chars_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE dbarray_chars_id_seq OWNED BY dbarray_chars.id;


--
-- Name: dbarray_dates; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE dbarray_dates (
    id integer NOT NULL,
    arr date[]
);


ALTER TABLE public.dbarray_dates OWNER TO anna;

--
-- Name: dbarray_dates_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE dbarray_dates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dbarray_dates_id_seq OWNER TO anna;

--
-- Name: dbarray_dates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE dbarray_dates_id_seq OWNED BY dbarray_dates.id;


--
-- Name: dbarray_floats; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE dbarray_floats (
    id integer NOT NULL,
    arr double precision[]
);


ALTER TABLE public.dbarray_floats OWNER TO anna;

--
-- Name: dbarray_floats_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE dbarray_floats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dbarray_floats_id_seq OWNER TO anna;

--
-- Name: dbarray_floats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE dbarray_floats_id_seq OWNED BY dbarray_floats.id;


--
-- Name: dbarray_integers; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE dbarray_integers (
    id integer NOT NULL,
    arr integer[]
);


ALTER TABLE public.dbarray_integers OWNER TO anna;

--
-- Name: dbarray_integers_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE dbarray_integers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dbarray_integers_id_seq OWNER TO anna;

--
-- Name: dbarray_integers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE dbarray_integers_id_seq OWNED BY dbarray_integers.id;


--
-- Name: dbarray_texts; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE dbarray_texts (
    id integer NOT NULL,
    arr text[]
);


ALTER TABLE public.dbarray_texts OWNER TO anna;

--
-- Name: dbarray_texts_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE dbarray_texts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dbarray_texts_id_seq OWNER TO anna;

--
-- Name: dbarray_texts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE dbarray_texts_id_seq OWNED BY dbarray_texts.id;


--
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    user_id integer NOT NULL,
    content_type_id integer,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


ALTER TABLE public.django_admin_log OWNER TO anna;

--
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.django_admin_log_id_seq OWNER TO anna;

--
-- Name: django_admin_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE django_admin_log_id_seq OWNED BY django_admin_log.id;


--
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE django_content_type (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


ALTER TABLE public.django_content_type OWNER TO anna;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.django_content_type_id_seq OWNER TO anna;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE django_content_type_id_seq OWNED BY django_content_type.id;


--
-- Name: django_session; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


ALTER TABLE public.django_session OWNER TO anna;

--
-- Name: django_site; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE django_site (
    id integer NOT NULL,
    domain character varying(100) NOT NULL,
    name character varying(50) NOT NULL
);


ALTER TABLE public.django_site OWNER TO anna;

--
-- Name: django_site_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE django_site_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.django_site_id_seq OWNER TO anna;

--
-- Name: django_site_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE django_site_id_seq OWNED BY django_site.id;


--
-- Name: items_item; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE items_item (
    id integer NOT NULL,
    name character varying(128) NOT NULL,
    model character varying(128),
    period integer NOT NULL,
    penalty numeric(8,2) NOT NULL,
    availability boolean
);


ALTER TABLE public.items_item OWNER TO anna;

--
-- Name: items_item_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE items_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.items_item_id_seq OWNER TO anna;

--
-- Name: items_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE items_item_id_seq OWNED BY items_item.id;


--
-- Name: occupations_occupation; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE occupations_occupation (
    id integer NOT NULL,
    user_id integer NOT NULL,
    position_id integer NOT NULL,
    vs date NOT NULL,
    ve date NOT NULL
);


ALTER TABLE public.occupations_occupation OWNER TO anna;

--
-- Name: occupations_occupation_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE occupations_occupation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.occupations_occupation_id_seq OWNER TO anna;

--
-- Name: occupations_occupation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE occupations_occupation_id_seq OWNED BY occupations_occupation.id;


--
-- Name: positions_position; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE positions_position (
    id integer NOT NULL,
    name character varying(128) NOT NULL,
    responsibilities text,
    active boolean NOT NULL
);


ALTER TABLE public.positions_position OWNER TO anna;

--
-- Name: positions_position_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE positions_position_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.positions_position_id_seq OWNER TO anna;

--
-- Name: positions_position_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE positions_position_id_seq OWNED BY positions_position.id;


--
-- Name: records_record; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE records_record (
    id integer NOT NULL,
    user_id integer NOT NULL,
    item_id integer NOT NULL,
    tt date[],
    vt date[]
);


ALTER TABLE public.records_record OWNER TO anna;

--
-- Name: records_record_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE records_record_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.records_record_id_seq OWNER TO anna;

--
-- Name: records_record_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE records_record_id_seq OWNED BY records_record.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_group ALTER COLUMN id SET DEFAULT nextval('auth_group_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_group_permissions ALTER COLUMN id SET DEFAULT nextval('auth_group_permissions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_permission ALTER COLUMN id SET DEFAULT nextval('auth_permission_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_user ALTER COLUMN id SET DEFAULT nextval('auth_user_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_user_groups ALTER COLUMN id SET DEFAULT nextval('auth_user_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_user_user_permissions ALTER COLUMN id SET DEFAULT nextval('auth_user_user_permissions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY dbarray_chars ALTER COLUMN id SET DEFAULT nextval('dbarray_chars_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY dbarray_dates ALTER COLUMN id SET DEFAULT nextval('dbarray_dates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY dbarray_floats ALTER COLUMN id SET DEFAULT nextval('dbarray_floats_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY dbarray_integers ALTER COLUMN id SET DEFAULT nextval('dbarray_integers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY dbarray_texts ALTER COLUMN id SET DEFAULT nextval('dbarray_texts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY django_admin_log ALTER COLUMN id SET DEFAULT nextval('django_admin_log_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY django_content_type ALTER COLUMN id SET DEFAULT nextval('django_content_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY django_site ALTER COLUMN id SET DEFAULT nextval('django_site_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY items_item ALTER COLUMN id SET DEFAULT nextval('items_item_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY occupations_occupation ALTER COLUMN id SET DEFAULT nextval('occupations_occupation_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY positions_position ALTER COLUMN id SET DEFAULT nextval('positions_position_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY records_record ALTER COLUMN id SET DEFAULT nextval('records_record_id_seq'::regclass);


--
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY auth_group (id, name) FROM stdin;
\.


--
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('auth_group_id_seq', 1, false);


--
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY auth_group_permissions (id, group_id, permission_id) FROM stdin;
\.


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('auth_group_permissions_id_seq', 1, false);


--
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY auth_permission (id, name, content_type_id, codename) FROM stdin;
1	Can add permission	1	add_permission
2	Can change permission	1	change_permission
3	Can delete permission	1	delete_permission
4	Can add group	2	add_group
5	Can change group	2	change_group
6	Can delete group	2	delete_group
7	Can add user	3	add_user
8	Can change user	3	change_user
9	Can delete user	3	delete_user
\.


--
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('auth_permission_id_seq', 9, true);


--
-- Data for Name: auth_user; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY auth_user (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined) FROM stdin;
1	pbkdf2_sha256$12000$UFzaviRtzIdT$+fSs+YuU/0i0S8ycM+r49+vs2NHpa1hqbdEZ5jV+M8g=	2013-12-13 01:10:54.201481+01	t	anna	Anna	Bomersbach	anna.bomersbach@gmail.com	t	t	2013-12-04 22:56:01.529727+01
2	pbkdf2_sha256$12000$Oz5bKtiHOf6o$P4oVP1rlUYYVyjY8uJWxgYHjAlzbiucd5aIx4ET182Y=	2013-12-10 20:50:15.657436+01	f	baradam	Bartosz	Adamski	baradan@example.com	f	t	2013-12-10 20:50:15.657598+01
3	pbkdf2_sha256$12000$uSopFQxp8OWa$x4vt3pCIglIm8sOWyWnDkJDA/jCmjPnuPGcMq4RHjvQ=	2013-12-10 20:50:57.93533+01	f	rymacie	Ryszard	Maciejewski	rymacie@example.com	f	t	2013-12-10 20:50:57.935413+01
5	pbkdf2_sha256$12000$0sXh0QQmYTAa$d4PhlPWsWz36Vj81xvfk3VS+2Z5K/4PtoUHLZ/4MLTw=	2013-12-10 20:52:12.518981+01	f	konnowi	Kondrat	Nowicki	konnowi@example.com	f	t	2013-12-10 20:52:12.519145+01
4	pbkdf2_sha256$12000$YWg2wdiglrTB$bRgqm2Uxa7yXlRYy8Q7fcltJScZ9LPJ2a3+jFGhewbI=	2013-12-12 23:16:17.795265+01	f	kasawi	Kasia	Sawicka	kasawi@example.com	f	t	2013-12-10 20:51:34.258515+01
6	pbkdf2_sha256$12000$nXVnq730pa7z$N+w5BhVMDgiSYlxHFAF5LFo4g83AMVOp8TegN4fr7gs=	2013-12-12 15:37:07.251302+01	f	kryos	Krystiana	Ostrowska	kryos@example.com	f	t	2013-12-12 15:37:07.251378+01
7	pbkdf2_sha256$12000$MMSMS8QaA8jc$cW1COyiuqVOh8LajFRU6EazuXm4EFTFBMozZIHV0ZSY=	2013-12-12 15:37:41.341162+01	f	tymich	Tytus	Michalski	tymich@example.com	f	t	2013-12-12 15:37:41.341328+01
8	pbkdf2_sha256$12000$XxopBqfkYRqs$OWMM4LgMEGF52+zGIgrjf+ikSikXvl0vk8Wl049MxMM=	2013-12-12 15:38:20.432289+01	f	barwy	Bartłomiej	Wysocki	barwy@example.com	f	t	2013-12-12 15:38:20.432433+01
9	pbkdf2_sha256$12000$cgwDnr7Tw1Y3$TEvDrHwjlqzkpJwqQJ0LiGDomC0GS3bwOwCmw3pDRc4=	2013-12-12 15:38:54.378612+01	f	pajaw	Paweł	Jaworski	pajaw@example.com	f	t	2013-12-12 15:38:54.378663+01
10	pbkdf2_sha256$12000$NQLSoUmujOKm$/ZHXVWvCRWyW8vX9rXc5Z77L6ioLAAQGPs+iATUmUjo=	2013-12-12 15:39:35.486319+01	f	bechmie	Benedykta	Chmielewska	bechmie@example.com	f	t	2013-12-12 15:39:35.486456+01
11	pbkdf2_sha256$12000$cN4bWArz63tn$gqcgtpYgjyqYBsTRgGT6vaIBHE1YN1hcC8RtZgGd7tE=	2013-12-12 15:40:01.45618+01	f	juwis	Julianna	Wiśniewska	juwis@example.com	f	t	2013-12-12 15:40:01.456227+01
12	pbkdf2_sha256$12000$WfbLEtsxIzLH$ETnc+dirzj0vQkajw0LstvNpUb8I/JSJTDyXX8CiQJ4=	2013-12-12 15:40:28.697005+01	f	wazaj	Wawrzyniec	Zając	wazaj@example.com	f	t	2013-12-12 15:40:28.697084+01
13	pbkdf2_sha256$12000$fWPApTBr6IQh$JsNdBLPP2CNuFtCcglUWiGKnvWSg1eu8OQU5zk79JNM=	2013-12-12 15:40:56.795192+01	f	krywoj	Krystiana	Wojciechowska	krywoj@example.com	f	t	2013-12-12 15:40:56.79524+01
14	pbkdf2_sha256$12000$vEZxgDzFnS8u$YnGJOpJltqSF5tYSrdSYmiInmE+mO2H4X+6ECtM3pS8=	2013-12-12 15:41:30.092584+01	f	anwie	Anastazja	Wieczorek	anwie@example.com	f	t	2013-12-12 15:41:30.092688+01
15	pbkdf2_sha256$12000$RQLxEjKNa3Wr$UhES1h30HweKmRjhAB20xS0BiXV6p6B0G7ZA9nW7iWg=	2013-12-12 15:41:57.767019+01	f	bakow	Basia	Kowalska	bakow@example.com	f	t	2013-12-12 15:41:57.767163+01
16	pbkdf2_sha256$12000$4XrsYFqcchCT$bFb9C9hIGMVpzfRZ7k3X2yevLRNGIUZwd4bO/VwVOaA=	2013-12-12 15:42:27.248468+01	f	ksaza	Ksawery	Zawadzki	ksaza@example.com	f	t	2013-12-12 15:42:27.248557+01
17	pbkdf2_sha256$12000$SZTgJnlV25c5$jL+w0vd6kHbpSG5k3xXexwmiuwAYqSqL8MPGxMFQ3Ww=	2013-12-12 15:42:55.199918+01	f	bosok	Bożena	Sokołowska	bosok@example.com	f	t	2013-12-12 15:42:55.200064+01
18	pbkdf2_sha256$12000$WvEhTWwtAzYF$3Tt/KabD5zh09KLMlTwLwMb6zm6FWUFpjzIfxARLYy0=	2013-12-12 15:43:26.304234+01	f	gapaw	Gabryś	Pawlak	gapaw@example.com	f	t	2013-12-12 15:43:26.304378+01
19	pbkdf2_sha256$12000$shbELTK90TkA$6FkSNxFW3WlYZd++7nN38yx2mJM64ay6Jyr1pK4yxy0=	2013-12-12 15:43:49.674044+01	f	jakuch	Janusz	Kucharski	jakuch@example.com	f	t	2013-12-12 15:43:49.674091+01
20	pbkdf2_sha256$12000$d3cBF1AFYczN$YBW2Tl2x42Xlkt4meuKc+JnkybUXrmACOJ5Np2P7i1M=	2013-12-12 15:44:14.901986+01	f	kakow	Kajetan	Kowalczyk	kakow@example.com	f	t	2013-12-12 15:44:14.902069+01
21	pbkdf2_sha256$12000$Id4TRMC2XgHt$GB6dELdF6MRQJFWBG9UoKy1f/ueSsim7W7c1D+J2yQw=	2013-12-12 15:44:43.427588+01	f	juwie	Justyna	Wieczorek	juwie@example.com	f	t	2013-12-12 15:44:43.427637+01
22	pbkdf2_sha256$12000$vOO2NTYJKCgK$OTP2vqp8FpjYOGGu2VRA3GltV+X8Wo87bKsok8+PkKM=	2013-12-12 15:45:18.728084+01	f	pajas	Paweł	Jasiński	pajas@example.com	f	t	2013-12-12 15:45:18.728224+01
23	pbkdf2_sha256$12000$Ke3uCri2NtUS$9Z4vBeQb4hdfejmpb1uJ8KuPoJa9LC02ZBh958yBQOk=	2013-12-12 15:45:46.351944+01	f	romaj	Róża	Majewska	romaj@example.com	f	t	2013-12-12 15:45:46.35201+01
24	pbkdf2_sha256$12000$fs7ehZPnzhZu$EGvT9dKegPpKv4OFJNgI9v/Cl2uV1vU4ErqNauw0fsw=	2013-12-12 15:46:11.637415+01	f	klesa	Klementyna	Sawicka	klesa@example.com	f	t	2013-12-12 15:46:11.637533+01
25	pbkdf2_sha256$12000$bH44H35qbONZ$NV9tbkY+DdGZkIMeE9G9ThbWRoPKNySNOMDi4ywwctU=	2013-12-12 15:46:37.289041+01	f	lukow	Ludwika	Kowalczyk	lukow@example.com	f	t	2013-12-12 15:46:37.28915+01
26	pbkdf2_sha256$12000$336UQWjgAlEk$DoePtiDwZVrZSfSsHc0B1PHqbcCau6rN9Y03JUMc87k=	2013-12-12 15:47:28.256448+01	f	jacza	Jarosław	Czarnecki	jacza@example.com	f	t	2013-12-12 15:47:28.256652+01
27	pbkdf2_sha256$12000$N7H0jXRyKPiP$BilHl6CGGaUWD0jeLFcKeoDCIzS6fqqtLWUyQuLRpyk=	2013-12-12 15:48:04.369515+01	f	klami	Klaudiusz	Michalski	klami@example.com	f	t	2013-12-12 15:48:04.369655+01
28	pbkdf2_sha256$12000$SH6090fyPSQH$FmC9M4YGRYzIuayCfsIMEMI3Y6spIl/eS4Jg2g2yIWg=	2013-12-12 15:48:28.807778+01	f	izgor	Izabela	Gorska	izgor@example.com	f	t	2013-12-12 15:48:28.807856+01
29	pbkdf2_sha256$12000$t2tDo5VmDncC$WphgTsPNeGtHbZsRoKEMI0w/0tpdNzIuVAvWFLxBegA=	2013-12-12 15:49:00.952753+01	f	jumic	Judyta	Michalska	jumic@example.com	f	t	2013-12-12 15:49:00.952829+01
30	pbkdf2_sha256$12000$9gOc91ZsbVHD$FqpOJhMem+YbPeJxPKBqts/sfJ67IogJarf6xBU9knQ=	2013-12-12 15:49:29.537726+01	f	wadud	Wacława	Dudek	wadud@example.com	f	t	2013-12-12 15:49:29.537776+01
31	pbkdf2_sha256$12000$YqMX6CMgoXM9$YK0VgZlcIsufEMTFK9QIwW8hEtTEyRbsxisudBOaK4I=	2013-12-12 15:49:57.924709+01	f	ansob	Anastazy	Sobczak	ansob@example.com	f	t	2013-12-12 15:49:57.924877+01
32	pbkdf2_sha256$12000$jOIEGE65vTUq$7vM4TTmbd2TLDUvwrNtL/gU73tvANboRBo9euuOZ7yM=	2013-12-12 15:54:03.183224+01	f	olpaw	Oliwia	Pawłowska	olpaw@example.com	f	t	2013-12-12 15:54:03.183284+01
33	pbkdf2_sha256$12000$lFdkp8giPZGN$mkj6Kh5R2dB09bmwx79k2FWX2MXpcSdf0ktiCKAgXgY=	2013-12-12 15:54:40.909459+01	f	mamaj	Martyna	Majewska	mamaj@example.com	f	t	2013-12-12 15:54:40.909608+01
34	pbkdf2_sha256$12000$uO6leu2gEOsA$oqsK1i5tQvTvg2tk9iVTrhj4fIt63kpEUshjM7I71ak=	2013-12-12 15:55:09.274861+01	f	japaw	Janek	Pawlak	japaw@example.com	f	t	2013-12-12 15:55:09.275082+01
35	pbkdf2_sha256$12000$forUoOtFutHz$KCeSBL89wBBke86tn88NttRqLUm6Y+6TRlpTA4xOahQ=	2013-12-12 15:57:21.587111+01	f	zotom	Zofia	Tomaszewska	zotom@example.com	f	t	2013-12-12 15:57:21.587395+01
36	pbkdf2_sha256$12000$NKDMjv4smjCN$BQ+x0lWtKPHdkP+cGFWr0qGczF1m090useD4FP9f6t4=	2013-12-12 15:57:44.985345+01	f	zupio	Zuzanna	Piotrowska	zupio@example.com	f	t	2013-12-12 15:57:44.985397+01
37	pbkdf2_sha256$12000$6B0th67rDw9q$mx5+9gY2AA+BeMdHGgiXe9elM6VXqJR2dEZUwxDmPps=	2013-12-12 15:58:14.740268+01	f	wijar	Wiktoria	Jaworska	wijar@example.com	f	t	2013-12-12 15:58:14.740344+01
38	pbkdf2_sha256$12000$9xCkZVQpEOyL$o0ORU42pvqG72xdVAGw54plCeaYa/sCH4dYBEmTvDrU=	2013-12-12 15:58:41.322122+01	f	tyjaw	Tymoteusz	Jaworski	tyjaw@example.com	f	t	2013-12-12 15:58:41.322207+01
39	pbkdf2_sha256$12000$WP7lCe5P0fm0$CRDCpknH14xpUGuL3mV0kwVXXL02OCsknZ28smikiPA=	2013-12-12 15:59:13.124364+01	f	boada	Bożena	Adamska	boada@example.com	f	t	2013-12-12 15:59:13.124518+01
40	pbkdf2_sha256$12000$C7ROTeOEBdHR$QXdGw4HttEralfpKdZEZAf5GZLp56Qk7e071tuW2WCk=	2013-12-12 15:59:39.499617+01	f	dowys	Donat	Wysocki	dowys@example.com	f	t	2013-12-12 15:59:39.499694+01
41	pbkdf2_sha256$12000$UvYmmStAPVyO$HrU7Igw6N5g59H6InKZoKtE4PbeP78ck0mxzu4QcK+M=	2013-12-12 16:00:07.646514+01	f	frago	Franciszka	Gorska	frago@example.com	f	t	2013-12-12 16:00:07.646759+01
42	pbkdf2_sha256$12000$ttzGomVmUYUW$6ZNn1vpwRC7QjLvOfOR/Nlsm63wO0KmjkSEDykKvhos=	2013-12-12 16:01:07.981501+01	f	stawy	Stanisław	Wysocki	stawy@example.com	f	t	2013-12-12 16:01:07.981644+01
43	pbkdf2_sha256$12000$Y6SbPPtVHHwG$U3BryYT+d2a71mPgTkfjpUTOMmKWeZ2wpImycUr4fco=	2013-12-12 16:01:30.469298+01	f	anaza	Anastazja	Zając	anaza@example.com	f	t	2013-12-12 16:01:30.469441+01
44	pbkdf2_sha256$12000$SY0XdEF2cNmR$LI4jAYGu0/SgJyzoppPoOspvGLy2kstuFSG1m1Lsuqk=	2013-12-12 16:01:56.510358+01	f	anzaw	Anastazy	Zawadzki	anzaw@example.com	f	t	2013-12-12 16:01:56.510408+01
45	pbkdf2_sha256$12000$PugPtlwwOMlE$bHXSZD8fBLH+pb1IXLpE0be9u2AneMbp/FloL9cnAqw=	2013-12-12 16:02:15.426613+01	f	anzie	Anna	Zieleniecka	anzie@example.com	f	t	2013-12-12 16:02:15.426663+01
46	pbkdf2_sha256$12000$4yRhSm2zkHiv$4/7vRog0MMvSMoIGpq6VscIIMY6U/yDc7qJVKIfuvNU=	2013-12-12 16:02:31.723502+01	f	bozaj	Bożena	Zając	bozaj@example.com	f	t	2013-12-12 16:02:31.72356+01
47	pbkdf2_sha256$12000$pO6FIlvTWg1Z$2tsD1ni9XfGE8oEJhfG/J05wW7ZURH+k+s8wBiUmBYE=	2013-12-12 16:02:56.222371+01	f	bozaw	Bożena	Zawadzka	bozaw@example.com	f	t	2013-12-12 16:02:56.222519+01
48	pbkdf2_sha256$12000$iOSVjmFiW8aP$AlBlCAq9humsZIVCPXt+t6Da/h6PGKmIlxmEoI9+KkI=	2013-12-12 16:03:23.527511+01	f	bazaj	Basia	Zając	nazaj@example.com	f	t	2013-12-12 16:03:23.527566+01
49	pbkdf2_sha256$12000$bDAIW3x01W4e$nRqy2pNECWSsjXfu75FL8xYDD4aWnyRPc8G4HyErbdQ=	2013-12-12 16:03:42.485463+01	f	bezie	Benedykta	Zieleniecka	bezie@example.com	f	t	2013-12-12 16:03:42.485513+01
50	pbkdf2_sha256$12000$JvgU1aSxEQdf$hVjGYsxdhhcNZfhF7DPRNhI+xCKQ7Dfz6z8CjirV6xg=	2013-12-12 16:03:59.568016+01	f	bokol	Bożena	Kowalczyk	bokol@example.com	f	t	2013-12-12 16:03:59.568086+01
51	pbkdf2_sha256$12000$gMfP0nj4jCAd$gz6Qujxu1HkLkIwCy9ajp/VGbUgqO4EGA7xScdK8Hn4=	2013-12-12 16:04:19.090014+01	f	bozos	Bożena	Ostrowska	bozos@example.com	f	t	2013-12-12 16:04:19.090092+01
52	pbkdf2_sha256$12000$iYH7sPAIjYID$nNEHzYbs4ZasSOlF4chADtzqw+fyoGKjc5rQLclSiuc=	2013-12-12 16:04:39.967819+01	f	anost	Anna	Ostrowska	anost@example.com	f	t	2013-12-12 16:04:39.967899+01
53	pbkdf2_sha256$12000$6G7QeKiMQMgi$jPMEqC5yV222B7l8/0IcyLAPwLzCiW35+hRiVLY2fL4=	2013-12-12 16:04:58.528642+01	f	watom	Wacława	Tomaszewska	watom@example.com	f	t	2013-12-12 16:04:58.528691+01
54	pbkdf2_sha256$12000$wo7ixaC8yJeh$depkfybCz06F8TNc3LFTizhH+EjfP+tpQaIZSxIcRjQ=	2013-12-12 16:05:19.985342+01	f	dosob	Donat	Sobczak	dosob@example.com	f	t	2013-12-12 16:05:19.985484+01
55	pbkdf2_sha256$12000$GvrbrQ3R25LO$d5HW2wGnnmsUvRnO/cyx/siRbWdwCMdkuct2e126nSw=	2013-12-12 16:05:41.442747+01	f	dojaw	Dorota	Jaworska	dojaw@example.com	f	t	2013-12-12 16:05:41.442962+01
56	pbkdf2_sha256$12000$JAYq0nUgqCbe$sPdXsq+4x41dPGUrdkfnBgwfFneTQ44VsEEFeaU+IXU=	2013-12-12 16:06:02.021811+01	f	hatom	Hanna	Tomaszewska	hatom@example.com	f	t	2013-12-12 16:06:02.0219+01
57	pbkdf2_sha256$12000$LFCHBXvl2AcO$WpraYwiY4GRBHwFJ84H5ushvZjU1ze5QsMI6uPt9zxc=	2013-12-12 16:06:20.672317+01	f	judud	Judyta	Dudek	judud@example.com	f	t	2013-12-12 16:06:20.672422+01
58	pbkdf2_sha256$12000$TMOqvdfkYuhG$8k8L8PEM7Kinjxml//2uBS3ZoUoZ9vK5+pSKo2scBcY=	2013-12-12 16:06:39.518503+01	f	jakow	Janek	Kowalczyk	jakow@example.com	f	t	2013-12-12 16:06:39.518666+01
59	pbkdf2_sha256$12000$5deJE0yPQhFs$Zk7/nP0hco+RSpizCI7xuiB2YoAlipyl0offl2HU8dY=	2013-12-12 16:07:53.389371+01	f	jakuc	Janusz	Kucharski	jakuc@example.com	f	t	2013-12-12 16:07:53.389427+01
60	pbkdf2_sha256$12000$DunAZy0wpGhg$dyfP6iRhmK3bIP2KnBpl4gksmw1FZEMGr7PqGOJAZqM=	2013-12-12 16:08:11.645059+01	f	jagor	Jarosław	Gorski	jagor@example.com	f	t	2013-12-12 16:08:11.645201+01
61	pbkdf2_sha256$12000$8vIk0LD0KTnw$LGNmDBCknydUDOW6Ly+flVx7cwPkfy5CSeOH2qSfKlE=	2013-12-12 16:08:28.804704+01	f	jugor	Judyta	Gorska	jugor@example.com	f	t	2013-12-12 16:08:28.804755+01
62	pbkdf2_sha256$12000$buH5TCfhMGUO$p3XQ67f0/WcotQ1ffKw8nQbCGU9xpLISibm1PzOs6JM=	2013-12-12 16:09:37.598629+01	f	tyjas	Tymoteusz	Jaski	tyjas@example.com	f	t	2013-12-12 16:09:37.598774+01
63	pbkdf2_sha256$12000$8r5chZ1IMFGO$m7lWDZnzmrFJMdEUfoaSAwgLycyw7YkHkQE/ERkLtpc=	2013-12-12 16:10:05.708656+01	f	mazaw	Marcin	Zawadzki	mazaw@example.com	f	t	2013-12-12 16:10:05.708732+01
64	pbkdf2_sha256$12000$3IFUhAdwjsSm$qMw4qh04TevJYaj5uzDDmo+sP1N3xbN1VhXEB2eF1vQ=	2013-12-12 16:10:30.727672+01	f	kryko	Krystyna	Kowalczyk	kryko@example.com	f	t	2013-12-12 16:10:30.727888+01
65	pbkdf2_sha256$12000$KTTJsPzypbed$Rr3+9Irxp7fVSe/D8PXG1e9gyViBSUkUFWuVtiZz4qI=	2013-12-12 16:11:01.885289+01	f	arjab	Aron	Jabłoński	arjab@example.com	f	t	2013-12-12 16:11:01.885417+01
66	pbkdf2_sha256$12000$rQ9YVWGM6jsB$IxUFh5lq9X3nyaJqSOdYNqY1FsK90QiFQpo1nulEgb4=	2013-12-12 16:11:31.501097+01	f	zosok	Zoja	Sokołowska	zosok@example.com	f	t	2013-12-12 16:11:31.501146+01
67	pbkdf2_sha256$12000$9ukm859bRJaN$Xx5cW43bH8J2NAJNk8pOgskgAQL5Qn8nlS45VdFs9G4=	2013-12-12 16:12:13.59819+01	f	gakec	Genowefa	Kaczmarek	gekac@example.com	f	t	2013-12-12 16:12:13.598329+01
68	pbkdf2_sha256$12000$kj0ARmnDasgK$XBjFjGnsEZUJChKrHLu/KjUSx+ZVi6rSoRwEXlb8NN0=	2013-12-12 16:12:34.432949+01	f	pizaj	Piotr	Zając	pizaj@example.com	f	t	2013-12-12 16:12:34.432997+01
69	pbkdf2_sha256$12000$4C76pjT5gbd6$RUH5jiSy+gT4McKACm0M1xtLY0Jh1F967tQhT3S0hDA=	2013-12-12 16:12:54.515101+01	f	pawos	Paweł	Ostrowski	pawos@example.com	f	t	2013-12-12 16:12:54.515307+01
70	pbkdf2_sha256$12000$AC6tYVXS4dtz$wbTLIzwJugjV/eSmuLoFRPI+1xQu9VbAvBeZ7A3YxDM=	2013-12-12 16:13:29.090226+01	f	pajawo	Paweł	Jaworski	pajawo@example.com	f	t	2013-12-12 16:13:29.090275+01
71	pbkdf2_sha256$12000$KFkwARWjfQHK$76lF6Up8BXz4Tiy6yF0cpqRELqs9q/283w9gdeXoJz4=	2013-12-12 16:13:47.848962+01	f	pitom	Piotr	Tomaszewski	pitom@example.com	f	t	2013-12-12 16:13:47.849084+01
72	pbkdf2_sha256$12000$BGsRgSQg9u6I$AJJ1ldkDNIyMPCjXbtt/+FTHiQWnggsKQPbQIJeFVpk=	2013-12-12 16:14:10.299494+01	f	piwie	Piotr	Wieczorek	piwie@example.com	f	t	2013-12-12 16:14:10.299649+01
73	pbkdf2_sha256$12000$TCRI9jARRdbN$W9/MERtf8CzLF10NT896VWQskrUa9UzGLCboPptTlWQ=	2013-12-12 16:14:26.897416+01	f	rydud	Ryszard	Dudek	rydud@example.com	f	t	2013-12-12 16:14:26.897552+01
74	pbkdf2_sha256$12000$dN65ngSxxLbF$UOmxmlG2X90LPzDFtKY97+t9JTgVi+SCjDdzOpbsC94=	2013-12-12 16:14:45.179264+01	f	hagor	Hanna	Gorska	hagor@example.com	f	t	2013-12-12 16:14:45.179477+01
75	pbkdf2_sha256$12000$hknVViRubeLZ$F5+vzDjmiCp9tO5Ps88hE/aE0PyqWbGqEWvc3uIe0gQ=	2013-12-12 16:15:09.053432+01	f	krydud	Krystiana	Dudek	krydud@example.com	f	t	2013-12-12 16:15:09.053534+01
76	pbkdf2_sha256$12000$5WpfFHTFr2PA$h+pq+I4Q9SSDd9x+MLdWYuPpda08K19rNpOqTqyPqxE=	2013-12-12 16:15:25.435509+01	f	jansa	Janek	Sawicki	jansa@example.com	f	t	2013-12-12 16:15:25.435582+01
77	pbkdf2_sha256$12000$lMcC2NxSdpF6$xQETdnflut8pF5oU+EFuH4kmJGVFEPvIBZ6iBsF1weY=	2013-12-12 16:15:57.627322+01	f	dojawo	Dorota	Jaworska	dojawo@example.com	f	t	2013-12-12 16:15:57.627372+01
78	pbkdf2_sha256$12000$NITuZBpVfa4G$8S6nKkt6DevaV/n8g3IuzCVVfR2MBgCv6sogkYUgSmM=	2013-12-12 16:16:15.803633+01	f	dokuc	Dorota	Kaczmarek	dokuc@example.com	f	t	2013-12-12 16:16:15.803773+01
79	pbkdf2_sha256$12000$AvhGobr4ItKg$0o44U41PE7xJ6YP69w+/dICDWR5McMhSawQnjM9jDco=	2013-12-12 16:16:37.271091+01	f	gasaw	Gabryś	Sawicki	gasaw@example.com	f	t	2013-12-12 16:16:37.271142+01
80	pbkdf2_sha256$12000$yVFDyLWxYszW$vbf5Q7JA/RS8Hs30Vf+vI+sBGfInksK71TJnQSOU0E8=	2013-12-12 16:16:54.281859+01	f	krywi	Krystiana	Wieczorek	krywi@example.com	f	t	2013-12-12 16:16:54.281934+01
81	pbkdf2_sha256$12000$CjwimUMLiIQk$FZlGpW/5C9SC3b4uMbmYn8eaUbIUk9QIqv+mDk87ze4=	2013-12-12 16:17:12.332741+01	f	fraka	Franciszka	Kaczmarek	fraka@example.com	f	t	2013-12-12 16:17:12.332792+01
82	pbkdf2_sha256$12000$agNja6h8eJCR$G0Mfei8ijuU+COPSm8FOogAIgdyWUeg9rl6Ql/jfi8g=	2013-12-12 16:17:34.132725+01	f	luwys	Ludwika	Wysocka	luwys@example.com	f	t	2013-12-12 16:17:34.132871+01
83	pbkdf2_sha256$12000$UwtzBqkC6sFX$sIZ4lYz0rde8R/M9xDOiSuK97AimIzYuPC12wtjlfyA=	2013-12-12 16:17:51.807626+01	f	dojab	Dorota	Jabłońska	dojab@example.com	f	t	2013-12-12 16:17:51.80773+01
84	pbkdf2_sha256$12000$NVFKDCtHzP6b$YBuIq5jzcpYK9wbq/uZsCKm4XFYyw1KqQqSla/PYhlU=	2013-12-12 16:18:11.789082+01	f	wada	Wacława	Adamska	wada@example.com	f	t	2013-12-12 16:18:11.789162+01
85	pbkdf2_sha256$12000$baojqWP3liwS$R9G7RyHSzLjMmbXU6LTzAaiFJBw/V6ugWRNJ666+BVY=	2013-12-12 16:18:38.354127+01	f	wichm	Wiktoria	Chmielewska	wichm@example.com	f	t	2013-12-12 16:18:38.354383+01
86	pbkdf2_sha256$12000$uCtjAgFdQfJr$eDPcTcRQgLwiQDzsTwpzpqjPVdv71Hu8HBuSAIduQ7Y=	2013-12-12 16:18:54.936798+01	f	wikac	Wiktoria	Kaczmarek	wikac@example.com	f	t	2013-12-12 16:18:54.936845+01
87	pbkdf2_sha256$12000$ukJPs94NDnNM$NESvoX+pnyn2HPAEsiGiXyY6YFw237rok5trM1hbPHY=	2013-12-12 16:19:41.931613+01	f	ludud	Ludwika	Dudek	ludud@example.com	f	t	2013-12-12 16:19:41.931699+01
88	pbkdf2_sha256$12000$CYv10nnuat82$WJJ4xQoRySg0WAl4e3JOuwWGDLtQ9+mgpwaPyj+FlGQ=	2013-12-12 16:19:57.640647+01	f	stada	Stanisław	Adamski	stada@example.com	f	t	2013-12-12 16:19:57.640696+01
89	pbkdf2_sha256$12000$4tndG6aHKbRH$S2p9sNEO2+i8xEbAuNWMrDLaRFr7qJEhyWvwSHckTLI=	2013-12-12 16:20:16.302014+01	f	stago	Stanisław	Gorski	stago@example.com	f	t	2013-12-12 16:20:16.30212+01
90	pbkdf2_sha256$12000$9GjBqp3fn4pg$zKzkl/V40SK062qhMtsGOpJjRQh5CNN9Djgd3jXAcEg=	2013-12-12 16:20:40.050344+01	f	kawis	Kasia	Wiśniewska	kawis@example.com	f	t	2013-12-12 16:20:40.050452+01
91	pbkdf2_sha256$12000$efDu3t5n6pfr$sjHE9j0GZ7y/QvxQ2k1suKRcc1+1MzqnGudRi2hVKxw=	2013-12-12 16:21:02.200686+01	f	kanow	Kasia	Nowicka	kanow@example.com	f	t	2013-12-12 16:21:02.200737+01
92	pbkdf2_sha256$12000$xf2qv6Xt6kc6$IRpQg10dVSiOAsDw3154MkuC/uGGn9zToBcVmRNHK7A=	2013-12-12 16:21:18.934241+01	f	panow	Paweł	Nowicki	panow@example.com	f	t	2013-12-12 16:21:18.934318+01
93	pbkdf2_sha256$12000$eUjawdU7j9PL$nsP/Fw96z9WQhNeB2uK7jW6NTB6HG35mhjEi2HQodTo=	2013-12-12 16:21:36.062843+01	f	tywys	Tytus	Wysocki	tywys@example.com	f	t	2013-12-12 16:21:36.063116+01
94	pbkdf2_sha256$12000$Vl9IE8xdUUfb$+VSLsJDmgfhPeuEOt9+Ip/Nipcipf+3Ma9CIrjQkAJU=	2013-12-12 16:21:53.939354+01	f	oltom	Oliwia	Tomaszewska	oltom@example.com	f	t	2013-12-12 16:21:53.939403+01
95	pbkdf2_sha256$12000$AzrWOPTbPe1x$515Hjvfokp2pvxKYA93x2a7R8Nf9XxYLMkEfcdLZGX0=	2013-12-12 16:22:16.889297+01	f	lutom	Ludwika	Tomaszewska	lutom@example.com	f	t	2013-12-12 16:22:16.889384+01
96	pbkdf2_sha256$12000$SOpqLE432Ol6$pwMYOLJNvLBIHptupnizGfKrAhMO1OLT02Obyg88Ezc=	2013-12-12 16:22:36.378443+01	f	ryjaw	Ryszard	Jaworski	ryjaw@example.com	f	t	2013-12-12 16:22:36.37865+01
97	pbkdf2_sha256$12000$qkVDgUb19nSS$aXiM0dQe+bzXhUsFbsG9Y+DnHbraqAvkAB5nN51qJpg=	2013-12-12 16:22:54.847503+01	f	rokuc	Róża	Kucharska	rokuc@example.com	f	t	2013-12-12 16:22:54.847726+01
98	pbkdf2_sha256$12000$FFGTanVdfr2W$rY+fvrF9vZQlbeRXtGP3/D/4EmYqW9+GWtSXRgvWYUE=	2013-12-12 16:23:53.235289+01	f	kleno	Klementyna	Nowicka	kleno@example.com	f	t	2013-12-12 16:23:53.235433+01
99	pbkdf2_sha256$12000$XyvNwCUVSZhM$DQ9r471IodqYqv9Wyg6v94BFLI9rGduI1QLnvtkMsaA=	2013-12-12 16:24:12.614922+01	f	jawys	Janek	Wysocki	jawys@example.com	f	t	2013-12-12 16:24:12.61503+01
100	pbkdf2_sha256$12000$EKVGpNPpK13h$MuG30NalKEi6xQYmW380zcxkIc8Ujzp1jbD463nv4mg=	2013-12-12 16:24:30.664987+01	f	jasob	Janusz	Sobczak	jasob@example.com	f	t	2013-12-12 16:24:30.66506+01
101	pbkdf2_sha256$12000$WkZeqOzQuXmv$+hBkJ5D5lGNF3j5AKVoQ5v9GtB/ThVPQxjgaVExvmnQ=	2013-12-12 16:24:53.458055+01	f	tysok	Tytus	Sokołowski	tysok@example.com	f	t	2013-12-12 16:24:53.458104+01
\.


--
-- Data for Name: auth_user_groups; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY auth_user_groups (id, user_id, group_id) FROM stdin;
\.


--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('auth_user_groups_id_seq', 1, false);


--
-- Name: auth_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('auth_user_id_seq', 101, true);


--
-- Data for Name: auth_user_user_permissions; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY auth_user_user_permissions (id, user_id, permission_id) FROM stdin;
\.


--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('auth_user_user_permissions_id_seq', 1, false);


--
-- Data for Name: dbarray_chars; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY dbarray_chars (id, arr) FROM stdin;
\.


--
-- Name: dbarray_chars_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('dbarray_chars_id_seq', 1, false);


--
-- Data for Name: dbarray_dates; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY dbarray_dates (id, arr) FROM stdin;
\.


--
-- Name: dbarray_dates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('dbarray_dates_id_seq', 1, false);


--
-- Data for Name: dbarray_floats; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY dbarray_floats (id, arr) FROM stdin;
\.


--
-- Name: dbarray_floats_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('dbarray_floats_id_seq', 1, false);


--
-- Data for Name: dbarray_integers; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY dbarray_integers (id, arr) FROM stdin;
\.


--
-- Name: dbarray_integers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('dbarray_integers_id_seq', 1, false);


--
-- Data for Name: dbarray_texts; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY dbarray_texts (id, arr) FROM stdin;
\.


--
-- Name: dbarray_texts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('dbarray_texts_id_seq', 1, false);


--
-- Data for Name: django_admin_log; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY django_admin_log (id, action_time, user_id, content_type_id, object_id, object_repr, action_flag, change_message) FROM stdin;
\.


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('django_admin_log_id_seq', 1, false);


--
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY django_content_type (id, name, app_label, model) FROM stdin;
1	permission	auth	permission
2	group	auth	group
3	user	auth	user
\.


--
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('django_content_type_id_seq', 3, true);


--
-- Data for Name: django_session; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY django_session (session_key, session_data, expire_date) FROM stdin;
6ksp47vnch8prgrcqyhnruv5mi1iw2ku	MGM0ZmMwYTY4ZWJkMjEzMDlkNzQxMmYzNzE4Yzg3NzU2NzM0MDYyZjp7Il9hdXRoX3VzZXJfYmFja2VuZCI6ImRqYW5nby5jb250cmliLmF1dGguYmFja2VuZHMuTW9kZWxCYWNrZW5kIiwiX2F1dGhfdXNlcl9pZCI6MX0=	2013-12-18 23:04:45.603486+01
uo63vcwpydttj7dl6pfppzs2yaxhe817	MGM0ZmMwYTY4ZWJkMjEzMDlkNzQxMmYzNzE4Yzg3NzU2NzM0MDYyZjp7Il9hdXRoX3VzZXJfYmFja2VuZCI6ImRqYW5nby5jb250cmliLmF1dGguYmFja2VuZHMuTW9kZWxCYWNrZW5kIiwiX2F1dGhfdXNlcl9pZCI6MX0=	2013-12-19 01:34:33.325427+01
ljfq8q326rpxhs6rhprlbwsxp5yuw1qz	MGM0ZmMwYTY4ZWJkMjEzMDlkNzQxMmYzNzE4Yzg3NzU2NzM0MDYyZjp7Il9hdXRoX3VzZXJfYmFja2VuZCI6ImRqYW5nby5jb250cmliLmF1dGguYmFja2VuZHMuTW9kZWxCYWNrZW5kIiwiX2F1dGhfdXNlcl9pZCI6MX0=	2013-12-27 01:10:54.212932+01
\.


--
-- Data for Name: django_site; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY django_site (id, domain, name) FROM stdin;
\.


--
-- Name: django_site_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('django_site_id_seq', 1, false);


--
-- Data for Name: items_item; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY items_item (id, name, model, period, penalty, availability) FROM stdin;
6	Asus	X24235SF	2	0.00	t
7	Samsung	X300	2	0.00	t
8	Samsung	X300i	2	0.00	t
9	Samsung	ghx	2	0.00	t
10	Samsung	400s	2	0.00	t
11	Samsung	234sdx	2	0.00	t
12	Samsung	500i7	2	0.00	t
13	Samsung	500i7a	2	0.00	t
14	Samsung	500i7b	2	0.00	t
15	Samsung	9xx02	2	0.00	t
16	Asus	x500	2	0.00	t
17	Asus	400z	2	0.00	t
19	Asus	200dx	2	0.00	t
20	Asus	ultimate pro	2	0.00	t
21	Asus	ipad 700	2	0.00	t
22	Toshiba	200x	2	0.00	t
23	Toshiba	200dx	2	0.00	t
24	Toshiba	dx500	2	0.00	t
25	Toshiba	603	2	0.00	t
26	Toshiba	xs20	2	0.00	t
27	Toshiba	500i7a	2	0.00	t
28	Toshiba	500i7	2	0.00	t
29	Toshiba	300i	2	0.00	t
30	Toshiba	X300	2	0.00	t
31	Toshiba	x500	2	0.00	t
32	Toshiba	X24235SFxs	2	0.00	t
33	Toshiba	T200	2	0.00	t
34	Toshiba	fix smart	2	0.00	t
35	Toshiba	pocket	2	0.00	t
36	Sony	206	2	0.00	t
37	Sony	206x	2	0.00	t
38	Sony	354xs	2	0.00	t
39	Sony	T200	2	0.00	t
40	Sony	500i7	2	0.00	t
41	Sony	z400	2	0.00	t
42	Sony	web smart	2	0.00	t
43	Sony	300i	2	0.00	t
44	Sony	8oo4	2	0.00	t
45	Sony	87cv	2	0.00	t
46	Sony	67cvx	2	0.00	t
47	Sony	67cva	2	0.00	t
48	Sony	300i yellow	2	0.00	t
49	Sony	300i black	2	0.00	t
50	Sony	300i red	2	0.00	t
51	Sony	67cv700	2	0.00	t
52	Lexmark	X4950i	2	0.00	t
53	Lexmark	X4950	2	0.00	t
54	Lexmark	X4952	2	0.00	t
55	Lexmark	X4954	2	0.00	t
56	Lexmark	X4948	2	0.00	t
57	Lexmark	X4948i	2	0.00	t
58	Lexmark	X300	2	0.00	t
59	Lexmark	X500	2	0.00	t
60	Lexmark	500s	2	0.00	t
61	HP	300i	2	0.00	t
62	HP	300	2	0.00	t
63	HP	300i black	2	0.00	t
64	HP	400s	2	0.00	t
65	HP	603	2	0.00	t
66	Chevrolet	c200	2	0.00	t
67	Chevrolet	1	2	0.00	t
68	Chevrolet	2	2	0.00	t
69	Chevrolet	3x	2	0.00	t
70	Audi	300	2	0.00	t
71	Audi	4x	2	0.00	t
72	Audi	pro	2	0.00	t
73	BMW	new 2013 x	2	0.00	t
74	Nissan	sunny 1	2	0.00	t
75	Nissan	sunny 2	2	0.00	t
76	Nissan	sunny 3	2	0.00	t
77	Nissan	sunny 4	2	0.00	t
78	Skoda	Fabia 500	2	0.00	t
79	Skoda	Octavia 	2	0.00	t
80	Skoda	Octavia 588	2	0.00	t
81	Toyota	400s	2	0.00	t
82	Toyota	4x	2	0.00	t
83	Toyota	8oo4	2	0.00	t
84	Toyota	766o	2	0.00	t
85	Mercedes-Benz	x	2	0.00	t
86	Mercedes-Benz	x600	2	0.00	t
87	Mercedes-Benz	a	2	0.00	t
88	Mercedes-Benz	w300	2	0.00	t
89	Mercedes-Benz	dx500	2	0.00	t
90	Mercedes-Benz	i700	2	0.00	t
91	Peugeot	x200	2	0.00	t
92	Peugeot	57a	2	0.00	t
93	Peugeot	ghx3	2	0.00	t
94	Peugeot	j700	2	0.00	t
95	Peugeot	9xx02	2	0.00	t
96	Peugeot	766oX	2	0.00	t
97	Peugeot	dx500	2	0.00	t
98	Peugeot	l500s	2	0.00	t
99	Peugeot	300i yellow	2	0.00	t
100	Peugeot	c200	2	0.00	t
1	Skoda Fabia	Kombi	2	0.00	f
2	MacBook Air	0.1	2	10.00	t
3	Skoda Octavia	Kombi	2	20.00	t
4	Skoda Fabia	Sedan	2	1.00	t
5	MacBook Pro	0.1	2	7.00	t
18	Asus	123sx	2	0.00	f
\.


--
-- Name: items_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('items_item_id_seq', 100, true);


--
-- Data for Name: occupations_occupation; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY occupations_occupation (id, user_id, position_id, vs, ve) FROM stdin;
61	44	7	2003-01-21	2005-12-21
65	45	7	2006-01-01	2006-12-31
66	46	7	2007-01-01	2007-12-31
67	47	7	2008-01-01	2008-12-31
68	48	7	2009-01-01	2009-12-31
69	49	7	2010-01-01	2010-12-31
70	50	7	2011-01-01	2012-12-31
71	51	7	2013-01-01	3001-01-01
72	52	8	2000-01-21	2000-12-21
73	53	8	2001-01-21	2001-12-21
74	54	8	2002-01-21	2002-12-21
75	55	8	2003-01-21	2005-12-21
76	56	8	2006-01-01	2006-12-31
77	57	8	2007-01-01	2007-12-31
78	58	8	2008-01-01	2008-12-31
79	59	8	2009-01-01	2009-12-31
80	60	8	2010-01-01	2010-12-31
81	61	8	2011-01-01	2012-12-31
82	62	8	2013-01-01	3001-01-01
83	63	9	2000-01-21	2000-12-21
84	64	9	2001-01-21	2001-12-21
85	65	9	2002-01-21	2002-12-21
86	66	9	2003-01-21	2005-12-21
87	67	9	2006-01-01	2006-12-31
88	68	9	2007-01-01	2007-12-31
89	69	9	2008-01-01	2008-12-31
90	70	9	2008-01-01	3001-01-01
101	1	1	2000-01-21	2000-12-21
102	2	10	2001-01-21	2001-12-21
103	3	10	2002-01-21	2002-12-21
104	4	10	2003-01-21	2005-12-21
105	5	10	2006-01-01	2006-12-31
106	6	10	2007-01-01	2007-12-31
107	7	10	2008-01-01	2008-12-31
108	8	10	2009-01-01	2009-12-31
109	9	10	2010-01-01	2010-12-31
2	2	1	2001-01-01	2001-12-31
3	3	1	2002-01-01	2003-12-31
4	4	1	2004-01-01	2005-12-31
5	5	1	2006-01-01	2006-12-31
6	6	1	2007-01-01	2007-12-31
7	7	1	2008-01-01	2008-12-31
8	8	1	2009-01-01	2009-12-31
10	10	1	2011-01-01	2012-12-31
110	10	10	2011-01-01	2012-12-31
111	11	10	2013-01-01	3001-01-01
112	12	11	2000-01-21	2000-12-21
113	13	11	2001-01-21	2001-12-21
16	16	2	2006-01-01	2006-12-31
17	17	2	2007-01-01	2007-12-31
18	18	2	2008-01-01	2008-12-31
19	19	2	2009-01-01	2009-12-31
20	20	2	2010-01-01	2010-12-31
21	21	2	2011-01-01	2012-12-31
22	22	2	2013-01-01	3001-01-01
1	1	1	2000-01-21	2000-12-21
114	14	11	2002-01-21	2002-12-21
115	15	11	2003-01-21	2005-12-21
116	16	11	2006-01-01	2006-12-31
12	12	2	2000-01-21	2000-12-21
13	13	2	2001-01-21	2001-12-21
14	14	2	2002-01-21	2002-12-21
15	15	2	2003-01-21	2005-12-21
23	23	3	2000-01-21	2000-12-21
24	24	3	2001-01-21	2001-12-21
25	25	3	2002-01-21	2002-12-21
26	26	3	2003-01-21	2005-12-21
27	27	3	2006-01-01	2006-12-31
28	28	3	2007-01-01	2007-12-31
29	29	3	2008-01-01	2008-12-31
30	30	3	2009-01-01	2009-12-31
31	20	3	2010-01-01	2010-12-31
32	21	3	2011-01-01	2012-12-31
117	17	11	2007-01-01	2007-12-31
33	22	3	2013-01-01	2013-12-12
34	24	4	2003-01-21	2005-12-21
35	25	4	2006-01-01	2006-12-31
36	26	4	2007-01-01	2007-12-31
37	27	4	2008-01-01	2008-12-31
38	28	4	2009-01-01	2009-12-31
39	29	4	2010-01-01	2010-12-31
40	30	4	2011-01-01	2012-12-31
41	31	4	2013-01-01	3001-01-01
42	32	5	2000-01-21	2000-12-21
43	33	5	2001-01-21	2001-12-21
44	34	5	2002-01-21	2002-12-21
45	35	5	2003-01-21	2005-12-21
46	36	5	2006-01-01	2006-12-31
47	37	5	2007-01-01	2007-12-31
48	38	5	2008-01-01	2008-12-31
49	39	5	2009-01-01	2009-12-31
50	30	5	2010-01-01	2010-12-31
51	31	5	2011-01-01	2012-12-31
52	32	5	2013-01-01	3001-01-01
53	33	6	2000-01-21	2000-12-21
54	34	6	2001-01-21	2001-12-21
55	35	6	2002-01-21	2002-12-21
56	36	6	2003-01-21	2005-12-21
57	37	6	2006-01-01	2006-12-31
58	38	6	2007-01-01	2007-12-31
59	39	6	2008-01-01	2008-12-31
60	40	6	2008-01-01	3001-01-01
118	18	11	2008-01-01	2008-12-31
119	19	11	2009-01-01	2009-12-31
120	20	11	2010-01-01	2010-12-31
121	21	11	2011-01-01	2012-12-31
122	22	11	2013-01-01	3001-01-01
123	23	12	2000-01-21	2000-12-21
124	24	12	2001-01-21	2001-12-21
125	25	12	2002-01-21	2002-12-21
126	26	12	2003-01-21	2005-12-21
127	27	12	2006-01-01	2006-12-31
128	28	12	2007-01-01	2007-12-31
129	29	12	2008-01-01	2008-12-31
130	30	12	2009-01-01	2009-12-31
131	20	12	2010-01-01	2010-12-31
11	2	3	2013-12-15	3001-01-01
132	21	12	2011-01-01	2012-12-31
133	22	12	2013-01-01	3001-01-01
134	24	13	2003-01-21	2005-12-21
135	25	13	2006-01-01	2006-12-31
136	26	13	2007-01-01	2007-12-31
137	27	13	2008-01-01	2008-12-31
138	28	13	2009-01-01	2009-12-31
139	29	13	2010-01-01	2010-12-31
140	30	13	2011-01-01	2012-12-31
141	31	13	2013-01-01	3001-01-01
142	32	14	2000-01-21	2000-12-21
143	33	14	2001-01-21	2001-12-21
144	34	14	2002-01-21	2002-12-21
145	35	14	2003-01-21	2005-12-21
146	36	14	2006-01-01	2006-12-31
147	37	14	2007-01-01	2007-12-31
148	38	14	2008-01-01	2008-12-31
149	39	14	2009-01-01	2009-12-31
150	30	14	2010-01-01	2010-12-31
151	31	14	2011-01-01	2012-12-31
152	32	14	2013-01-01	3001-01-01
153	33	15	2000-01-21	2000-12-21
154	34	15	2001-01-21	2001-12-21
155	35	15	2002-01-21	2002-12-21
156	36	15	2003-01-21	2005-12-21
157	37	15	2006-01-01	2006-12-31
158	38	15	2007-01-01	2007-12-31
159	39	15	2008-01-01	2008-12-31
160	40	15	2008-01-01	3001-01-01
161	44	16	2003-01-21	2005-12-21
165	45	16	2006-01-01	2006-12-31
166	46	16	2007-01-01	2007-12-31
167	47	16	2008-01-01	2008-12-31
168	48	16	2009-01-01	2009-12-31
169	49	16	2010-01-01	2010-12-31
170	50	16	2011-01-01	2012-12-31
171	51	16	2013-01-01	3001-01-01
172	52	17	2000-01-21	2000-12-21
173	53	17	2001-01-21	2001-12-21
174	54	17	2002-01-21	2002-12-21
175	55	17	2003-01-21	2005-12-21
176	56	17	2006-01-01	2006-12-31
177	57	17	2007-01-01	2007-12-31
178	58	17	2008-01-01	2008-12-31
179	59	17	2009-01-01	2009-12-31
180	60	17	2010-01-01	2010-12-31
181	61	17	2011-01-01	2012-12-31
182	62	17	2013-01-01	3001-01-01
183	63	18	2000-01-21	2000-12-21
184	64	18	2001-01-21	2001-12-21
185	65	18	2002-01-21	2002-12-21
186	66	18	2003-01-21	2005-12-21
187	67	18	2006-01-01	2006-12-31
188	68	18	2007-01-01	2007-12-31
189	69	18	2008-01-01	2008-12-31
190	70	18	2008-01-01	3001-01-01
\.


--
-- Name: occupations_occupation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('occupations_occupation_id_seq', 11, true);


--
-- Data for Name: positions_position; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY positions_position (id, name, responsibilities, active) FROM stdin;
2	HR manager	Developing systems and processes within the organization that address the strategic needs of the business	t
3	Junior JAVA programmer	Develop java applications, working in a team.	t
4	Senior JAVA programmer	Develop super nice java applications.	t
1	CEO	The communicator role can involve the press and the rest of the outside world, as well as the organization's management and employees; the decision-making role involves high-level decisions about policy and strategy. As a leader of the company, the CEO/MD advises the board of directors, motivates employees, and drives change within the organization.	f
5	Security Analyst	Maintain awareness of Information Security standards, regulatory requirements, compliance frameworks and best practices, and ensure, where appropriate, that these are reflected in the Bruce Power Information Security program. 	t
6	Program Manager	Executes information assurance (IA) activities for the USAP enterprise.  Ensures FISMA program compliance, as well as serves as liaison with the NSF information assurance group and the NSF Chief Information Officer.  Oversees the operational IA program and coordinated incident response and reporting	t
7	Director of Information Technology Operations	The Director of Information Technology Operations reports to the CIO, and has direct reports from two departments:  the central Information Services Department, and Health and Hospital System’s Information Services.  	t
9	Mechnical Design Engineering Manager	Lead the development and implementation of high precision manufacturing processes in a demanding and high volume environment	t
10	 Optical Sensors Engineering Manager 	Hands-On Sensing System Hardware Engineering Leader to drive engineering activities and identify, specify, develop and test innovative sensing systems used in Apple products	t
11	Post Ramp Engineering Project Manager	The Engineering Project Manager (EPM) owns at the system level shipping iOS products in engineering/quality improvements/new suppliers qualifications areas. 	t
12	Technical Program Manager	Lead a team of engineers (DFx, DFm, test, SQE, PQE, etc) and others in support of new product development as well as sustaining operations and ensuring the contract manufacturer readiness for extremely high volume production	t
13	Advanced Manufacturing Engineer	Lead a team of engineers (DFx, DFm, test, SQE, PQE, etc) and others in support of new product development as well as sustaining operations and ensuring the contract manufacturer readiness for extremely high volume production	t
14	Mechanical / Industrial Engineer	As a mechanical engineer, you participate in the design, analysis, and prototyping of new concepts.	t
15	Lead Enterprise Network Engineer		t
16	Software Engineering Intern		t
17	Commodity Manager	Work with Engineering teams to make sure Google has the supplies and equipment to put into production the innovative products coming from our Engineering teams	t
18	Field Engineering	As a member of the team, you have a direct impact on design and feature enhancements to keep our systems running smoothly. You also ensure that network operations are safe and efficient by monitoring network performance, coordinating planned maintenance, adjusting hardware components and responding to network connectivity issues.	t
19	Engineering Project Specialist	You plan requirements with internal customers and usher projects through the entire project lifecycle. This includes managing project schedules, identifying risks and clearly communicating goals to project stakeholders.	t
20	Mechanical Building Services Engineer	You analyze and design improvements on engineering systems projects (e.g., cooling, electrical).	t
21	Quality Engineer	Establish, deliver and maintain product quality and reliability standards for Google's new technologies, leveraging existing tools and processes or developing new ones as required. Own cost of quality and manage it through the life of the product.	t
8	Process Engineering Technical Authority	Regional primary contact for process engineering, both internal and external to the region, including Upstream Engineering Centre (UEC ) and local regulatory bodies.	f
\.


--
-- Name: positions_position_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('positions_position_id_seq', 21, true);


--
-- Data for Name: records_record; Type: TABLE DATA; Schema: public; Owner: anna
--

COPY records_record (id, user_id, item_id, tt, vt) FROM stdin;
301	1	4	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
302	2	4	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
303	3	4	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
304	4	4	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
305	5	4	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
306	6	4	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
307	7	4	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
308	8	4	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
309	9	4	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
310	10	4	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
311	11	4	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
312	12	4	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
313	13	4	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
314	14	4	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
315	15	4	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
1	1	1	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
2	2	1	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
3	3	1	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
4	4	1	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
5	5	1	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
6	6	1	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
7	7	1	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
8	8	1	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
9	9	1	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
316	16	4	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
10	10	1	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
11	11	1	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
317	17	4	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
12	12	1	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
13	13	1	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
318	18	4	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
14	14	1	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
15	15	1	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
16	16	1	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
17	17	1	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
18	18	1	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
19	19	1	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
20	20	1	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
21	21	1	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
319	19	4	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
22	22	1	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
23	23	1	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
320	20	4	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
24	24	1	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
25	25	1	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
26	26	1	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
27	27	1	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
321	21	4	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
28	28	1	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
29	29	1	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
30	30	1	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
322	22	4	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
323	23	4	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
324	24	4	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
325	25	4	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
326	26	4	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
327	27	4	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
328	28	4	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
110	10	2	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
111	11	2	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
112	12	2	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
113	13	2	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
114	14	2	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
115	15	2	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
116	16	2	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
117	17	2	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
118	18	2	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
119	19	2	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
120	20	2	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
121	21	2	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
122	22	2	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
123	23	2	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
124	24	2	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
125	25	2	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
126	26	2	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
127	27	2	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
128	28	2	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
129	29	2	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
130	30	2	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
101	1	1	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
102	2	2	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
103	3	2	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
104	4	2	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
105	5	2	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
106	6	2	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
107	7	2	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
108	8	2	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
109	9	2	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
329	29	4	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
330	30	4	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
401	1	5	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
402	2	5	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
403	3	5	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
404	5	5	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
405	5	5	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
406	6	5	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
407	7	5	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
408	8	5	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
409	9	5	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
410	10	5	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
411	11	5	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
412	12	5	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
413	13	5	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
414	14	5	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
415	15	5	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
416	16	5	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
417	17	5	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
418	18	5	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
419	19	5	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
201	1	3	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
202	2	3	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
203	3	3	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
204	4	3	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
205	5	3	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
206	6	3	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
207	7	3	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
208	8	3	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
209	9	3	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
210	10	3	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
211	11	3	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
212	12	3	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
213	13	3	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
214	14	3	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
215	15	3	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
216	16	3	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
217	17	3	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
218	18	3	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
219	19	3	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
220	20	3	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
221	21	3	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
222	22	3	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
223	23	3	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
224	24	3	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
225	25	3	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
226	26	3	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
227	27	3	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
228	28	3	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
229	29	3	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
230	30	3	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
420	20	5	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
421	21	5	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
422	22	5	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
423	23	5	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
424	24	5	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
425	25	5	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
426	26	5	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
427	27	5	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
428	28	5	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
429	29	5	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
430	30	5	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
502	2	6	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
503	3	6	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
504	4	6	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
505	5	6	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
506	6	6	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
507	7	6	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
508	8	6	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
509	9	6	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
510	10	6	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
511	11	6	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
512	12	6	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
513	13	6	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
514	14	6	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
515	15	6	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
516	16	6	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
517	17	6	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
518	18	6	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
519	19	6	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
520	20	6	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
521	21	6	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
522	22	6	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
523	23	6	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
524	24	6	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
525	25	6	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
526	26	6	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
527	27	6	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
528	28	6	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
529	29	6	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
530	30	6	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
601	1	7	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
602	2	7	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
603	3	7	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
604	4	7	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
605	5	7	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
606	6	7	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
607	7	7	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
608	8	7	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
609	9	7	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
610	10	7	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
611	11	7	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
612	12	7	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
613	13	7	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
614	14	7	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
615	15	7	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
616	16	7	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
617	17	7	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
618	18	7	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
619	19	7	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
620	20	7	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
621	21	7	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
622	22	7	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
623	23	7	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
624	24	7	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
625	25	7	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
626	26	7	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
627	27	7	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
628	28	7	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
629	29	7	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
630	30	7	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
701	1	8	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
702	2	8	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
703	3	8	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
704	4	8	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
705	5	8	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
706	6	8	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
707	7	8	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
708	8	8	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
709	9	8	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
710	10	8	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
711	11	8	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
712	12	8	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
713	13	8	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
714	14	8	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
715	15	8	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
716	16	8	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
717	17	8	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
718	18	8	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
719	19	8	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
720	20	8	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
721	21	8	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
722	22	8	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
723	23	8	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
724	24	8	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
725	25	8	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
726	26	8	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
727	27	8	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
728	28	8	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
729	29	8	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
730	30	8	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
801	1	9	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
802	2	9	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
803	3	9	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
804	4	9	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
805	5	9	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
806	6	9	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
807	7	9	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
808	8	9	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
809	9	9	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
810	10	9	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
811	11	9	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
812	12	9	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
813	13	9	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
814	14	9	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
815	15	9	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
816	16	9	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
817	17	9	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
818	18	9	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
819	19	9	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
820	20	9	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
821	21	9	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
822	22	9	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
823	23	9	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
824	24	9	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
825	25	9	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
826	26	9	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
827	27	9	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
828	28	9	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
829	29	9	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
830	30	9	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
901	1	19	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
902	2	19	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
903	3	19	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
904	4	19	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
905	5	19	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
906	6	19	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
907	7	19	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
908	8	19	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
909	9	19	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
910	10	19	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
911	11	19	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
912	12	19	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
913	13	19	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
914	14	19	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
915	15	19	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
916	16	19	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
917	17	19	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
918	18	19	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
919	19	19	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
920	20	19	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
921	21	19	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
922	22	19	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
923	23	19	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
924	24	19	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
925	25	19	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
926	26	19	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
927	27	19	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
928	28	19	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
929	29	19	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
930	30	19	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
31	1	10	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
32	2	10	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
33	3	10	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
34	4	10	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
35	5	10	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
36	6	10	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
37	7	10	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
38	8	10	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
39	9	10	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
40	10	10	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
41	11	10	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
42	12	10	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
43	13	10	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
44	14	10	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
45	15	10	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
46	16	10	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
47	17	10	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
48	18	10	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
49	19	10	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
50	20	10	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
51	21	10	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
52	22	10	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
53	23	10	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
54	24	10	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
55	25	10	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
56	26	10	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
57	27	10	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
58	28	10	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
59	29	10	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
60	30	10	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
131	1	11	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
132	2	11	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
133	3	11	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
134	4	11	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
135	5	11	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
136	6	11	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
137	7	11	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
138	8	11	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
139	9	11	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
140	10	11	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
141	11	11	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
142	12	11	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
143	13	11	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
144	14	11	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
145	15	11	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
146	16	11	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
147	17	11	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
148	18	11	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
149	19	11	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
150	20	11	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
151	21	11	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
152	22	11	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
153	23	11	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
154	24	11	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
155	25	11	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
156	26	11	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
157	27	11	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
158	28	11	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
159	29	11	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
160	30	11	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
231	1	12	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
232	2	12	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
233	3	12	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
234	4	12	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
235	5	12	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
236	6	12	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
237	7	12	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
238	8	12	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
239	9	12	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
240	10	12	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
241	11	12	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
242	12	12	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
243	13	12	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
244	14	12	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
245	15	12	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
246	16	12	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
247	17	12	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
248	18	12	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
249	19	12	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
250	20	12	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
251	21	12	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
252	22	12	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
253	23	12	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
254	24	12	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
255	25	12	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
256	26	12	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
257	27	12	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
258	28	12	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
259	29	12	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
260	30	12	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
331	1	13	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
332	2	13	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
333	3	13	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
334	4	13	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
335	5	13	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
336	6	13	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
337	7	13	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
338	8	13	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
339	9	13	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
340	10	13	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
341	11	13	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
342	12	13	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
343	13	13	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
344	14	13	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
345	15	13	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
346	16	13	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
347	17	13	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
348	18	13	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
349	19	13	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
350	20	13	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
351	21	13	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
352	22	13	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
353	23	13	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
354	24	13	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
355	25	13	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
356	26	13	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
357	27	13	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
358	28	13	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
359	29	13	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
360	30	13	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
431	1	14	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
432	2	14	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
433	3	14	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
434	4	14	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
435	5	14	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
436	6	14	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
437	7	14	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
438	8	14	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
439	9	14	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
440	10	14	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
441	11	14	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
442	12	14	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
443	14	14	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
444	14	14	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
445	15	14	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
446	16	14	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
447	17	14	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
448	18	14	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
449	19	14	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
450	20	14	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
451	21	14	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
452	22	14	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
453	23	14	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
454	24	14	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
455	25	14	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
456	26	14	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
457	27	14	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
458	28	14	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
459	29	14	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
460	30	14	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
531	1	15	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
532	2	15	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
533	3	15	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
534	4	15	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
535	5	15	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
536	6	15	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
537	7	15	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
538	8	15	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
539	9	15	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
540	10	15	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
541	11	15	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
542	12	15	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
543	13	15	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
544	14	15	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
545	15	15	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
546	16	15	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
547	17	15	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
548	18	15	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
549	19	15	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
550	20	15	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
551	21	15	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
552	22	15	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
553	23	15	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
554	24	15	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
555	25	15	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
556	26	15	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
557	27	15	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
558	28	15	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
559	29	15	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
560	30	15	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
631	1	16	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
632	2	16	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
633	3	16	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
634	4	16	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
635	5	16	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
636	6	16	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
637	7	16	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
638	8	16	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
639	9	16	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
640	10	16	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
641	11	16	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
642	12	16	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
643	13	16	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
644	14	16	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
645	15	16	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
646	16	16	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
647	17	16	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
648	18	16	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
649	19	16	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
650	20	16	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
651	21	16	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
652	22	16	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
653	23	16	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
654	24	16	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
655	25	16	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
656	26	16	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
657	27	16	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
658	28	16	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
659	29	16	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
660	30	16	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
731	1	17	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
732	2	17	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
733	3	17	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
734	4	17	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
735	5	17	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
736	6	17	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
737	7	17	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
738	8	17	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
739	9	17	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
740	10	17	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
741	11	17	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
742	12	17	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
743	13	17	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
744	14	17	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
745	15	17	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
746	16	17	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
747	17	17	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
748	18	17	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
749	19	17	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
750	20	17	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
751	21	17	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
752	22	17	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
753	23	17	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
754	24	17	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
755	25	17	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
756	26	17	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
757	27	17	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
758	28	17	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
759	29	17	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
760	30	17	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
831	1	18	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
832	2	18	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
833	3	18	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
834	4	18	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
835	5	18	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
836	6	18	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
837	7	18	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
838	8	18	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
839	9	18	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
840	10	18	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
841	11	18	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
842	12	18	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
843	13	18	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
844	14	18	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
845	15	18	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
846	16	18	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
847	17	18	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
848	18	18	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
849	19	18	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
850	20	18	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
851	21	18	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
852	22	18	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
853	23	18	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
854	24	18	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
855	25	18	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
856	26	18	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
857	27	18	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
858	28	18	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
859	29	18	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
860	30	18	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
931	1	19	{2013-01-01,2013-01-01,2013-01-02,2013-01-02}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02}
932	2	19	{2013-01-11,2013-01-11,2013-01-12,2013-01-12}	{2013-01-11,2013-01-12,2013-01-11,2013-01-12}
933	3	19	{2013-01-21,2013-01-21,2013-01-22,2013-01-22}	{2013-01-21,2013-01-22,2013-01-21,2013-01-22}
934	4	19	{2013-02-01,2013-02-01,2013-02-02,2013-02-02}	{2013-02-01,2013-02-02,2013-02-01,2013-02-02}
935	5	19	{2013-02-11,2013-02-11,2013-02-12,2013-02-12}	{2013-02-11,2013-02-12,2013-02-11,2013-02-12}
936	6	19	{2013-02-21,2013-02-21,2013-02-22,2013-02-22}	{2013-02-21,2013-02-22,2013-02-21,2013-02-22}
937	7	19	{2013-03-01,2013-03-01,2013-03-02,2013-03-02}	{2013-03-01,2013-03-02,2013-03-01,2013-03-02}
938	8	19	{2013-03-11,2013-03-11,2013-03-12,2013-03-12}	{2013-03-11,2013-03-12,2013-03-11,2013-03-12}
939	9	19	{2013-03-21,2013-03-21,2013-03-22,2013-03-22}	{2013-03-21,2013-03-22,2013-03-21,2013-03-22}
940	10	19	{2013-04-01,2013-04-01,2013-04-02,2013-04-02}	{2013-04-01,2013-04-02,2013-04-01,2013-04-02}
941	11	19	{2013-04-11,2013-04-11,2013-04-12,2013-04-12}	{2013-04-11,2013-04-12,2013-04-11,2013-04-12}
942	12	19	{2013-04-21,2013-04-21,2013-04-22,2013-04-22}	{2013-04-21,2013-04-22,2013-04-21,2013-04-22}
943	13	19	{2013-05-01,2013-05-01,2013-05-02,2013-05-02}	{2013-05-01,2013-05-02,2013-05-01,2013-05-02}
944	14	19	{2013-05-11,2013-05-11,2013-05-12,2013-05-12}	{2013-05-11,2013-05-12,2013-05-11,2013-05-12}
945	15	19	{2013-05-21,2013-05-21,2013-05-22,2013-05-22}	{2013-05-21,2013-05-22,2013-05-21,2013-05-22}
946	16	19	{2013-06-01,2013-06-01,2013-06-02,2013-06-02}	{2013-06-01,2013-06-02,2013-06-01,2013-06-02}
947	17	19	{2013-06-11,2013-06-11,2013-06-12,2013-06-12}	{2013-06-11,2013-06-12,2013-06-11,2013-06-12}
948	18	19	{2013-06-21,2013-06-21,2013-06-22,2013-06-22}	{2013-06-21,2013-06-22,2013-06-21,2013-06-22}
949	19	19	{2013-07-01,2013-07-01,2013-07-02,2013-07-02}	{2013-07-01,2013-07-02,2013-07-01,2013-07-02}
950	20	19	{2013-07-11,2013-07-11,2013-07-12,2013-07-12}	{2013-07-11,2013-07-12,2013-07-11,2013-07-12}
951	21	19	{2013-07-21,2013-07-21,2013-07-22,2013-07-22}	{2013-07-21,2013-07-22,2013-07-21,2013-07-22}
952	22	19	{2013-08-01,2013-08-01,2013-08-02,2013-08-02}	{2013-08-01,2013-08-02,2013-08-01,2013-08-02}
953	23	19	{2013-08-11,2013-08-11,2013-08-12,2013-08-12}	{2013-08-11,2013-08-12,2013-08-11,2013-08-12}
954	24	19	{2013-08-21,2013-08-21,2013-08-22,2013-08-22}	{2013-08-21,2013-08-22,2013-08-21,2013-08-22}
955	25	19	{2013-09-01,2013-09-01,2013-09-02,2013-09-02}	{2013-09-01,2013-09-02,2013-09-01,2013-09-02}
956	26	19	{2013-09-11,2013-09-11,2013-09-12,2013-09-12}	{2013-09-11,2013-09-12,2013-09-11,2013-09-12}
957	27	19	{2013-09-21,2013-09-21,2013-09-22,2013-09-22}	{2013-09-21,2013-09-22,2013-09-21,2013-09-22}
958	28	19	{2013-10-01,2013-10-01,2013-10-02,2013-10-02}	{2013-10-01,2013-10-02,2013-10-01,2013-10-02}
959	29	19	{2013-10-11,2013-10-11,2013-10-12,2013-10-12}	{2013-10-11,2013-10-12,2013-10-11,2013-10-12}
960	30	19	{2013-10-21,2013-10-21,2013-10-22,2013-10-22}	{2013-10-21,2013-10-22,2013-10-21,2013-10-22}
1001	1	21	{2012-01-01,2012-01-01,2012-01-02,2012-01-02}	{2012-01-01,2012-01-02,2012-01-01,2012-01-02}
1002	2	21	{2012-01-11,2012-01-11,2012-01-12,2012-01-12}	{2012-01-11,2012-01-12,2012-01-11,2012-01-12}
1003	3	21	{2012-01-21,2012-01-21,2012-01-22,2012-01-22}	{2012-01-21,2012-01-22,2012-01-21,2012-01-22}
1004	4	21	{2012-02-01,2012-02-01,2012-02-02,2012-02-02}	{2012-02-01,2012-02-02,2012-02-01,2012-02-02}
1005	5	21	{2012-02-11,2012-02-11,2012-02-12,2012-02-12}	{2012-02-11,2012-02-12,2012-02-11,2012-02-12}
1006	6	21	{2012-02-21,2012-02-21,2012-02-22,2012-02-22}	{2012-02-21,2012-02-22,2012-02-21,2012-02-22}
1007	7	21	{2012-03-01,2012-03-01,2012-03-02,2012-03-02}	{2012-03-01,2012-03-02,2012-03-01,2012-03-02}
1008	8	21	{2012-03-11,2012-03-11,2012-03-12,2012-03-12}	{2012-03-11,2012-03-12,2012-03-11,2012-03-12}
1009	9	21	{2012-03-21,2012-03-21,2012-03-22,2012-03-22}	{2012-03-21,2012-03-22,2012-03-21,2012-03-22}
1010	10	21	{2012-04-01,2012-04-01,2012-04-02,2012-04-02}	{2012-04-01,2012-04-02,2012-04-01,2012-04-02}
1011	11	21	{2012-04-11,2012-04-11,2012-04-12,2012-04-12}	{2012-04-11,2012-04-12,2012-04-11,2012-04-12}
1012	12	21	{2012-04-21,2012-04-21,2012-04-22,2012-04-22}	{2012-04-21,2012-04-22,2012-04-21,2012-04-22}
1013	13	21	{2012-05-01,2012-05-01,2012-05-02,2012-05-02}	{2012-05-01,2012-05-02,2012-05-01,2012-05-02}
1014	14	21	{2012-05-11,2012-05-11,2012-05-12,2012-05-12}	{2012-05-11,2012-05-12,2012-05-11,2012-05-12}
1015	15	21	{2012-05-21,2012-05-21,2012-05-22,2012-05-22}	{2012-05-21,2012-05-22,2012-05-21,2012-05-22}
1016	16	21	{2012-06-01,2012-06-01,2012-06-02,2012-06-02}	{2012-06-01,2012-06-02,2012-06-01,2012-06-02}
1017	17	21	{2012-06-11,2012-06-11,2012-06-12,2012-06-12}	{2012-06-11,2012-06-12,2012-06-11,2012-06-12}
1018	18	21	{2012-06-21,2012-06-21,2012-06-22,2012-06-22}	{2012-06-21,2012-06-22,2012-06-21,2012-06-22}
1019	19	21	{2012-07-01,2012-07-01,2012-07-02,2012-07-02}	{2012-07-01,2012-07-02,2012-07-01,2012-07-02}
1020	20	21	{2012-07-11,2012-07-11,2012-07-12,2012-07-12}	{2012-07-11,2012-07-12,2012-07-11,2012-07-12}
1021	21	21	{2012-07-21,2012-07-21,2012-07-22,2012-07-22}	{2012-07-21,2012-07-22,2012-07-21,2012-07-22}
1022	22	21	{2012-08-01,2012-08-01,2012-08-02,2012-08-02}	{2012-08-01,2012-08-02,2012-08-01,2012-08-02}
1023	23	21	{2012-08-11,2012-08-11,2012-08-12,2012-08-12}	{2012-08-11,2012-08-12,2012-08-11,2012-08-12}
1024	24	21	{2012-08-21,2012-08-21,2012-08-22,2012-08-22}	{2012-08-21,2012-08-22,2012-08-21,2012-08-22}
1025	25	21	{2012-09-01,2012-09-01,2012-09-02,2012-09-02}	{2012-09-01,2012-09-02,2012-09-01,2012-09-02}
1026	26	21	{2012-09-11,2012-09-11,2012-09-12,2012-09-12}	{2012-09-11,2012-09-12,2012-09-11,2012-09-12}
1027	27	21	{2012-09-21,2012-09-21,2012-09-22,2012-09-22}	{2012-09-21,2012-09-22,2012-09-21,2012-09-22}
1028	28	21	{2012-10-01,2012-10-01,2012-10-02,2012-10-02}	{2012-10-01,2012-10-02,2012-10-01,2012-10-02}
1029	29	21	{2012-10-11,2012-10-11,2012-10-12,2012-10-12}	{2012-10-11,2012-10-12,2012-10-11,2012-10-12}
1030	30	21	{2012-10-21,2012-10-21,2012-10-22,2012-10-22}	{2012-10-21,2012-10-22,2012-10-21,2012-10-22}
1101	1	21	{2012-01-01,2012-01-01,2012-01-02,2012-01-02}	{2012-01-01,2012-01-02,2012-01-01,2012-01-02}
1102	2	22	{2012-01-11,2012-01-11,2012-01-12,2012-01-12}	{2012-01-11,2012-01-12,2012-01-11,2012-01-12}
1103	3	22	{2012-01-21,2012-01-21,2012-01-22,2012-01-22}	{2012-01-21,2012-01-22,2012-01-21,2012-01-22}
1104	4	22	{2012-02-01,2012-02-01,2012-02-02,2012-02-02}	{2012-02-01,2012-02-02,2012-02-01,2012-02-02}
1105	5	22	{2012-02-11,2012-02-11,2012-02-12,2012-02-12}	{2012-02-11,2012-02-12,2012-02-11,2012-02-12}
1106	6	22	{2012-02-21,2012-02-21,2012-02-22,2012-02-22}	{2012-02-21,2012-02-22,2012-02-21,2012-02-22}
1107	7	22	{2012-03-01,2012-03-01,2012-03-02,2012-03-02}	{2012-03-01,2012-03-02,2012-03-01,2012-03-02}
1108	8	22	{2012-03-11,2012-03-11,2012-03-12,2012-03-12}	{2012-03-11,2012-03-12,2012-03-11,2012-03-12}
1109	9	22	{2012-03-21,2012-03-21,2012-03-22,2012-03-22}	{2012-03-21,2012-03-22,2012-03-21,2012-03-22}
1110	10	22	{2012-04-01,2012-04-01,2012-04-02,2012-04-02}	{2012-04-01,2012-04-02,2012-04-01,2012-04-02}
1111	11	22	{2012-04-11,2012-04-11,2012-04-12,2012-04-12}	{2012-04-11,2012-04-12,2012-04-11,2012-04-12}
1112	12	22	{2012-04-21,2012-04-21,2012-04-22,2012-04-22}	{2012-04-21,2012-04-22,2012-04-21,2012-04-22}
1113	13	22	{2012-05-01,2012-05-01,2012-05-02,2012-05-02}	{2012-05-01,2012-05-02,2012-05-01,2012-05-02}
1114	14	22	{2012-05-11,2012-05-11,2012-05-12,2012-05-12}	{2012-05-11,2012-05-12,2012-05-11,2012-05-12}
1115	15	22	{2012-05-21,2012-05-21,2012-05-22,2012-05-22}	{2012-05-21,2012-05-22,2012-05-21,2012-05-22}
1116	16	22	{2012-06-01,2012-06-01,2012-06-02,2012-06-02}	{2012-06-01,2012-06-02,2012-06-01,2012-06-02}
1117	17	22	{2012-06-11,2012-06-11,2012-06-12,2012-06-12}	{2012-06-11,2012-06-12,2012-06-11,2012-06-12}
1118	18	22	{2012-06-21,2012-06-21,2012-06-22,2012-06-22}	{2012-06-21,2012-06-22,2012-06-21,2012-06-22}
1119	19	22	{2012-07-01,2012-07-01,2012-07-02,2012-07-02}	{2012-07-01,2012-07-02,2012-07-01,2012-07-02}
1120	20	22	{2012-07-11,2012-07-11,2012-07-12,2012-07-12}	{2012-07-11,2012-07-12,2012-07-11,2012-07-12}
1121	21	22	{2012-07-21,2012-07-21,2012-07-22,2012-07-22}	{2012-07-21,2012-07-22,2012-07-21,2012-07-22}
1122	22	22	{2012-08-01,2012-08-01,2012-08-02,2012-08-02}	{2012-08-01,2012-08-02,2012-08-01,2012-08-02}
1123	23	22	{2012-08-11,2012-08-11,2012-08-12,2012-08-12}	{2012-08-11,2012-08-12,2012-08-11,2012-08-12}
1124	24	22	{2012-08-21,2012-08-21,2012-08-22,2012-08-22}	{2012-08-21,2012-08-22,2012-08-21,2012-08-22}
1125	25	22	{2012-09-01,2012-09-01,2012-09-02,2012-09-02}	{2012-09-01,2012-09-02,2012-09-01,2012-09-02}
1126	26	22	{2012-09-11,2012-09-11,2012-09-12,2012-09-12}	{2012-09-11,2012-09-12,2012-09-11,2012-09-12}
1127	27	22	{2012-09-21,2012-09-21,2012-09-22,2012-09-22}	{2012-09-21,2012-09-22,2012-09-21,2012-09-22}
1128	28	22	{2012-10-01,2012-10-01,2012-10-02,2012-10-02}	{2012-10-01,2012-10-02,2012-10-01,2012-10-02}
1129	29	22	{2012-10-11,2012-10-11,2012-10-12,2012-10-12}	{2012-10-11,2012-10-12,2012-10-11,2012-10-12}
1130	30	22	{2012-10-21,2012-10-21,2012-10-22,2012-10-22}	{2012-10-21,2012-10-22,2012-10-21,2012-10-22}
1201	1	23	{2012-01-01,2012-01-01,2012-01-02,2012-01-02}	{2012-01-01,2012-01-02,2012-01-01,2012-01-02}
1202	2	23	{2012-01-11,2012-01-11,2012-01-12,2012-01-12}	{2012-01-11,2012-01-12,2012-01-11,2012-01-12}
1203	3	23	{2012-01-21,2012-01-21,2012-01-22,2012-01-22}	{2012-01-21,2012-01-22,2012-01-21,2012-01-22}
1204	4	23	{2012-02-01,2012-02-01,2012-02-02,2012-02-02}	{2012-02-01,2012-02-02,2012-02-01,2012-02-02}
1205	5	23	{2012-02-11,2012-02-11,2012-02-12,2012-02-12}	{2012-02-11,2012-02-12,2012-02-11,2012-02-12}
1206	6	23	{2012-02-21,2012-02-21,2012-02-22,2012-02-22}	{2012-02-21,2012-02-22,2012-02-21,2012-02-22}
1207	7	23	{2012-03-01,2012-03-01,2012-03-02,2012-03-02}	{2012-03-01,2012-03-02,2012-03-01,2012-03-02}
1208	8	23	{2012-03-11,2012-03-11,2012-03-12,2012-03-12}	{2012-03-11,2012-03-12,2012-03-11,2012-03-12}
1209	9	23	{2012-03-21,2012-03-21,2012-03-22,2012-03-22}	{2012-03-21,2012-03-22,2012-03-21,2012-03-22}
1210	10	23	{2012-04-01,2012-04-01,2012-04-02,2012-04-02}	{2012-04-01,2012-04-02,2012-04-01,2012-04-02}
1211	11	23	{2012-04-11,2012-04-11,2012-04-12,2012-04-12}	{2012-04-11,2012-04-12,2012-04-11,2012-04-12}
1212	12	23	{2012-04-21,2012-04-21,2012-04-22,2012-04-22}	{2012-04-21,2012-04-22,2012-04-21,2012-04-22}
1213	13	23	{2012-05-01,2012-05-01,2012-05-02,2012-05-02}	{2012-05-01,2012-05-02,2012-05-01,2012-05-02}
1214	14	23	{2012-05-11,2012-05-11,2012-05-12,2012-05-12}	{2012-05-11,2012-05-12,2012-05-11,2012-05-12}
1215	15	23	{2012-05-21,2012-05-21,2012-05-22,2012-05-22}	{2012-05-21,2012-05-22,2012-05-21,2012-05-22}
1216	16	23	{2012-06-01,2012-06-01,2012-06-02,2012-06-02}	{2012-06-01,2012-06-02,2012-06-01,2012-06-02}
1217	17	23	{2012-06-11,2012-06-11,2012-06-12,2012-06-12}	{2012-06-11,2012-06-12,2012-06-11,2012-06-12}
1218	18	23	{2012-06-21,2012-06-21,2012-06-22,2012-06-22}	{2012-06-21,2012-06-22,2012-06-21,2012-06-22}
1219	19	23	{2012-07-01,2012-07-01,2012-07-02,2012-07-02}	{2012-07-01,2012-07-02,2012-07-01,2012-07-02}
1220	20	23	{2012-07-11,2012-07-11,2012-07-12,2012-07-12}	{2012-07-11,2012-07-12,2012-07-11,2012-07-12}
1221	21	23	{2012-07-21,2012-07-21,2012-07-22,2012-07-22}	{2012-07-21,2012-07-22,2012-07-21,2012-07-22}
1222	22	23	{2012-08-01,2012-08-01,2012-08-02,2012-08-02}	{2012-08-01,2012-08-02,2012-08-01,2012-08-02}
1223	23	23	{2012-08-11,2012-08-11,2012-08-12,2012-08-12}	{2012-08-11,2012-08-12,2012-08-11,2012-08-12}
1224	24	23	{2012-08-21,2012-08-21,2012-08-22,2012-08-22}	{2012-08-21,2012-08-22,2012-08-21,2012-08-22}
1225	25	23	{2012-09-01,2012-09-01,2012-09-02,2012-09-02}	{2012-09-01,2012-09-02,2012-09-01,2012-09-02}
1226	26	23	{2012-09-11,2012-09-11,2012-09-12,2012-09-12}	{2012-09-11,2012-09-12,2012-09-11,2012-09-12}
1227	27	23	{2012-09-21,2012-09-21,2012-09-22,2012-09-22}	{2012-09-21,2012-09-22,2012-09-21,2012-09-22}
1228	28	23	{2012-10-01,2012-10-01,2012-10-02,2012-10-02}	{2012-10-01,2012-10-02,2012-10-01,2012-10-02}
1229	29	23	{2012-10-11,2012-10-11,2012-10-12,2012-10-12}	{2012-10-11,2012-10-12,2012-10-11,2012-10-12}
1230	30	23	{2012-10-21,2012-10-21,2012-10-22,2012-10-22}	{2012-10-21,2012-10-22,2012-10-21,2012-10-22}
1301	1	24	{2012-01-01,2012-01-01,2012-01-02,2012-01-02}	{2012-01-01,2012-01-02,2012-01-01,2012-01-02}
1302	2	24	{2012-01-11,2012-01-11,2012-01-12,2012-01-12}	{2012-01-11,2012-01-12,2012-01-11,2012-01-12}
1303	3	24	{2012-01-21,2012-01-21,2012-01-22,2012-01-22}	{2012-01-21,2012-01-22,2012-01-21,2012-01-22}
1304	4	24	{2012-02-01,2012-02-01,2012-02-02,2012-02-02}	{2012-02-01,2012-02-02,2012-02-01,2012-02-02}
1305	5	24	{2012-02-11,2012-02-11,2012-02-12,2012-02-12}	{2012-02-11,2012-02-12,2012-02-11,2012-02-12}
1306	6	24	{2012-02-21,2012-02-21,2012-02-22,2012-02-22}	{2012-02-21,2012-02-22,2012-02-21,2012-02-22}
1307	7	24	{2012-03-01,2012-03-01,2012-03-02,2012-03-02}	{2012-03-01,2012-03-02,2012-03-01,2012-03-02}
1308	8	24	{2012-03-11,2012-03-11,2012-03-12,2012-03-12}	{2012-03-11,2012-03-12,2012-03-11,2012-03-12}
1309	9	24	{2012-03-21,2012-03-21,2012-03-22,2012-03-22}	{2012-03-21,2012-03-22,2012-03-21,2012-03-22}
1310	10	24	{2012-04-01,2012-04-01,2012-04-02,2012-04-02}	{2012-04-01,2012-04-02,2012-04-01,2012-04-02}
1311	11	24	{2012-04-11,2012-04-11,2012-04-12,2012-04-12}	{2012-04-11,2012-04-12,2012-04-11,2012-04-12}
1312	12	24	{2012-04-21,2012-04-21,2012-04-22,2012-04-22}	{2012-04-21,2012-04-22,2012-04-21,2012-04-22}
1313	13	24	{2012-05-01,2012-05-01,2012-05-02,2012-05-02}	{2012-05-01,2012-05-02,2012-05-01,2012-05-02}
1314	14	24	{2012-05-11,2012-05-11,2012-05-12,2012-05-12}	{2012-05-11,2012-05-12,2012-05-11,2012-05-12}
1315	15	24	{2012-05-21,2012-05-21,2012-05-22,2012-05-22}	{2012-05-21,2012-05-22,2012-05-21,2012-05-22}
1316	16	24	{2012-06-01,2012-06-01,2012-06-02,2012-06-02}	{2012-06-01,2012-06-02,2012-06-01,2012-06-02}
1317	17	24	{2012-06-11,2012-06-11,2012-06-12,2012-06-12}	{2012-06-11,2012-06-12,2012-06-11,2012-06-12}
1318	18	24	{2012-06-21,2012-06-21,2012-06-22,2012-06-22}	{2012-06-21,2012-06-22,2012-06-21,2012-06-22}
1319	19	24	{2012-07-01,2012-07-01,2012-07-02,2012-07-02}	{2012-07-01,2012-07-02,2012-07-01,2012-07-02}
1320	20	24	{2012-07-11,2012-07-11,2012-07-12,2012-07-12}	{2012-07-11,2012-07-12,2012-07-11,2012-07-12}
1321	21	24	{2012-07-21,2012-07-21,2012-07-22,2012-07-22}	{2012-07-21,2012-07-22,2012-07-21,2012-07-22}
1322	22	24	{2012-08-01,2012-08-01,2012-08-02,2012-08-02}	{2012-08-01,2012-08-02,2012-08-01,2012-08-02}
1323	23	24	{2012-08-11,2012-08-11,2012-08-12,2012-08-12}	{2012-08-11,2012-08-12,2012-08-11,2012-08-12}
1324	24	24	{2012-08-21,2012-08-21,2012-08-22,2012-08-22}	{2012-08-21,2012-08-22,2012-08-21,2012-08-22}
1325	25	24	{2012-09-01,2012-09-01,2012-09-02,2012-09-02}	{2012-09-01,2012-09-02,2012-09-01,2012-09-02}
1326	26	24	{2012-09-11,2012-09-11,2012-09-12,2012-09-12}	{2012-09-11,2012-09-12,2012-09-11,2012-09-12}
1327	27	24	{2012-09-21,2012-09-21,2012-09-22,2012-09-22}	{2012-09-21,2012-09-22,2012-09-21,2012-09-22}
1328	28	24	{2012-10-01,2012-10-01,2012-10-02,2012-10-02}	{2012-10-01,2012-10-02,2012-10-01,2012-10-02}
1329	29	24	{2012-10-11,2012-10-11,2012-10-12,2012-10-12}	{2012-10-11,2012-10-12,2012-10-11,2012-10-12}
1330	30	24	{2012-10-21,2012-10-21,2012-10-22,2012-10-22}	{2012-10-21,2012-10-22,2012-10-21,2012-10-22}
1401	1	25	{2012-01-01,2012-01-01,2012-01-02,2012-01-02}	{2012-01-01,2012-01-02,2012-01-01,2012-01-02}
1402	2	25	{2012-01-11,2012-01-11,2012-01-12,2012-01-12}	{2012-01-11,2012-01-12,2012-01-11,2012-01-12}
1403	3	25	{2012-01-21,2012-01-21,2012-01-22,2012-01-22}	{2012-01-21,2012-01-22,2012-01-21,2012-01-22}
1404	5	25	{2012-02-01,2012-02-01,2012-02-02,2012-02-02}	{2012-02-01,2012-02-02,2012-02-01,2012-02-02}
1405	5	25	{2012-02-11,2012-02-11,2012-02-12,2012-02-12}	{2012-02-11,2012-02-12,2012-02-11,2012-02-12}
1406	6	25	{2012-02-21,2012-02-21,2012-02-22,2012-02-22}	{2012-02-21,2012-02-22,2012-02-21,2012-02-22}
1407	7	25	{2012-03-01,2012-03-01,2012-03-02,2012-03-02}	{2012-03-01,2012-03-02,2012-03-01,2012-03-02}
1408	8	25	{2012-03-11,2012-03-11,2012-03-12,2012-03-12}	{2012-03-11,2012-03-12,2012-03-11,2012-03-12}
1409	9	25	{2012-03-21,2012-03-21,2012-03-22,2012-03-22}	{2012-03-21,2012-03-22,2012-03-21,2012-03-22}
1410	10	25	{2012-04-01,2012-04-01,2012-04-02,2012-04-02}	{2012-04-01,2012-04-02,2012-04-01,2012-04-02}
1411	11	25	{2012-04-11,2012-04-11,2012-04-12,2012-04-12}	{2012-04-11,2012-04-12,2012-04-11,2012-04-12}
1412	12	25	{2012-04-21,2012-04-21,2012-04-22,2012-04-22}	{2012-04-21,2012-04-22,2012-04-21,2012-04-22}
1413	13	25	{2012-05-01,2012-05-01,2012-05-02,2012-05-02}	{2012-05-01,2012-05-02,2012-05-01,2012-05-02}
1414	14	25	{2012-05-11,2012-05-11,2012-05-12,2012-05-12}	{2012-05-11,2012-05-12,2012-05-11,2012-05-12}
1415	15	25	{2012-05-21,2012-05-21,2012-05-22,2012-05-22}	{2012-05-21,2012-05-22,2012-05-21,2012-05-22}
1416	16	25	{2012-06-01,2012-06-01,2012-06-02,2012-06-02}	{2012-06-01,2012-06-02,2012-06-01,2012-06-02}
1417	17	25	{2012-06-11,2012-06-11,2012-06-12,2012-06-12}	{2012-06-11,2012-06-12,2012-06-11,2012-06-12}
1418	18	25	{2012-06-21,2012-06-21,2012-06-22,2012-06-22}	{2012-06-21,2012-06-22,2012-06-21,2012-06-22}
1419	19	25	{2012-07-01,2012-07-01,2012-07-02,2012-07-02}	{2012-07-01,2012-07-02,2012-07-01,2012-07-02}
1420	20	25	{2012-07-11,2012-07-11,2012-07-12,2012-07-12}	{2012-07-11,2012-07-12,2012-07-11,2012-07-12}
1421	21	25	{2012-07-21,2012-07-21,2012-07-22,2012-07-22}	{2012-07-21,2012-07-22,2012-07-21,2012-07-22}
1422	22	25	{2012-08-01,2012-08-01,2012-08-02,2012-08-02}	{2012-08-01,2012-08-02,2012-08-01,2012-08-02}
1423	23	25	{2012-08-11,2012-08-11,2012-08-12,2012-08-12}	{2012-08-11,2012-08-12,2012-08-11,2012-08-12}
1424	24	25	{2012-08-21,2012-08-21,2012-08-22,2012-08-22}	{2012-08-21,2012-08-22,2012-08-21,2012-08-22}
1425	25	25	{2012-09-01,2012-09-01,2012-09-02,2012-09-02}	{2012-09-01,2012-09-02,2012-09-01,2012-09-02}
1426	26	25	{2012-09-11,2012-09-11,2012-09-12,2012-09-12}	{2012-09-11,2012-09-12,2012-09-11,2012-09-12}
1427	27	25	{2012-09-21,2012-09-21,2012-09-22,2012-09-22}	{2012-09-21,2012-09-22,2012-09-21,2012-09-22}
1428	28	25	{2012-10-01,2012-10-01,2012-10-02,2012-10-02}	{2012-10-01,2012-10-02,2012-10-01,2012-10-02}
1429	29	25	{2012-10-11,2012-10-11,2012-10-12,2012-10-12}	{2012-10-11,2012-10-12,2012-10-11,2012-10-12}
1430	30	25	{2012-10-21,2012-10-21,2012-10-22,2012-10-22}	{2012-10-21,2012-10-22,2012-10-21,2012-10-22}
1501	1	26	{2012-01-01,2012-01-01,2012-01-02,2012-01-02}	{2012-01-01,2012-01-02,2012-01-01,2012-01-02}
1502	2	26	{2012-01-11,2012-01-11,2012-01-12,2012-01-12}	{2012-01-11,2012-01-12,2012-01-11,2012-01-12}
1503	3	26	{2012-01-21,2012-01-21,2012-01-22,2012-01-22}	{2012-01-21,2012-01-22,2012-01-21,2012-01-22}
1504	4	26	{2012-02-01,2012-02-01,2012-02-02,2012-02-02}	{2012-02-01,2012-02-02,2012-02-01,2012-02-02}
1505	5	26	{2012-02-11,2012-02-11,2012-02-12,2012-02-12}	{2012-02-11,2012-02-12,2012-02-11,2012-02-12}
1506	6	26	{2012-02-21,2012-02-21,2012-02-22,2012-02-22}	{2012-02-21,2012-02-22,2012-02-21,2012-02-22}
1507	7	26	{2012-03-01,2012-03-01,2012-03-02,2012-03-02}	{2012-03-01,2012-03-02,2012-03-01,2012-03-02}
1508	8	26	{2012-03-11,2012-03-11,2012-03-12,2012-03-12}	{2012-03-11,2012-03-12,2012-03-11,2012-03-12}
1509	9	26	{2012-03-21,2012-03-21,2012-03-22,2012-03-22}	{2012-03-21,2012-03-22,2012-03-21,2012-03-22}
1510	10	26	{2012-04-01,2012-04-01,2012-04-02,2012-04-02}	{2012-04-01,2012-04-02,2012-04-01,2012-04-02}
1511	11	26	{2012-04-11,2012-04-11,2012-04-12,2012-04-12}	{2012-04-11,2012-04-12,2012-04-11,2012-04-12}
1512	12	26	{2012-04-21,2012-04-21,2012-04-22,2012-04-22}	{2012-04-21,2012-04-22,2012-04-21,2012-04-22}
1513	13	26	{2012-05-01,2012-05-01,2012-05-02,2012-05-02}	{2012-05-01,2012-05-02,2012-05-01,2012-05-02}
1514	14	26	{2012-05-11,2012-05-11,2012-05-12,2012-05-12}	{2012-05-11,2012-05-12,2012-05-11,2012-05-12}
1515	15	26	{2012-05-21,2012-05-21,2012-05-22,2012-05-22}	{2012-05-21,2012-05-22,2012-05-21,2012-05-22}
1516	16	26	{2012-06-01,2012-06-01,2012-06-02,2012-06-02}	{2012-06-01,2012-06-02,2012-06-01,2012-06-02}
1517	17	26	{2012-06-11,2012-06-11,2012-06-12,2012-06-12}	{2012-06-11,2012-06-12,2012-06-11,2012-06-12}
1518	18	26	{2012-06-21,2012-06-21,2012-06-22,2012-06-22}	{2012-06-21,2012-06-22,2012-06-21,2012-06-22}
1519	19	26	{2012-07-01,2012-07-01,2012-07-02,2012-07-02}	{2012-07-01,2012-07-02,2012-07-01,2012-07-02}
1520	20	26	{2012-07-11,2012-07-11,2012-07-12,2012-07-12}	{2012-07-11,2012-07-12,2012-07-11,2012-07-12}
1521	21	26	{2012-07-21,2012-07-21,2012-07-22,2012-07-22}	{2012-07-21,2012-07-22,2012-07-21,2012-07-22}
1522	22	26	{2012-08-01,2012-08-01,2012-08-02,2012-08-02}	{2012-08-01,2012-08-02,2012-08-01,2012-08-02}
1523	23	26	{2012-08-11,2012-08-11,2012-08-12,2012-08-12}	{2012-08-11,2012-08-12,2012-08-11,2012-08-12}
1524	24	26	{2012-08-21,2012-08-21,2012-08-22,2012-08-22}	{2012-08-21,2012-08-22,2012-08-21,2012-08-22}
1525	25	26	{2012-09-01,2012-09-01,2012-09-02,2012-09-02}	{2012-09-01,2012-09-02,2012-09-01,2012-09-02}
1526	26	26	{2012-09-11,2012-09-11,2012-09-12,2012-09-12}	{2012-09-11,2012-09-12,2012-09-11,2012-09-12}
1527	27	26	{2012-09-21,2012-09-21,2012-09-22,2012-09-22}	{2012-09-21,2012-09-22,2012-09-21,2012-09-22}
1528	28	26	{2012-10-01,2012-10-01,2012-10-02,2012-10-02}	{2012-10-01,2012-10-02,2012-10-01,2012-10-02}
1529	29	26	{2012-10-11,2012-10-11,2012-10-12,2012-10-12}	{2012-10-11,2012-10-12,2012-10-11,2012-10-12}
1530	30	26	{2012-10-21,2012-10-21,2012-10-22,2012-10-22}	{2012-10-21,2012-10-22,2012-10-21,2012-10-22}
1601	1	27	{2012-01-01,2012-01-01,2012-01-02,2012-01-02}	{2012-01-01,2012-01-02,2012-01-01,2012-01-02}
1602	2	27	{2012-01-11,2012-01-11,2012-01-12,2012-01-12}	{2012-01-11,2012-01-12,2012-01-11,2012-01-12}
1603	3	27	{2012-01-21,2012-01-21,2012-01-22,2012-01-22}	{2012-01-21,2012-01-22,2012-01-21,2012-01-22}
1604	4	27	{2012-02-01,2012-02-01,2012-02-02,2012-02-02}	{2012-02-01,2012-02-02,2012-02-01,2012-02-02}
1605	5	27	{2012-02-11,2012-02-11,2012-02-12,2012-02-12}	{2012-02-11,2012-02-12,2012-02-11,2012-02-12}
1606	6	27	{2012-02-21,2012-02-21,2012-02-22,2012-02-22}	{2012-02-21,2012-02-22,2012-02-21,2012-02-22}
1607	7	27	{2012-03-01,2012-03-01,2012-03-02,2012-03-02}	{2012-03-01,2012-03-02,2012-03-01,2012-03-02}
1608	8	27	{2012-03-11,2012-03-11,2012-03-12,2012-03-12}	{2012-03-11,2012-03-12,2012-03-11,2012-03-12}
1609	9	27	{2012-03-21,2012-03-21,2012-03-22,2012-03-22}	{2012-03-21,2012-03-22,2012-03-21,2012-03-22}
1610	10	27	{2012-04-01,2012-04-01,2012-04-02,2012-04-02}	{2012-04-01,2012-04-02,2012-04-01,2012-04-02}
1611	11	27	{2012-04-11,2012-04-11,2012-04-12,2012-04-12}	{2012-04-11,2012-04-12,2012-04-11,2012-04-12}
1612	12	27	{2012-04-21,2012-04-21,2012-04-22,2012-04-22}	{2012-04-21,2012-04-22,2012-04-21,2012-04-22}
1613	13	27	{2012-05-01,2012-05-01,2012-05-02,2012-05-02}	{2012-05-01,2012-05-02,2012-05-01,2012-05-02}
1614	14	27	{2012-05-11,2012-05-11,2012-05-12,2012-05-12}	{2012-05-11,2012-05-12,2012-05-11,2012-05-12}
1615	15	27	{2012-05-21,2012-05-21,2012-05-22,2012-05-22}	{2012-05-21,2012-05-22,2012-05-21,2012-05-22}
1616	16	27	{2012-06-01,2012-06-01,2012-06-02,2012-06-02}	{2012-06-01,2012-06-02,2012-06-01,2012-06-02}
1617	17	27	{2012-06-11,2012-06-11,2012-06-12,2012-06-12}	{2012-06-11,2012-06-12,2012-06-11,2012-06-12}
1618	18	27	{2012-06-21,2012-06-21,2012-06-22,2012-06-22}	{2012-06-21,2012-06-22,2012-06-21,2012-06-22}
1619	19	27	{2012-07-01,2012-07-01,2012-07-02,2012-07-02}	{2012-07-01,2012-07-02,2012-07-01,2012-07-02}
1620	20	27	{2012-07-11,2012-07-11,2012-07-12,2012-07-12}	{2012-07-11,2012-07-12,2012-07-11,2012-07-12}
1621	21	27	{2012-07-21,2012-07-21,2012-07-22,2012-07-22}	{2012-07-21,2012-07-22,2012-07-21,2012-07-22}
1622	22	27	{2012-08-01,2012-08-01,2012-08-02,2012-08-02}	{2012-08-01,2012-08-02,2012-08-01,2012-08-02}
1623	23	27	{2012-08-11,2012-08-11,2012-08-12,2012-08-12}	{2012-08-11,2012-08-12,2012-08-11,2012-08-12}
1624	24	27	{2012-08-21,2012-08-21,2012-08-22,2012-08-22}	{2012-08-21,2012-08-22,2012-08-21,2012-08-22}
1625	25	27	{2012-09-01,2012-09-01,2012-09-02,2012-09-02}	{2012-09-01,2012-09-02,2012-09-01,2012-09-02}
1626	26	27	{2012-09-11,2012-09-11,2012-09-12,2012-09-12}	{2012-09-11,2012-09-12,2012-09-11,2012-09-12}
1627	27	27	{2012-09-21,2012-09-21,2012-09-22,2012-09-22}	{2012-09-21,2012-09-22,2012-09-21,2012-09-22}
1628	28	27	{2012-10-01,2012-10-01,2012-10-02,2012-10-02}	{2012-10-01,2012-10-02,2012-10-01,2012-10-02}
1629	29	27	{2012-10-11,2012-10-11,2012-10-12,2012-10-12}	{2012-10-11,2012-10-12,2012-10-11,2012-10-12}
1630	30	27	{2012-10-21,2012-10-21,2012-10-22,2012-10-22}	{2012-10-21,2012-10-22,2012-10-21,2012-10-22}
1701	1	28	{2012-01-01,2012-01-01,2012-01-02,2012-01-02}	{2012-01-01,2012-01-02,2012-01-01,2012-01-02}
1702	2	28	{2012-01-11,2012-01-11,2012-01-12,2012-01-12}	{2012-01-11,2012-01-12,2012-01-11,2012-01-12}
1703	3	28	{2012-01-21,2012-01-21,2012-01-22,2012-01-22}	{2012-01-21,2012-01-22,2012-01-21,2012-01-22}
1704	4	28	{2012-02-01,2012-02-01,2012-02-02,2012-02-02}	{2012-02-01,2012-02-02,2012-02-01,2012-02-02}
1705	5	28	{2012-02-11,2012-02-11,2012-02-12,2012-02-12}	{2012-02-11,2012-02-12,2012-02-11,2012-02-12}
1706	6	28	{2012-02-21,2012-02-21,2012-02-22,2012-02-22}	{2012-02-21,2012-02-22,2012-02-21,2012-02-22}
1707	7	28	{2012-03-01,2012-03-01,2012-03-02,2012-03-02}	{2012-03-01,2012-03-02,2012-03-01,2012-03-02}
1708	8	28	{2012-03-11,2012-03-11,2012-03-12,2012-03-12}	{2012-03-11,2012-03-12,2012-03-11,2012-03-12}
1709	9	28	{2012-03-21,2012-03-21,2012-03-22,2012-03-22}	{2012-03-21,2012-03-22,2012-03-21,2012-03-22}
1710	10	28	{2012-04-01,2012-04-01,2012-04-02,2012-04-02}	{2012-04-01,2012-04-02,2012-04-01,2012-04-02}
1711	11	28	{2012-04-11,2012-04-11,2012-04-12,2012-04-12}	{2012-04-11,2012-04-12,2012-04-11,2012-04-12}
1712	12	28	{2012-04-21,2012-04-21,2012-04-22,2012-04-22}	{2012-04-21,2012-04-22,2012-04-21,2012-04-22}
1713	13	28	{2012-05-01,2012-05-01,2012-05-02,2012-05-02}	{2012-05-01,2012-05-02,2012-05-01,2012-05-02}
1714	14	28	{2012-05-11,2012-05-11,2012-05-12,2012-05-12}	{2012-05-11,2012-05-12,2012-05-11,2012-05-12}
1715	15	28	{2012-05-21,2012-05-21,2012-05-22,2012-05-22}	{2012-05-21,2012-05-22,2012-05-21,2012-05-22}
1716	16	28	{2012-06-01,2012-06-01,2012-06-02,2012-06-02}	{2012-06-01,2012-06-02,2012-06-01,2012-06-02}
1717	17	28	{2012-06-11,2012-06-11,2012-06-12,2012-06-12}	{2012-06-11,2012-06-12,2012-06-11,2012-06-12}
1718	18	28	{2012-06-21,2012-06-21,2012-06-22,2012-06-22}	{2012-06-21,2012-06-22,2012-06-21,2012-06-22}
1719	19	28	{2012-07-01,2012-07-01,2012-07-02,2012-07-02}	{2012-07-01,2012-07-02,2012-07-01,2012-07-02}
1720	20	28	{2012-07-11,2012-07-11,2012-07-12,2012-07-12}	{2012-07-11,2012-07-12,2012-07-11,2012-07-12}
1721	21	28	{2012-07-21,2012-07-21,2012-07-22,2012-07-22}	{2012-07-21,2012-07-22,2012-07-21,2012-07-22}
1722	22	28	{2012-08-01,2012-08-01,2012-08-02,2012-08-02}	{2012-08-01,2012-08-02,2012-08-01,2012-08-02}
1723	23	28	{2012-08-11,2012-08-11,2012-08-12,2012-08-12}	{2012-08-11,2012-08-12,2012-08-11,2012-08-12}
1724	24	28	{2012-08-21,2012-08-21,2012-08-22,2012-08-22}	{2012-08-21,2012-08-22,2012-08-21,2012-08-22}
1725	25	28	{2012-09-01,2012-09-01,2012-09-02,2012-09-02}	{2012-09-01,2012-09-02,2012-09-01,2012-09-02}
1726	26	28	{2012-09-11,2012-09-11,2012-09-12,2012-09-12}	{2012-09-11,2012-09-12,2012-09-11,2012-09-12}
1727	27	28	{2012-09-21,2012-09-21,2012-09-22,2012-09-22}	{2012-09-21,2012-09-22,2012-09-21,2012-09-22}
1728	28	28	{2012-10-01,2012-10-01,2012-10-02,2012-10-02}	{2012-10-01,2012-10-02,2012-10-01,2012-10-02}
1729	29	28	{2012-10-11,2012-10-11,2012-10-12,2012-10-12}	{2012-10-11,2012-10-12,2012-10-11,2012-10-12}
1730	30	28	{2012-10-21,2012-10-21,2012-10-22,2012-10-22}	{2012-10-21,2012-10-22,2012-10-21,2012-10-22}
1901	1	29	{2012-01-01,2012-01-01,2012-01-02,2012-01-02}	{2012-01-01,2012-01-02,2012-01-01,2012-01-02}
1902	2	29	{2012-01-11,2012-01-11,2012-01-12,2012-01-12}	{2012-01-11,2012-01-12,2012-01-11,2012-01-12}
1903	3	29	{2012-01-21,2012-01-21,2012-01-22,2012-01-22}	{2012-01-21,2012-01-22,2012-01-21,2012-01-22}
1904	4	29	{2012-02-01,2012-02-01,2012-02-02,2012-02-02}	{2012-02-01,2012-02-02,2012-02-01,2012-02-02}
1905	5	29	{2012-02-11,2012-02-11,2012-02-12,2012-02-12}	{2012-02-11,2012-02-12,2012-02-11,2012-02-12}
1906	6	29	{2012-02-21,2012-02-21,2012-02-22,2012-02-22}	{2012-02-21,2012-02-22,2012-02-21,2012-02-22}
1907	7	29	{2012-03-01,2012-03-01,2012-03-02,2012-03-02}	{2012-03-01,2012-03-02,2012-03-01,2012-03-02}
1908	8	29	{2012-03-11,2012-03-11,2012-03-12,2012-03-12}	{2012-03-11,2012-03-12,2012-03-11,2012-03-12}
1909	9	29	{2012-03-21,2012-03-21,2012-03-22,2012-03-22}	{2012-03-21,2012-03-22,2012-03-21,2012-03-22}
1910	10	29	{2012-04-01,2012-04-01,2012-04-02,2012-04-02}	{2012-04-01,2012-04-02,2012-04-01,2012-04-02}
1911	11	29	{2012-04-11,2012-04-11,2012-04-12,2012-04-12}	{2012-04-11,2012-04-12,2012-04-11,2012-04-12}
1912	12	29	{2012-04-21,2012-04-21,2012-04-22,2012-04-22}	{2012-04-21,2012-04-22,2012-04-21,2012-04-22}
1913	13	29	{2012-05-01,2012-05-01,2012-05-02,2012-05-02}	{2012-05-01,2012-05-02,2012-05-01,2012-05-02}
1914	14	29	{2012-05-11,2012-05-11,2012-05-12,2012-05-12}	{2012-05-11,2012-05-12,2012-05-11,2012-05-12}
1915	15	29	{2012-05-21,2012-05-21,2012-05-22,2012-05-22}	{2012-05-21,2012-05-22,2012-05-21,2012-05-22}
1916	16	19	{2012-06-01,2012-06-01,2012-06-02,2012-06-02}	{2012-06-01,2012-06-02,2012-06-01,2012-06-02}
1917	17	19	{2012-06-11,2012-06-11,2012-06-12,2012-06-12}	{2012-06-11,2012-06-12,2012-06-11,2012-06-12}
1918	18	19	{2012-06-21,2012-06-21,2012-06-22,2012-06-22}	{2012-06-21,2012-06-22,2012-06-21,2012-06-22}
1919	19	19	{2012-07-01,2012-07-01,2012-07-02,2012-07-02}	{2012-07-01,2012-07-02,2012-07-01,2012-07-02}
1920	20	19	{2012-07-11,2012-07-11,2012-07-12,2012-07-12}	{2012-07-11,2012-07-12,2012-07-11,2012-07-12}
1921	21	29	{2012-07-21,2012-07-21,2012-07-22,2012-07-22}	{2012-07-21,2012-07-22,2012-07-21,2012-07-22}
1922	22	29	{2012-08-01,2012-08-01,2012-08-02,2012-08-02}	{2012-08-01,2012-08-02,2012-08-01,2012-08-02}
1923	23	29	{2012-08-11,2012-08-11,2012-08-12,2012-08-12}	{2012-08-11,2012-08-12,2012-08-11,2012-08-12}
1924	24	29	{2012-08-21,2012-08-21,2012-08-22,2012-08-22}	{2012-08-21,2012-08-22,2012-08-21,2012-08-22}
1925	25	29	{2012-09-01,2012-09-01,2012-09-02,2012-09-02}	{2012-09-01,2012-09-02,2012-09-01,2012-09-02}
1926	26	29	{2012-09-11,2012-09-11,2012-09-12,2012-09-12}	{2012-09-11,2012-09-12,2012-09-11,2012-09-12}
1927	27	29	{2012-09-21,2012-09-21,2012-09-22,2012-09-22}	{2012-09-21,2012-09-22,2012-09-21,2012-09-22}
1928	28	29	{2012-10-01,2012-10-01,2012-10-02,2012-10-02}	{2012-10-01,2012-10-02,2012-10-01,2012-10-02}
1929	29	29	{2012-10-11,2012-10-11,2012-10-12,2012-10-12}	{2012-10-11,2012-10-12,2012-10-11,2012-10-12}
1930	30	29	{2012-10-21,2012-10-21,2012-10-22,2012-10-22}	{2012-10-21,2012-10-22,2012-10-21,2012-10-22}
501	1	6	{2013-01-01,2013-01-01,2013-01-02,2013-01-02,2013-12-14,2013-12-14,0001-01-01,0001-01-01}	{2013-01-01,2013-01-02,2013-01-01,2013-01-02,2013-12-14,2013-12-15,2013-12-14,2013-12-15}
\.


--
-- Name: records_record_id_seq; Type: SEQUENCE SET; Schema: public; Owner: anna
--

SELECT pg_catalog.setval('records_record_id_seq', 46, true);


--
-- Name: auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions_group_id_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_key UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_permission_content_type_id_codename_key; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_key UNIQUE (content_type_id, codename);


--
-- Name: auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups_user_id_group_id_key; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_group_id_key UNIQUE (user_id, group_id);


--
-- Name: auth_user_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_user
    ADD CONSTRAINT auth_user_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions_user_id_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_permission_id_key UNIQUE (user_id, permission_id);


--
-- Name: auth_user_username_key; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY auth_user
    ADD CONSTRAINT auth_user_username_key UNIQUE (username);


--
-- Name: dbarray_chars_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY dbarray_chars
    ADD CONSTRAINT dbarray_chars_pkey PRIMARY KEY (id);


--
-- Name: dbarray_dates_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY dbarray_dates
    ADD CONSTRAINT dbarray_dates_pkey PRIMARY KEY (id);


--
-- Name: dbarray_floats_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY dbarray_floats
    ADD CONSTRAINT dbarray_floats_pkey PRIMARY KEY (id);


--
-- Name: dbarray_integers_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY dbarray_integers
    ADD CONSTRAINT dbarray_integers_pkey PRIMARY KEY (id);


--
-- Name: dbarray_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY dbarray_texts
    ADD CONSTRAINT dbarray_texts_pkey PRIMARY KEY (id);


--
-- Name: django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- Name: django_content_type_app_label_model_key; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_key UNIQUE (app_label, model);


--
-- Name: django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- Name: django_site_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY django_site
    ADD CONSTRAINT django_site_pkey PRIMARY KEY (id);


--
-- Name: items_item_name_model_key; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY items_item
    ADD CONSTRAINT items_item_name_model_key UNIQUE (name, model);


--
-- Name: items_item_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY items_item
    ADD CONSTRAINT items_item_pkey PRIMARY KEY (id);


--
-- Name: occupations_occupation_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY occupations_occupation
    ADD CONSTRAINT occupations_occupation_pkey PRIMARY KEY (id);


--
-- Name: positions_position_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY positions_position
    ADD CONSTRAINT positions_position_pkey PRIMARY KEY (id);


--
-- Name: records_record_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY records_record
    ADD CONSTRAINT records_record_pkey PRIMARY KEY (id);


--
-- Name: duration_idx; Type: INDEX; Schema: public; Owner: anna; Tablespace: 
--

CREATE INDEX duration_idx ON occupations_occupation USING gist (daterange(vs, ve));


--
-- Name: transaction_idx; Type: INDEX; Schema: public; Owner: anna; Tablespace: 
--

CREATE INDEX transaction_idx ON records_record USING gin (tt);


--
-- Name: valid_idx; Type: INDEX; Schema: public; Owner: anna; Tablespace: 
--

CREATE INDEX valid_idx ON records_record USING gin (vt);


--
-- Name: auth_group_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_group_id_fkey FOREIGN KEY (group_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_type_id_refs_id_d043b34a; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT content_type_id_refs_id_d043b34a FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log_content_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_fkey FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: group_id_refs_id_f4b32aac; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT group_id_refs_id_f4b32aac FOREIGN KEY (group_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: item_id_refs_id_67d4d416; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY records_record
    ADD CONSTRAINT item_id_refs_id_67d4d416 FOREIGN KEY (item_id) REFERENCES items_item(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: occupations_occupation_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY occupations_occupation
    ADD CONSTRAINT occupations_occupation_position_id_fkey FOREIGN KEY (position_id) REFERENCES positions_position(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: occupations_occupation_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY occupations_occupation
    ADD CONSTRAINT occupations_occupation_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: records_record_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY records_record
    ADD CONSTRAINT records_record_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_id_refs_id_40c41112; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT user_id_refs_id_40c41112 FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_id_refs_id_4dc23c39; Type: FK CONSTRAINT; Schema: public; Owner: anna
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT user_id_refs_id_4dc23c39 FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

