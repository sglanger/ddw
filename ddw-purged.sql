--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: ddw; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE ddw WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'English_United States.1252' LC_CTYPE = 'English_United States.1252';


ALTER DATABASE ddw OWNER TO postgres;

\connect ddw

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: ddw; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE ddw IS 'DICOM Data Warehouse

Steve Langer 2011

A general purpose DICOM dbase for research use and subsequent data mining. No warrenty is expressed or implied

External Dependencies:
 The DDW mirth channel';


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
-- Name: dispatcher(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dispatcher(OUT status text) RETURNS text
    LANGUAGE plpgsql
    AS $$DECLARE
--------------------------------------
-- Purpose: run by Parient table trigger, looks at 
--	table exams_to_process and then
--	a) mapps an exam to an analytic algorithm for processing
--	b) verfies analytic runs
--	c) on success removes exam from exams_to_process table
-- Caller: trigger on Patient table
---------------------------------------
-- Note
-- Functions that don't return a result set MUST NOT define a out parameter
-- just use "return value;"
	func text;
	result exams_to_process%ROWTYPE;
	id text ;
	gid integer ;
	now timestamp without time zone := now() ;
BEGIN
	func :='ddw:dispatcher';
	-- clear log for each run
	delete from log *;
	
	for result in select * from exams_to_process LOOP
		if current_date - cast(result.last_touched as date) > 0 then 
			-- first find out what the SWare versionID is for this series
			select into id version_id from series where series.exam_uid = result.exam_uid ;
			-- Next find out what group this Sware version maps to
			select into gid group_id from known_scanners where known_scanners.version_id = cast (id as integer)  ;

			-- Now we know what algorithm to invoke, pass it the study_uid
			if gid = 1 then
				-- GE MR
				perform logger (func, 'in GE MR');
				SELECT into status one(result.exam_uid);
			elseif gid = 2 then
				-- Siemens CT
				--Select into status two(result.exam_uid);
			elseif gid = 3 then
				-- Fuji CR
				--Select into status three(result.exam_uid);
			elseif gid = 4 then
				-- GE DR
				--Select into status four(result.exam_uid);
			elseif gid = 5 then
				-- Philips CR
				--Select into status five(result.exam_uid);
			elseif gid = 10 then
				-- Siemens MR
				perform logger (func, 'in Siemens MR');
				Select into status ten(result.exam_uid);
			else
				perform logger (func, 'unknown GID');
			end if;

			-- check here if status is OK
			-- And last remove the entry now that it's been analyzed
			--perform logger (func, status);
			if status = 'ok' then
				--perform logger (func, 'in OK');
				DELETE from exams_to_process * where exam_uid = result.exam_uid ;
			else
				-- something must have broke
				-- should raise an alert
				perform logger (func, 'failed on '|| result.exam_uid);
			end if;
		end if;
	end LOOP;

	return ;
END
$$;


ALTER FUNCTION public.dispatcher(OUT status text) OWNER TO postgres;

