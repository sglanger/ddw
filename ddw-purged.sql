--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: ddw; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE ddw IS 'DICOM Data Warehouse

Steve Langer 2011

A general purpose DICOM dbase for research use and subsequent data mining. No warrenty is expressed or implied

External Dependencies:
 The DDW mirth channel';


--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: postgres
--

CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;


ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO postgres;

SET search_path = public, pg_catalog;

--
-- Name: delete_aquisition_tree(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION delete_aquisition_tree(uid text, OUT success text) RETURNS text
    LANGUAGE plpgsql
    AS $$DECLARE
--------------------------------------
-- Purpose: Clean up PHI info at the acquisition level
-- Args:
-- Caller:
-------------------------------------------

	--local vars
	func text;
BEGIN
	func := 'ddw:delete_acquisition_tree' ;

	-- assume it fails, change later if succeed
	success := 'false';
	DELETE FROM acquisition_derived_values * ;
	DELETE FROM acquisition_mapped_values * ;
	DELETE FROM acquisition * ;

	-- if we got all the way here we succeeded
	success := 'true';
	return ;
END
$$;


ALTER FUNCTION public.delete_aquisition_tree(uid text, OUT success text) OWNER TO postgres;

--
-- Name: delete_exam_tree(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION delete_exam_tree(uid text, OUT success text) RETURNS text
    LANGUAGE plpgsql
    AS $$DECLARE
--------------------------------------
-- Purpose: Clean up PHI info at the exam level
-- Caller: purge_phi
-------------------------------------------

	--local vars
	func text;
BEGIN
	func := 'ddw:delete_exam_tree' ;

	-- assume it fails, change later if succeed
	success := 'false';
	DELETE FROM exams_derived_values * ;
	DELETE FROM exams_mapped_values * ;
	DELETE FROM exams * ;

	-- if we got all the way here we succeeded
	success := 'true';
	return ;
END
$$;


ALTER FUNCTION public.delete_exam_tree(uid text, OUT success text) OWNER TO postgres;

--
-- Name: delete_instance_tree(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION delete_instance_tree(uid text, OUT success text) RETURNS text
    LANGUAGE plpgsql
    AS $$DECLARE
--------------------------------------
-- Purpose: Clean up PHI info at the instance level
-- Args:
-- Caller:
-------------------------------------------

	--local vars
	func text;
BEGIN
	func := 'ddw:delete_instance_tree' ;

	-- assume it fails, change later if succeed
	success := 'false';
	DELETE FROM instance_derived_values * ; 
	DELETE FROM instance_binary_object * ; 
	DELETE FROM instance_mapped_values * ;
	DELETE FROM instance * ;

	-- if we got all the way here we succeeded
	success := 'true';
	return ;
END
$$;


ALTER FUNCTION public.delete_instance_tree(uid text, OUT success text) OWNER TO postgres;

--
-- Name: delete_patient(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION delete_patient(mrn text, OUT success text) RETURNS text
    LANGUAGE plpgsql
    AS $$DECLARE
--------------------------------------
-- Purpose: Clean up PHI info at the patient level
-- Caller: purge_phi
-------------------------------------------

	--local vars
	func text;
BEGIN
	func := 'ddw:delete_patient' ;

	-- assume it fails, change later if succeed
	success := 'false';
	DELETE FROM patient * ;

	-- if we got all the way here we succeeded
	success := 'true';
	return ;
END
$$;


ALTER FUNCTION public.delete_patient(mrn text, OUT success text) OWNER TO postgres;

--
-- Name: delete_series_tree(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION delete_series_tree(uid text, OUT success text) RETURNS text
    LANGUAGE plpgsql
    AS $$DECLARE
--------------------------------------
-- Purpose: Clean up PHI info at the series level
-- Args:
-- Caller:
-------------------------------------------

	--local vars
	func text;
BEGIN
	func := 'ddw:delete_series_tree' ;

	-- assume it fails, change later if succeed
	success := 'false';
	DELETE FROM series_derived_values * ;
	DELETE FROM series_mapped_values * ;
	DELETE FROM series * ;

	-- if we got all the way here we succeeded
	success := 'true';
	return ;
END
$$;


ALTER FUNCTION public.delete_series_tree(uid text, OUT success text) OWNER TO postgres;

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
	-- user PERFORM instead of SELECT since we are throwing away the result
	PERFORM delete_patient ('');
	PERFORM delete_exam_tree ('');
	PERFORM delete_series_tree ('');
	PERFORM delete_aquisition_tree ('');
	PERFORM delete_instance_tree ('');
	
	-- if we got all the way here we succeeded
	success := 'true';
	return ;
END
$$;


ALTER FUNCTION public.purge_phi(OUT success text) OWNER TO postgres;

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
    event_uid text
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
-- Name: alerts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alerts (
    exam_uid text,
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
    group_id integer
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
    SELECT derived_view.std_name FROM derived_view, known_scanners WHERE ((derived_view.version_id)::oid = known_scanners.oid) ORDER BY known_scanners.oid;


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
    SELECT mapp_view.std_name, mapp_view.unit, mapp_view.scope, mapp_view.dicom_grp_ele, mapp_view.version_id, known_scanners.modality, known_scanners.make, known_scanners.model, known_scanners.vers, known_scanners.group_id FROM mapp_view, known_scanners WHERE ((mapp_view.version_id)::oid = known_scanners.oid) ORDER BY mapp_view.version_id;


ALTER TABLE public.mapp_scanner_version OWNER TO postgres;

--
-- Name: patient; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE patient (
    pat_name text NOT NULL,
    dob text NOT NULL,
    local_pat_id text NOT NULL,
    mpi_pat_id text NOT NULL,
    gender text NOT NULL
);


ALTER TABLE public.patient OWNER TO postgres;

--
-- Name: pga_diagrams; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pga_diagrams (
    diagramname character varying(64) NOT NULL,
    diagramtables text,
    diagramlinks text
);


ALTER TABLE public.pga_diagrams OWNER TO postgres;

--
-- Name: pga_forms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pga_forms (
    formname character varying(64) NOT NULL,
    formsource text
);


ALTER TABLE public.pga_forms OWNER TO postgres;

--
-- Name: pga_graphs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pga_graphs (
    graphname character varying(64) NOT NULL,
    graphsource text,
    graphcode text
);


ALTER TABLE public.pga_graphs OWNER TO postgres;

--
-- Name: pga_images; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pga_images (
    imagename character varying(64) NOT NULL,
    imagesource text
);


ALTER TABLE public.pga_images OWNER TO postgres;

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
-- Name: pga_queries; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pga_queries (
    queryname character varying(64) NOT NULL,
    querytype character(1),
    querycommand text,
    querytables text,
    querylinks text,
    queryresults text,
    querycomments text
);


ALTER TABLE public.pga_queries OWNER TO postgres;

--
-- Name: pga_reports; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pga_reports (
    reportname character varying(64) NOT NULL,
    reportsource text,
    reportbody text,
    reportprocs text,
    reportoptions text
);


ALTER TABLE public.pga_reports OWNER TO postgres;

--
-- Name: pga_scripts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pga_scripts (
    scriptname character varying(64) NOT NULL,
    scriptsource text
);


ALTER TABLE public.pga_scripts OWNER TO postgres;

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
    version_id text NOT NULL
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
\.


--
-- Data for Name: dict_alert_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY dict_alert_types (alert_type, scope, criticality, email_to_address, email_title, email_from_address) FROM stdin;
over_dose_ct	exam	3	langer.steve@mayo.edu	alert from ddw: over dose ct	dlradtrac@mayo.edu
over_dose_fluoro	exam	3	langer.steve@mayo.edu	alert from ddq: over dose fluor	dlradtrac@mayo.edu
unknown_version	exam	2	langer.steve@mayo.edu	alert from ddw: unknown version	dlradtrac@mayo.edu
over_exam_limit	patient	3	langer.steve@mayo.edu	alert from ddw: over CT limit	dlradtrac@mayo.edu
no_patient	exam	1	langer.steve@mayo.edu	alert from ddw: no patient	\N
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

COPY known_scanners (modality, make, model, vers, group_id) FROM stdin;
MR	GE	SIGNA HDx	14_LX_MR Software release:14.0_M5_0737.f	1
CT	Siemens	Sensation 64	syngo CT 2007S	2
CR	Fuji	5000	A18	3
CR	Fuji	5501ES	A07	3
DR	GE	"Thunder Platform"	DM_Platform_Magic_Release_Patch_1-4.3-2	4
CR	Philips	PCR Eleva	1.2.1_PMS1.1.1 XRG GXRIM4.0	5
MG	Lorad	Lorad Selenia	AWS:MAMMODROC_3_4_1_8_PXCM:1.4.0.7_ARR:1.7.3.10	6
CT	Siemens	Sensation 16	syngo CT 2007S	2
RF	Siemens	Siremobil	3VC02C0	7
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
kvp	tag00180060	24873
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
\.


--
-- Data for Name: patient; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY patient (pat_name, dob, local_pat_id, mpi_pat_id, gender) FROM stdin;
\.


--
-- Data for Name: pga_diagrams; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pga_diagrams (diagramname, diagramtables, diagramlinks) FROM stdin;
\.


--
-- Data for Name: pga_forms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pga_forms (formname, formsource) FROM stdin;
\.


--
-- Data for Name: pga_graphs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pga_graphs (graphname, graphsource, graphcode) FROM stdin;
\.


--
-- Data for Name: pga_images; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pga_images (imagename, imagesource) FROM stdin;
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
-- Data for Name: pga_queries; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pga_queries (queryname, querytype, querycommand, querytables, querylinks, queryresults, querycomments) FROM stdin;
\.


--
-- Data for Name: pga_reports; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pga_reports (reportname, reportsource, reportbody, reportprocs, reportoptions) FROM stdin;
\.


--
-- Data for Name: pga_scripts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pga_scripts (scriptname, scriptsource) FROM stdin;
\.


--
-- Data for Name: series; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY series (exam_uid, series_uid, station_id, aet, series_description, protocol_name, series_name, body_part, series_number, version_id) FROM stdin;
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
-- Name: exams_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY exams
    ADD CONSTRAINT exams_pkey PRIMARY KEY (exam_uid);


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
-- Name: pga_diagrams_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pga_diagrams
    ADD CONSTRAINT pga_diagrams_pkey PRIMARY KEY (diagramname);


--
-- Name: pga_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pga_forms
    ADD CONSTRAINT pga_forms_pkey PRIMARY KEY (formname);


--
-- Name: pga_graphs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pga_graphs
    ADD CONSTRAINT pga_graphs_pkey PRIMARY KEY (graphname);


--
-- Name: pga_images_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pga_images
    ADD CONSTRAINT pga_images_pkey PRIMARY KEY (imagename);


--
-- Name: pga_layout_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pga_layout
    ADD CONSTRAINT pga_layout_pkey PRIMARY KEY (tablename);


--
-- Name: pga_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pga_queries
    ADD CONSTRAINT pga_queries_pkey PRIMARY KEY (queryname);


--
-- Name: pga_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pga_reports
    ADD CONSTRAINT pga_reports_pkey PRIMARY KEY (reportname);


--
-- Name: pga_scripts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pga_scripts
    ADD CONSTRAINT pga_scripts_pkey PRIMARY KEY (scriptname);


--
-- Name: xpatient_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY patient
    ADD CONSTRAINT xpatient_pkey PRIMARY KEY (mpi_pat_id);


--
-- Name: xseries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY series
    ADD CONSTRAINT xseries_pkey PRIMARY KEY (series_uid);


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
-- Name: series_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX series_index ON instance USING btree (series_uid);


--
-- Name: series_mapped_values_series_uid_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX series_mapped_values_series_uid_idx ON series_mapped_values USING btree (series_uid);


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