--
-- Name: logger(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION logger(caller text, message text) RETURNS text
    LANGUAGE plpgsql
    AS $$declare
--------------------------------------
-- Purpose: General purpose logging for debug
-- Caller: any stored procedure
------------------------------------------
	func text;
	status text;
	
begin
	func :='ddw:logger';
	insert into log values (caller, message, now()) ;
	return 'ok';
end
$$;


ALTER FUNCTION public.logger(caller text, message text) OWNER TO postgres;

--
-- Name: one(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION one(study_uid text) RETURNS text
    LANGUAGE plpgsql
    AS $$declare
------------------------------------------
-- Purpose: GE MR header processor
-- 	Right now this is a stub call to trim
--	entries from the "exams-to-process" table
-- Caller: Dispatcher
-----------------------------------------
	func text;
	status text;

begin
	func :='ddw:one';
	status :='ok';

	--perform logger (func, status);
	return status;
end
$$;


ALTER FUNCTION public.one(study_uid text) OWNER TO postgres;

--
-- Name: purge_phi(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION purge_phi(OUT success text) RETURNS text
    LANGUAGE plpgsql
    AS $$DECLARE
--------------------------------------
-- Purpose: purge all PHI
-- Caller: external or User
-------------------------------------------
	--local vars
	func text;
BEGIN
	func := 'ddw:purge_phi' ;

	-- assume it fails, change later if succeed
	success := 'false';
	-- use PERFORM instead of SELECT since we are throwing away the result
	PERFORM purger ('', 'test');
	perform purger ('', 'nuke-it');
	
	--perform purger ('', 'alerts');
	--PERFORM purger ('', 'patient');	
	--pERFORM purger ('', 'exam');
	--PERFORM purger ('', 'series');
	--PERFORM purger ('', 'acquisition');
	--pERFORM purger ('', 'instance');
	
	-- if we got all the way here we succeeded
	success := 'true';
	return ;
END
$$;


ALTER FUNCTION public.purge_phi(OUT success text) OWNER TO postgres;

--
-- Name: purger(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION purger(uid text, scope text) RETURNS text
    LANGUAGE plpgsql
    AS $$declare
----------------------------------------
-- Purpose: replace 5 different function with 
-- 	this one
-- Caller: purge_phi
----------------------------------------------
	func text;
	status text;
	template text;
begin
	func :='ddw:purger';
	status := 'error';

	if uid = '' then 
		-- wipe everything in the table
		template :='%';
	else
		-- surgically clean the table (ie for exams over 1 yr old)
		template :=uid;
	end if;

	if scope = 'patient' then
		DELETE FROM patient * where patient.mpi_pat_id LIKE template ;
		status := 'ok';
	elseif scope = 'alerts' then
		DELETE FROM alerts * where alerts.exam_uid LIKE  template;
		DELETE FROM exams_to_process * where exams_to_process.exam_uid LIKE  template ;
		status := 'ok';
	elseif scope = 'exam' then
		DELETE FROM exams_derived_values * where exams_derived_values.exam_uid LIKE  template ;
		DELETE FROM exams_mapped_values * where exams_mapped_values.exam_uid LIKE  template ;
		DELETE FROM exams * where exams.exam_uid LIKE template  ;
		status := 'ok';
	elseif scope = 'series' then
		DELETE FROM series_derived_values * where series_derived_values.series_uid LIKE template ;
		DELETE FROM series_mapped_values * where series_mapped_values.series_uid LIKE template ;
		DELETE FROM series * where series.series_uid LIKE template  ;
		status := 'ok';
	elseif scope = 'acquisition' then
		DELETE FROM acquisition_derived_values * where acquisition_derived_values.event_uid LIKE template ;
		DELETE FROM acquisition_mapped_values * where acquisition_mapped_values.event_uid LIKE template  ;
		DELETE FROM acquisition * where acquisition.event_uid LIKE template  ;
		status := 'ok';
	elseif scope = 'instance' then
		DELETE FROM instance_derived_values * where instance_derived_values.instance_uid LIKE template ;
		DELETE FROM instance_binary_object  * where instance_binary_object.instance_uid LIKE template ; 
		DELETE FROM instance_mapped_values  * where instance_mapped_values.instance_uid LIKE template ;
		DELETE FROM instance  * where instance.instance_uid LIKE template;
		status := 'ok';
	elseif scope = 'test' then
		perform logger (func, 'test');
		status := 'ok';
	elseif scope = 'nuke-it' then
		-- destroy all PHI\
		truncate patient ;
		truncate alerts, exams_to_process ;
		truncate exams_derived_values, exams_mapped_values, exams ;
		truncate series_derived_values, series_mapped_values, series ;
		truncate acquisition_derived_values, acquisition_mapped_values, acquisition; 
		truncate instance_derived_values, instance_mapped_values, instance ;
		status := 'ok';
	end if;

	--perform logger (func, status);
	return status;
end
$$;


ALTER FUNCTION public.purger(uid text, scope text) OWNER TO postgres;

--
-- Name: run_dispatcher(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION run_dispatcher() RETURNS trigger
    LANGUAGE plpgsql
    AS $$begin
 -- example
 -- http://www.postgresql.org/docs/8.1/static/plpgsql-trigger.html
  perform dispatcher();
  return NULL;
end
$$;


ALTER FUNCTION public.run_dispatcher() OWNER TO postgres;

--
-- Name: ten(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ten(study_uid text) RETURNS text
    LANGUAGE plpgsql
    AS $_$declare
------------------------------------------
-- Purpose: Siemens MR header processor
-- 	In particular, the Siemens MR Shadow 1029
--	which contains PulseSeq, PatientWeight, etc
-- Caller: Dispatcher
-----------------------------------------
	func text;
	status text;
	result series%ROWTYPE;
	res2 series_mapped_values%ROWTYPE;
	value text;
begin
	func :='ddw:ten';
	status :='fail';
	--perform logger (func, 'entering 10. examUID = ' || $1);
	
	-- find all series_uid matching exam_uid 
	-- then Qry the series_mapped_table for 
	-- "siemens_MR_shadow" and parse out the PulseSeq
	for result in select * from  series where series.exam_uid = $1 LOOP 
		for res2 in select * from series_mapped_values where series_mapped_values.series_uid = result.series_uid LOOP
			-- now parse the tags of interest in series_mapped_values
			-- where series_uids have the parent exam_uid
			if res2.std_name = 'siemens_MR_shadow' then
				-- parse res2.value for CustomerSeq%\\
				value = substr (res2.value, strpos(res2.value,'Seq%\\') + 4, 20);
				value = split_part (value, '""', 1);
				--perform logger (func, value); 
				--  then update the series_derived values
				insert into series_mapped_values values (result.series_uid, 'pulse_seq', value, 'text');
				status :='ok';
			else
				perform logger (func, 'std name = ' || res2.std_name); 
			end if;
		end LOOP;
	end LOOP;

	return status;
end$_$;


ALTER FUNCTION public.ten(study_uid text) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = true;

--
-- Name: acquisition; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE acquisition (
    acq_time text,
    acq_number text,
    sop_class text NOT NULL,
    exam_uid text NOT NULL,
    series_uid text NOT NULL,
    event_uid text NOT NULL
);


ALTER TABLE public.acquisition OWNER TO postgres;

--
-- Name: acquisition_derived_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE acquisition_derived_values (
    event_uid text NOT NULL,
    std_name text NOT NULL,
    value text NOT NULL,
    unit text NOT NULL,
    algorithm text
);


ALTER TABLE public.acquisition_derived_values OWNER TO postgres;

--
-- Name: acquisition_mapped_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE acquisition_mapped_values (
    event_uid text NOT NULL,
    std_name text NOT NULL,
    value text NOT NULL,
    unit text NOT NULL
);


ALTER TABLE public.acquisition_mapped_values OWNER TO postgres;

--
-- Name: acquisition_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW acquisition_view AS
    SELECT acquisition_mapped_values.event_uid, acquisition_mapped_values.std_name, acquisition_mapped_values.value, acquisition_mapped_values.unit FROM acquisition_mapped_values UNION SELECT acquisition_derived_values.event_uid, acquisition_derived_values.std_name, acquisition_derived_values.value, acquisition_derived_values.unit FROM acquisition_derived_values ORDER BY 1;


ALTER TABLE public.acquisition_view OWNER TO postgres;

--
-- Name: alerts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alerts (
    exam_uid text NOT NULL,
    mpi_pat_id text,
    alert_type text NOT NULL,
    closed_status boolean DEFAULT false NOT NULL,
    date_open text NOT NULL,
    date_close text,
    message text NOT NULL
);


ALTER TABLE public.alerts OWNER TO postgres;

--
-- Name: derived_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE derived_values (
    version_id bigint NOT NULL,
    std_name text NOT NULL
);


ALTER TABLE public.derived_values OWNER TO postgres;

--
-- Name: dict_std_names; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dict_std_names (
    std_name text,
    unit text NOT NULL,
    scope text NOT NULL
);


ALTER TABLE public.dict_std_names OWNER TO postgres;

--
-- Name: derived_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW derived_view AS
    SELECT dict_std_names.std_name, dict_std_names.unit, dict_std_names.scope, derived_values.version_id FROM derived_values, dict_std_names WHERE (derived_values.std_name = dict_std_names.std_name) ORDER BY derived_values.version_id;


ALTER TABLE public.derived_view OWNER TO postgres;

--
-- Name: known_scanners; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE known_scanners (
    modality text NOT NULL,
    make text NOT NULL,
    model text NOT NULL,
    vers text NOT NULL,
    group_id integer,
    version_id integer NOT NULL
);


ALTER TABLE public.known_scanners OWNER TO postgres;

--
-- Name: COLUMN known_scanners.group_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN known_scanners.group_id IS 'This is a short hand way to refer to a class of scanners that all have the same MappedValues even if they are different sware Versions. This would likely be the case -say- for all GE MR. This likely leads to a single algorithm being useful for this Group of scanners';


--
-- Name: derived_scanner_version; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW derived_scanner_version AS
    SELECT derived_view.std_name, derived_view.unit, derived_view.scope, derived_view.version_id, known_scanners.modality, known_scanners.make, known_scanners.model, known_scanners.vers, known_scanners.group_id FROM derived_view, known_scanners WHERE (derived_view.version_id = known_scanners.version_id) ORDER BY known_scanners.group_id, known_scanners.version_id;


ALTER TABLE public.derived_scanner_version OWNER TO postgres;

--
-- Name: dict_alert_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dict_alert_types (
    alert_type text NOT NULL,
    scope text,
    criticality text NOT NULL,
    email_to_address text NOT NULL,
    email_title text,
    email_from_address text
);


ALTER TABLE public.dict_alert_types OWNER TO postgres;

--
-- Name: exams_derived_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE exams_derived_values (
    exam_uid text NOT NULL,
    std_name text NOT NULL,
    value text NOT NULL,
    unit text NOT NULL,
    algorithm text
);


ALTER TABLE public.exams_derived_values OWNER TO postgres;

--
-- Name: TABLE exams_derived_values; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE exams_derived_values IS 'This is for exam level data that has to be calculated. The data sources would often come from teh examsMappedValues table, and the algorithm used would be a stored procedure, listed in dictAlgorithms ';


--
-- Name: exams_mapped_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE exams_mapped_values (
    exam_uid text NOT NULL,
    std_name text NOT NULL,
    value text NOT NULL,
    unit text NOT NULL
);


ALTER TABLE public.exams_mapped_values OWNER TO postgres;

--
-- Name: exam_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW exam_view AS
    SELECT exams_mapped_values.exam_uid, exams_mapped_values.std_name, exams_mapped_values.value, exams_mapped_values.unit FROM exams_mapped_values UNION SELECT exams_derived_values.exam_uid, exams_derived_values.std_name, exams_derived_values.value, exams_derived_values.unit FROM exams_derived_values ORDER BY 1;


ALTER TABLE public.exam_view OWNER TO postgres;

--
-- Name: exams; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE exams (
    mpi_pat_id text NOT NULL,
    exam_uid text NOT NULL,
    accession text NOT NULL,
    date_of_exam text NOT NULL,
    time_of_exam text,
    refer_doc text,
    exam_descrip text,
    exam_code text,
    campus text,
    operator text,
    triggers_check text,
    radiologist text
);


ALTER TABLE public.exams OWNER TO postgres;

--
-- Name: TABLE exams; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE exams IS 'Location for Exam level, standard data that is not SOP class specific or custom (shadow) tags';


--
-- Name: exams_to_process; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE exams_to_process (
    exam_uid text NOT NULL,
    last_touched timestamp without time zone DEFAULT now()
);


ALTER TABLE public.exams_to_process OWNER TO postgres;

--
-- Name: instance; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE instance (
    exam_uid text NOT NULL,
    series_uid text NOT NULL,
    instance_uid text NOT NULL,
    content_time text,
    instance_number text,
    image_type text
);


ALTER TABLE public.instance OWNER TO postgres;

--
-- Name: instance_binary_object; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE instance_binary_object (
    instance_uid text NOT NULL,
    date_of_exam text NOT NULL,
    header character varying,
    content bytea
);


ALTER TABLE public.instance_binary_object OWNER TO postgres;

--
-- Name: instance_derived_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE instance_derived_values (
    instance_uid text NOT NULL,
    std_name text NOT NULL,
    value text NOT NULL,
    unit text NOT NULL,
    algorithm text
);


ALTER TABLE public.instance_derived_values OWNER TO postgres;

--
-- Name: instance_mapped_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE instance_mapped_values (
    instance_uid text NOT NULL,
    std_name text NOT NULL,
    value text NOT NULL,
    unit text NOT NULL
);


ALTER TABLE public.instance_mapped_values OWNER TO postgres;

--
-- Name: instance_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW instance_view AS
    SELECT instance_mapped_values.instance_uid, instance_mapped_values.std_name, instance_mapped_values.value, instance_mapped_values.unit FROM instance_mapped_values UNION SELECT instance_derived_values.instance_uid, instance_derived_values.std_name, instance_derived_values.value, instance_derived_values.unit FROM instance_derived_values ORDER BY 1;


ALTER TABLE public.instance_view OWNER TO postgres;

--
-- Name: known_scanners_version_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE known_scanners_version_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.known_scanners_version_id_seq OWNER TO postgres;

--
-- Name: known_scanners_version_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE known_scanners_version_id_seq OWNED BY known_scanners.version_id;


--
-- Name: known_scanners_version_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('known_scanners_version_id_seq', 49, true);


SET default_with_oids = false;

--
-- Name: log; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE log (
    caller text,
    message text,
    "time" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.log OWNER TO postgres;

SET default_with_oids = true;

--
-- Name: mapped_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE mapped_values (
    std_name text NOT NULL,
    dicom_grp_ele text NOT NULL,
    version_id bigint NOT NULL
);


ALTER TABLE public.mapped_values OWNER TO postgres;

--
-- Name: mapp_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW mapp_view AS
    SELECT dict_std_names.std_name, dict_std_names.unit, dict_std_names.scope, mapped_values.dicom_grp_ele, mapped_values.version_id FROM dict_std_names, mapped_values WHERE (dict_std_names.std_name = mapped_values.std_name) ORDER BY mapped_values.version_id;


ALTER TABLE public.mapp_view OWNER TO postgres;

--
-- Name: mapp_scanner_version; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW mapp_scanner_version AS
    SELECT mapp_view.std_name, mapp_view.unit, mapp_view.scope, mapp_view.dicom_grp_ele, mapp_view.version_id, known_scanners.modality, known_scanners.make, known_scanners.model, known_scanners.vers, known_scanners.group_id FROM mapp_view, known_scanners WHERE ((mapp_view.version_id)::oid = (known_scanners.version_id)::oid) ORDER BY known_scanners.group_id, known_scanners.version_id;


ALTER TABLE public.mapp_scanner_version OWNER TO postgres;

--
-- Name: patient; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE patient (
    pat_name text NOT NULL,
    dob text NOT NULL,
    local_pat_id text NOT NULL,
    mpi_pat_id text NOT NULL,
    gender text NOT NULL,
    height integer,
    weight integer
);


ALTER TABLE public.patient OWNER TO postgres;

--
-- Name: pga_layout; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pga_layout (
    tablename character varying(64) NOT NULL,
    nrcols smallint,
    colnames text,
    colwidth text
);


ALTER TABLE public.pga_layout OWNER TO postgres;

--
-- Name: series; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE series (
    exam_uid text NOT NULL,
    series_uid text NOT NULL,
    station_id text NOT NULL,
    aet text NOT NULL,
    series_description text NOT NULL,
    protocol_name text NOT NULL,
    series_name text NOT NULL,
    body_part text NOT NULL,
    series_number text NOT NULL,
    version_id text NOT NULL,
    series_time text
);


ALTER TABLE public.series OWNER TO postgres;

--
-- Name: series_derived_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE series_derived_values (
    series_uid text NOT NULL,
    std_name text NOT NULL,
    value text NOT NULL,
    unit text NOT NULL,
    algorithm text
);


ALTER TABLE public.series_derived_values OWNER TO postgres;

--
-- Name: series_mapped_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE series_mapped_values (
    series_uid text NOT NULL,
    std_name text NOT NULL,
    value text NOT NULL,
    unit text NOT NULL
);


ALTER TABLE public.series_mapped_values OWNER TO postgres;

--
-- Name: series_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW series_view AS
    SELECT series_mapped_values.series_uid, series_mapped_values.std_name, series_mapped_values.value, series_mapped_values.unit FROM series_mapped_values UNION SELECT series_derived_values.series_uid, series_derived_values.std_name, series_derived_values.value, series_derived_values.unit FROM series_derived_values ORDER BY 1;


ALTER TABLE public.series_view OWNER TO postgres;

--
-- Name: version_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY known_scanners ALTER COLUMN version_id SET DEFAULT nextval('known_scanners_version_id_seq'::regclass);


--
-- Data for Name: acquisition; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY acquisition (acq_time, acq_number, sop_class, exam_uid, series_uid, event_uid) FROM stdin;
\.


--
-- Data for Name: acquisition_derived_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY acquisition_derived_values (event_uid, std_name, value, unit, algorithm) FROM stdin;
\.


--
-- Data for Name: acquisition_mapped_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY acquisition_mapped_values (event_uid, std_name, value, unit) FROM stdin;
\.


--
-- Data for Name: alerts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY alerts (exam_uid, mpi_pat_id, alert_type, closed_status, date_open, date_close, message) FROM stdin;
\.


--
-- Data for Name: derived_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY derived_values (version_id, std_name) FROM stdin;
24873	instance_exposure
40	pulse_seq
42	pulse_seq
43	pulse_seq
44	pulse_seq
\.


--
-- Data for Name: dict_alert_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY dict_alert_types (alert_type, scope, criticality, email_to_address, email_title, email_from_address) FROM stdin;
over_dose_ct	exam	3	langer.steve@mayo.edu	alert from ddw: over dose ct	dlradtrac@mayo.edu
over_dose_fluoro	exam	3	langer.steve@mayo.edu	alert from ddq: over dose fluor	dlradtrac@mayo.edu
over_exam_limit	patient	3	langer.steve@mayo.edu	alert from ddw: over CT limit	dlradtrac@mayo.edu
no_patient	exam	1	langer.steve@mayo.edu	alert from ddw: no patient	\N
unknown_version	exam	3	langer.steve@mayo.edu	alert from ddw: unknown version	dlradtrac@mayo.edu
\.


--
-- Data for Name: dict_std_names; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY dict_std_names (std_name, unit, scope) FROM stdin;
point_exposure	mm, mm, mm, mGy	point
instance_exposure	mGy	instance
series_exposure	mGy	series
exam_exposure	mGy	exam
exam_dose	mSv	exam
tube_current	mA	instance
tube_voltage	kVp	instance
series_dose	mSv	series
s_number	inverse_mGy	instance
dap	mSv*cm2	instance
flouro_dap_total	mSv*cm2	instance
acquisition_dap_total	mSv*cm2	acquisition
primary_angle	deg	acquisition
secondary_angle	deg	acquisition
dist_source_detect	mm	instance
dist_source_isocenter	mm	instance
dlp	mSv*mm	acquisition
ctdi	mSv	acquisition
scan_seq	text	acquisition
slice_thickness	mm	instance
echo_time	ms	instance
inversion_time	ms	instance
field_strength	t	exam
interslice_space	mm	series
flip_angle	deg	instance
num_averages	number	instance
exposure_time	ms	instance
recon_fov	cm	acquisition
focal_spot	mm	series
filter_type	text	series
gen_power	kW	series
processing_descrip	text	instance
processing_code	text	instance
sensitivity	text	instance
view_position	text	instance
relative_exposure	text	instance
compression_force	N	instance
coil	text	series
pulse_seq	text	series
procedure_code_seq	text	instance
shutter_shape	text	acquisition
win_center	text	instance
win_width	text	instance
slope	text	instance
intercept	text	instance
lut_descrip	text	instance
siemens_MR_shadow	text	series
\.


--
-- Data for Name: exams; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY exams (mpi_pat_id, exam_uid, accession, date_of_exam, time_of_exam, refer_doc, exam_descrip, exam_code, campus, operator, triggers_check, radiologist) FROM stdin;
\.


--
-- Data for Name: exams_derived_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY exams_derived_values (exam_uid, std_name, value, unit, algorithm) FROM stdin;
\.


--
-- Data for Name: exams_mapped_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY exams_mapped_values (exam_uid, std_name, value, unit) FROM stdin;
\.


--
-- Data for Name: exams_to_process; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY exams_to_process (exam_uid, last_touched) FROM stdin;
\.


--
-- Data for Name: instance; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instance (exam_uid, series_uid, instance_uid, content_time, instance_number, image_type) FROM stdin;
\.


--
-- Data for Name: instance_binary_object; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instance_binary_object (instance_uid, date_of_exam, header, content) FROM stdin;
\.


--
-- Data for Name: instance_derived_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instance_derived_values (instance_uid, std_name, value, unit, algorithm) FROM stdin;
\.


--
-- Data for Name: instance_mapped_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instance_mapped_values (instance_uid, std_name, value, unit) FROM stdin;
\.


--
-- Data for Name: known_scanners; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY known_scanners (modality, make, model, vers, group_id, version_id) FROM stdin;
MR	GE	GENESIS_SIGNA	09	1	36
MR	GE	Signa HDxt	24_LX_MR Software release:HD16.0_V02_1131.a	1	39
MR	GE	DISCOVERY MR750	23_LX_MR Software release:DV22.0_V02_1122.a	1	41
MR	Siemens	Verio	syngo MR B17	10	40
MR	Siemens	Skyra	syngo MR D11	10	42
MR	GE	SIGNA HDx	14_LX_MR Software release:14.0_M5_0737.f	1	24848
MR	GE Medical Systems	Signa HDxt	15_LX_MR Software release:15.0_M4_0910.a	1	57370
CR	Fuji	5000	A18	3	25275
CR	Fuji	5501ES	A07	3	25436
DR	GE	"Thunder Platform"	DM_Platform_Magic_Release_Patch_1-4.3-2	4	25411
MG	Lorad	Lorad Selenia	AWS:MAMMODROC_3_4_1_8_PXCM:1.4.0.7_ARR:1.7.3.10	6	25617
CT	Siemens	Sensation 64	syngo CT 2007S	2	25236
MR	Siemens	Espree	syngo MR B17	10	43
MR	Siemens	Avanto	syngo MR B17	10	44
MR	GE	DISCOVERY MR450	23_LX_MR Software release:DV22.0_V02_1122.a	1	45
CR	Philips	PCR Eleva	1.2.1_PMS1.1.1 XRG GXRIM4.0	5	25314
CT	Siemens	Sensation 16	syngo CT 2007S	2	41120
CT	Siemens	SOMATOM Definition AS+ syngo CT	syngo CT 2011A.1.04_P02	2	24873
CR	Philips	PCR Eleva	PCR_Eleva_R1.1.5_PMS1.1 XRG GXRIM2.0	5	13
CR	Philips	PCR Eleva	PCR_Eleva_R1.1.1_PMS1.1 XRG GXRIM2.0	5	14
CR 	Philips	digital DIAGNOST	Version 1.5.3.1	6	15
MR 	GE	SIGNA HDx	14_LX_MR Software release:14.0_M5A_0828.b	1	18
RF	Siemens	Siremobil	3VC02C0	7	20
XA	Siemens 	POLYTRON-TOP	H01C	8	21
CT	Siemens 	Sensation 64	syngo CT 2009E	2	23
MR	GE	Optima MR450w	23_LX_MR Software release:DV22.1_V01_1131.a	1	46
MR	GE	GENESIS_HISPEED_RP	05	1	48
MR	GE	GENESIS_SIGNA	04	1	49
MR	GE	Signa HDxt	24_LX_MR Software release:HD16.0_V01_1108.b	1	25
MR	GE	DISCOVERY MR750	21_LX_MR Software release:20.1_IB2_1020.a	1	26
CT	Siemens	SOMATOM Definition Flash	syngo CT 2011A	2	28
CR	KODAK	DRX-EVOLUTION	5.3.409.4	9	29
CR	FUJIFILM Corporation	XU-D1	A07	3	30
CR	FUJI PHOTO FILM Co., ltd.	5501	A06-02	3	35
\.


--
-- Data for Name: log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY log (caller, message, "time") FROM stdin;
ddw:purger	test	2012-09-11 13:48:24.438-05
\.


--
-- Data for Name: mapped_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY mapped_values (std_name, dicom_grp_ele, version_id) FROM stdin;
slice_thickness	tag00180050	24848
field_strength	tag00180087	24848
interslice_space	tag00180088	24848
flip_angle	tag00181314	24848
kvp	tag00180060	25236
slice_thickness	tag00180050	25236
dist_source_detector	tag00181110	25617
tube_current	tag00181151	25236
exposure_time	tag00181150	25236
filter_type	tag00181160	25236
gen_power	tag00181170	25236
focal_spot	tag00181190	25236
tube_voltage	tag00180060	25236
recon_fov	tag00180090	25236
instance_exposure	tag00181152	25236
dist_source_detect	tag00181110	25236
echo_time	tag00180081	24848
repetition_time	tag00180080	24848
inversion_time	tag00180082	24848
image_freq	tag00180084	24848
acquisition_type	tag00180023	24848
processing_descrip	tag00181400	25275
processing_code	tag00181401	25275
sensitivity	tag00186000	25275
sensitivity	tag00186000	25314
processing_code	tag00181401	25314
processing_descrip	tag00181400	25314
dist_source_isocenter	tag00181111	25236
sensitivity	tag00186000	25411
kvp	tag00180060	25411
exposure_time	tag00181150	25411
tube_current	tag00181151	25411
filter_type	tag00181160	25411
dap	tag0018115E	25411
detector_type	tag00187004	25411
view_position	tag00185101	25411
view_position	tag00185101	25436
processing_description	tag00181400	25436
processing_description	tag00181400	25411
relative_exposure	tag00181405	25436
sensitivity	tag00186000	25436
dist_source_isocenter	tag00181111	25617
exposure_time	tag00181150	25617
tube_current	tag00181151	25617
instance_exposure	tag00181152	25411
instance_exposure	tag00181152	25617
compression_force	tag001811A2	25617
focal_spot	tag00181190	25617
view_position	tag00185101	25617
inversion_time	tag00180082	57370
slice_thickness	tag00180050	24873
dist_source_detect	tag00181110	24873
dist_source_isocenter	tag00181111	24873
tube_current	tag00181151	24873
exposure_time	tag00181150	24873
recon_fov	tag00180090	24873
instance_exposure	tag00181152	24873
filter_type	tag00181160	24873
gen_power	tag00181170	24873
focal_spot	tag00181190	24873
tube_voltage	tag00180060	24873
slice_thickness	tag00180050	41120
echo_time	tag00180081	57370
dist_source_detect	tag00181110	41120
dist_source_isocenter	tag00181111	41120
tube_current	tag00181151	41120
exposure_time	tag00181150	41120
filter_type	tag00181160	41120
gen_power	tag00181170	41120
focal_spot	tag00181190	41120
tube_voltage	tag00180060	41120
recon_fov	tag00180090	41120
instance_exposure	tag00181152	41120
coil	tag00181250	24848
pulse_seq	tag0019109C	24848
coil	tag00181250	57370
pulse_seq	tag0019109C	57370
slice_thickness	tag00180050	57370
field_strength	tag00180087	57370
interslice_space	tag00180088	57370
flip_angle	tag00181314	57370
image_freq	tag00180084	18
tube_voltage	tag00180060	41120
sensitivity	tag00186000	13
processing_code	tag00181401	13
processing_descrip	tag00181400	13
sensitivity	tag00186000	14
processing_code	tag00181401	14
processing_descrip	tag00181400	14
tube_voltage	tag00180060	24873
procedure_code_seq	tag00081032	15
slice_thickness	tag00180050	18
field_strength	tag00180087	18
interslice_space	tag00180088	18
flip_angle	tag00181314	18
echo_time	tag00180081	18
repetition_time	tag00180080	18
inversion_time	tag00180082	18
acquisition_type	tag00180023	18
coil	tag00181250	18
pulse_seq	tag0019109C	18
primary_angle	tag00181510	21
secondary_angle	tag00181511	21
shutter_shape	tag00181600	21
coil	tag00181250	25
pulse_seq	tag0019109C	25
coil	tag00181250	26
pulse_seq	tag0019109C	26
photometric_interp	tag00280004	29
coil	tag00181250	36
win_width	tag00281051	29
win_center	tag00281050	29
intercept	tag00281052	29
slope	tag00281053	29
lut_descrip	tag00283010	29
view_position	tag00185101	30
sensitivity	tag00186000	30
relative_exposure	tag00181405	30
photometric_interp	tag00280004	30
win_center	tag00281050	30
win_width	tag00281051	30
intercept	tag00281052	30
slope	tag00281053	30
lut_descrip	tag00283010	30
view_position	tag00185101	35
sensitivity	tag00186000	35
relative_exposure	tag00181405	35
photometric_interpretation	tag00280004	35
win_center	tag00281050	35
win_width	tag00281051	35
intercept	tag00281052	35
slope	tag00281053	35
lut_descrip	tag00283010	35
pulse_seq	tag0019109C	36
coil	tag00181250	39
pulse_seq	tag0019109C	39
coil	tag00181250	41
pulse_seq	tag0019109C	41
coil	tag00181250	45
pulse_seq	tag0019109C	45
coil	tag00181250	46
pulse_seq	tag0019109C	46
coil	tag00181250	48
pulse_seq	tag0019109C	48
coil	tag00181250	49
pulse_seq	tag0019109C	49
siemens_MR_shadow	tag00291020	40
siemens_MR_shadow	tag00291020	42
siemens_MR_shadow	tag00291020	43
siemens_MR_shadow	tag00291020	44
\.


--
-- Data for Name: patient; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY patient (pat_name, dob, local_pat_id, mpi_pat_id, gender, height, weight) FROM stdin;
\.


--
-- Data for Name: pga_layout; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pga_layout (tablename, nrcols, colnames, colwidth) FROM stdin;
public.mapp_version_group	10	std_name unit scope dicom_grp_ele version_id modality make model vers group_id	150 150 150 150 150 150 150 150 150 150
public.mapp_view	5	std_name unit scope dicom_grp_ele version_id	150 150 150 150 150
public.series_mapped_values	4	series_uid std_name value unit	150 150 150 150
public.instance_mapped_values	4	instance_uid std_name value unit	150 150 150 150
\.


--
-- Data for Name: series; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY series (exam_uid, series_uid, station_id, aet, series_description, protocol_name, series_name, body_part, series_number, version_id, series_time) FROM stdin;
\.


--
-- Data for Name: series_derived_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY series_derived_values (series_uid, std_name, value, unit, algorithm) FROM stdin;
\.


--
-- Data for Name: series_mapped_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY series_mapped_values (series_uid, std_name, value, unit) FROM stdin;
\.


--
-- Name: acq_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY acquisition
    ADD CONSTRAINT acq_pkey PRIMARY KEY (event_uid);


--
-- Name: exams_to_process_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY exams_to_process
    ADD CONSTRAINT exams_to_process_pkey PRIMARY KEY (exam_uid);


--
-- Name: instance_binary_object_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instance_binary_object
    ADD CONSTRAINT instance_binary_object_pkey PRIMARY KEY (instance_uid);


--
-- Name: instance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instance
    ADD CONSTRAINT instance_pkey PRIMARY KEY (instance_uid);


--
-- Name: pga_layout_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pga_layout
    ADD CONSTRAINT pga_layout_pkey PRIMARY KEY (tablename);


--
-- Name: pkey_examUID; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alerts
    ADD CONSTRAINT "pkey_examUID" PRIMARY KEY (exam_uid);


--
-- Name: pkey_examuid; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY exams
    ADD CONSTRAINT pkey_examuid PRIMARY KEY (exam_uid);


--
-- Name: pkey_mpi; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY patient
    ADD CONSTRAINT pkey_mpi PRIMARY KEY (mpi_pat_id);


--
-- Name: pkey_seriesuid; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY series
    ADD CONSTRAINT pkey_seriesuid PRIMARY KEY (series_uid);


--
-- Name: exam_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX exam_index ON series USING btree (exam_uid);


--
-- Name: exams_derived_values_exam_uid_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX exams_derived_values_exam_uid_idx ON exams_derived_values USING btree (exam_uid);


--
-- Name: instance_derived_values_instance_uid_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX instance_derived_values_instance_uid_idx ON instance_derived_values USING btree (instance_uid);


--
-- Name: instance_mapped_values_instance_uid_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX instance_mapped_values_instance_uid_idx ON instance_mapped_values USING btree (instance_uid);


--
-- Name: mpi_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX mpi_index ON exams USING btree (mpi_pat_id);


--
-- Name: series_derived_values_series_uid_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX series_derived_values_series_uid_idx ON series_derived_values USING btree (series_uid);


--
-- Name: series_exam_uid_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX series_exam_uid_idx ON series USING btree (exam_uid);


--
-- Name: series_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX series_index ON instance USING btree (series_uid);

ALTER TABLE instance CLUSTER ON series_index;


--
-- Name: series_mapped_values_series_uid_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX series_mapped_values_series_uid_idx ON series_mapped_values USING btree (series_uid);


--
-- Name: run_dispatcher; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER run_dispatcher AFTER INSERT OR UPDATE ON patient FOR EACH ROW EXECUTE PROCEDURE run_dispatcher();


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

