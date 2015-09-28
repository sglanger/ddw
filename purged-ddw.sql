--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: purged_ddw; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE purged_ddw WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


ALTER DATABASE purged_ddw OWNER TO postgres;

\connect purged_ddw

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: purged_ddw; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE purged_ddw IS 'DICOM Data Warehouse

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
-- Name: clone_version(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION clone_version(src_version text) RETURNS text
    LANGUAGE plpgsql
    AS $$declare
----------------------------------
-- Purpose: Make it easy to clone an existing
-- 	scanner tag mapping to other scanners in
--	same group
-- Caller: manual
---------------------------------
	func text;
	grp int;
	status text ;
	result known_scanners%ROWTYPE;
	res2 mapped_values%ROWTYPE;
	res3 derived_values%ROWTYPE;
begin
	func :='ddw:clone_version';
	status := 'fail';
	
	-- OK, the idea is to ID the group this scanner belongs to
	-- then find all the other group members and
	-- copy this guy's tag mappings to them

	select into grp group_id from known_scanners where known_scanners.version_id = cast (src_version as bigint) ;
	--perform logger (func, grp);
	for result in select * from known_scanners where group_id = grp LOOP
		--perform logger (func, result.version_id);

		-- now, we don't want to process the Source version
		if result.version_id  = cast (src_version as bigint) then
			-- do nothing, move onto the next group member
			CONTINUE ;
		else
			-- this version is not the Source version, so we want to clear the current mappings 
			-- so there are no old tags that are not present in the Source
			delete from derived_values * where derived_values.version_id = result.version_id ;
			delete from mapped_values * where mapped_values.version_id = result.version_id ;
			--return cast (result.version_id as text);
		end if;
		
		-- Now loop over the tag maps for the Src and insert into mappings
		-- for the destination scanners
		for res2 in select * from mapped_values  where version_id = cast (src_version as bigint) LOOP
			perform logger (func, res2.std_name);
			BEGIN
				status :='ok';
				insert into mapped_values values (res2.std_name, res2.dicom_grp_ele, result.version_id);
			EXCEPTION WHEN unique_violation then
				-- do nothing
				status :='ok';
			END;	
		end loop;

		-- Now here do it again for table Derived_Values
		for res3 in select * from derived_values  where version_id = cast (src_version as bigint) LOOP
			perform logger (func, res3.std_name);
			BEGIN
				status :='ok';
				insert into derived_values values (result.version_id, res3.std_name);
			EXCEPTION WHEN unique_violation then
				-- do nothing
				status :='ok';
			END;
		end loop;
	end loop;
	return status;
end
$$;


ALTER FUNCTION public.clone_version(src_version text) OWNER TO postgres;

--
-- Name: dispatcher(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dispatcher(OUT status text) RETURNS text
    LANGUAGE plpgsql
    AS $$DECLARE
--------------------------------------
-- Purpose: run by Patient table trigger, looks at 
--	table exams_to_process and then
--	a) maps an exam to an analytic algorithm for processing
--	b) verifies analytic runs
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
	truncate log ;
	
	for result in select * from exams_to_process LOOP
		if current_date - cast(result.last_touched as date) > 0 then 
			-- first find out what the SWare versionID is for this series
			select into id version_id from series where series.exam_uid = result.exam_uid ;
			-- Next find out what group this Sware version maps to
			select into gid group_id from known_scanners where known_scanners.version_id = cast (id as integer)  ;

			-- Now we know what algorithm to invoke, pass it the study_uid
			if gid = 1 then
				-- GE MR
				SELECT into status one(result.exam_uid);
			elseif gid = 2 then
				-- Siemens CT
				Select into status two(result.exam_uid);
			elseif gid = 3 then
				-- Fuji CR
				Select into status three(result.exam_uid);
			elseif gid = 4 then
				-- GE DR
				Select into status four(result.exam_uid);
			elseif gid = 5 then
				-- Philips CR
				Select into status five(result.exam_uid);
			elseif gid = 10 then
				-- Siemens MR
				--perform logger (func, 'in Siemens MR');
				Select into status ten(result.exam_uid);
			elseif gid = 11 then
				-- GE PACS
				Select into status eleven(result.exam_uid);		
			elseif gid = 12 then
				-- Carestream DR
				Select into status twelve(result.exam_uid);	
			elseif gid = 13 then
				-- GE PET
				Select into status thirteen(result.exam_uid);	
			elseif gid = 14 then				
				-- GE CT
				Select into status fourteen(result.exam_uid);	
			else
				perform logger (func, 'unknown GID ' || gid);
			end if;

			-- check here if status is OK
			-- And last remove the entry now that it's been analyzed
			--perform logger (func, status);
			if status = 'ok' then
				--perform logger (func, 'in OK');
				DELETE from exams_to_process * where exam_uid = result.exam_uid ;
			else
				-- something must have broke, should raise an alert
				perform logger (func, 'GID ' || gid || ' failed on '|| result.exam_uid);
			end if;
		end if;
	end LOOP;

	return ;
END
$$;


ALTER FUNCTION public.dispatcher(OUT status text) OWNER TO postgres;

--
-- Name: eleven(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION eleven(study_uid text) RETURNS text
    LANGUAGE plpgsql
    AS $$declare
------------------------------------------
-- Purpose: GE PACS header processor
-- 	After successful run clears entry from
--	"exams-to-process" table
-- Caller: Dispatcher
-----------------------------------------
	func text :='ddw:eleven';
	status text :='failed';

begin
	status :='ok';
	-- right now this is just a stub to clear the "exams-to-process" table
	-- and avoid errors in the Log table
	return status ;
end;$$;


ALTER FUNCTION public.eleven(study_uid text) OWNER TO postgres;

--
-- Name: five(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION five(study_uid text) RETURNS text
    LANGUAGE plpgsql
    AS $$declare
------------------------------------------
-- Purpose: Philips CR header processor
-- 	After successful run clears entry from
--	"exams-to-process" table
-- Caller: Dispatcher
-----------------------------------------
	func text :='ddw:five';
	status text :='failed';

begin
	status :='ok';
	-- right now this is just a stub to clear the "exams-to-process" table
	-- and avoid errors in the Log table
	return status ;
end;$$;


ALTER FUNCTION public.five(study_uid text) OWNER TO postgres;

--
-- Name: four(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION four(study_uid text) RETURNS text
    LANGUAGE plpgsql
    AS $$declare
------------------------------------------
-- Purpose: GE DR header processor
-- 	After successful run clears entry from
--	"exams-to-process" table
-- Caller: Dispatcher
-----------------------------------------
	func text :='ddw:four';
	status text :='failed';

begin
	status :='ok';
	-- right now this is just a stub to clear the "exams-to-process" table
	-- and avoid errors in the Log table
	return status ;
end;$$;


ALTER FUNCTION public.four(study_uid text) OWNER TO postgres;

--
-- Name: fourteen(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fourteen(study_uid text) RETURNS text
    LANGUAGE plpgsql
    AS $_$declare
------------------------------------------
-- Purpose: GE CT header processor
-- 	This takes in the Dose-SR segment tag0040A730 
--	from the TABLE "exams_mapped_values"
-- 	and parses out the vendor specific
--	labels for the information of interest. This is
--	then stuffed into TABLE "exams_derived_values"
-- Caller: Dispatcher
-----------------------------------------
	func text :='ddw:fourteen';
	status text :='failed';
	res2 exams_mapped_values%ROWTYPE;
	val float;
	stop int;
	i int := 0;
	terms text[];
	tags text[];
	tag text;
	term text;
	buf  text;
	valu text;
begin
	-- These arrays are synced. 
	terms[0] := array['dlp'];
	terms[1] := array['ctdi_vol'];
	tags[0] :=  array['Product'];
	tags[1] :=  array['CTDIvol'];
	-- end at '</tag0040A30A>'

	for res2 in select * from exams_mapped_values where exams_mapped_values.exam_uid = $1 LOOP
		if res2.std_name = 'dose_SR' then
			-- Loop over the array of intersting SR tags
			i := 0;
			while (i < 2 ) loop
				buf := res2.value ;
				val := 0;
				tag := substr(tags[i], strpos(tags[i], '{') +1, strpos(tags[i], '}') - 2) ;
				term := substr(terms[i], strpos(terms[i], '{') +1, strpos(terms[i], '}') - 2) ;
				-- Accumulate and sum all occurences of a tag into a Summation Value for the exam
				while (strpos(buf, tag) > 0) loop
					buf := substr(buf, strpos(buf, tag), char_length(buf));
					stop := strpos(buf, '</tag0040A30A>');
					valu := substr(buf, stop - 18, stop- (stop - 18)) ;
					perform logger(func, 'stop: ' || stop || ' length: ' || char_length(buf) || ' value: ' || valu);
					val := val + str2flt (substr (valu, strpos(valu, '>') + 1, char_length(valu)), '');
					buf := substr(buf, stop, char_length(buf));
				end loop;
				perform logger(func, term || ': ' || val);
				BEGIN
					insert into exams_derived_values values (res2.exam_uid, term, cast (val as text), 'text', func) ;
					status :='ok';
				EXCEPTION WHEN unique_violation then
					-- do nothing
					status :='ok';
				END;
				i := i + 1;
			end loop;
		end if;
	end loop;

	if status = 'failed' then
		-- if this ExamsNMappedValue entry does not have the SR, check How many times we have tried
		select into i run_trial from exams_to_process where exams_to_process.exam_uid = $1 ;
		if i < 5 then
			-- hope the next Exams_Mapped_Entry will have it
			UPDATE exams_to_process set run_trial = (i + 1) where exams_to_process.exam_uid = $1 ;
		else	
			-- but at some point we have to give up, Maybe CT never sent a DOSE-SR to MIDIA/PACS?
			status :='ok';
		end if;
	end if;
	return status;
end$_$;


ALTER FUNCTION public.fourteen(study_uid text) OWNER TO postgres;

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
    AS $_$declare
------------------------------------------
-- Purpose: GE MR header processor
-- 	After successful run clears entry from
--	"exams-to-process" table
-- Caller: Dispatcher
-----------------------------------------
	func text;
	status text;
	val text;
	rep_time int;
	gotTo text;
	result series%ROWTYPE;
	res2 series_mapped_values%ROWTYPE;
begin
	func :='ddw:one';
	status :='fail';
	gotTo :='1';

	--perform logger (func, 'entering 1. examUID = ' || $1);
	-- now need to loop over each series in this exam
	-- and look at its TR and TE in Series_Mapped_values
	for result in select * from  series where series.exam_uid = $1 LOOP 
		gotTo :='2';
		for res2 in select * from series_mapped_values where series_mapped_values.series_uid = result.series_uid LOOP
			gotTo :='3';
			--perform logger (func, 'gotTo = ' || gotTo || res2.std_name );
			if res2.std_name = 'repetition_time' then
				gotTo :='4';
				--perform logger (func, 'in rep time ' || res2.value);
				select into rep_time str2int(res2.value, '.' ); 
				--perform logger (func, ' ' || rep_time);
				if rep_time  < 1100 then
					val := 'T1W' ;
				else
					val := 'T2W' ;
				end if;
				BEGIN
					--perform logger (func, val);	
					insert into series_derived_values values (result.series_uid, 'weighted', val, 'text', 'one');
					status :='ok';
				EXCEPTION WHEN unique_violation then
					-- do nothing
					status :='ok';
				END;
			end if;
		end LOOP;
	end LOOP;

	perform logger (func, 'exiting 1. gotTo = ' || gotTo || res2.std_name );
	return status;
end
$_$;


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
    AS $_$declare
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
		truncate instance_derived_values, instance_mapped_values, instance_binary_object, instance ;
		status := 'ok';
	elseif scope = 'trunc-uid' then
		perform logger (func, $2);
		truncate last_uids;
		-- but after we do this, MIRTH channel fails with "Out of range" error
		-- so need to put dummy row in
		INSERT into last_uids values ('mcr-dit', '1.2.3', '1.2.3.4', '1.2.3.4.5') ;
		INSERT into last_uids values ('mcr-dit2', '1.2.3.4', '1.2.3.4.5', '1.2.3.4.5') ;
		status := 'ok';
	end if;

	--perform logger (func, status);
	return status;
end
$_$;


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
-- Name: str2flt(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION str2flt("in" text, exponent text) RETURNS double precision
    LANGUAGE plpgsql
    AS $_$declare
------------------------------------------
-- Author: SG Langer, March 2014
-- Purpose: Take any numeric looking string as input
-- 	and isolate the parts left and right of decimal
-- 	and convert to numbers
-- Args: $1 = the numeric string
--	$2 = an exponent if scientific notation (not implemented yet)
-- Caller: numerous
-----------------------------------------
	func text := 'ddw: str2flt';
	leftval text;
	rightval text ;
	sum double precision := 0;
	sign int := 1;
	exp int := 0;
	digit text;
	asc_val int;
begin
	-- check if a decimal,and slice off everything to the right of it
	if (strpos($1, '.') < 1) then
		-- casting does not work. CAST thinks $1 is ''
		--val := cast ($1 as int);
		leftval := $1;
		rightval := '0';
	else
		leftval := substr($1, 0, strpos($1, '.'));
		rightval := substr($1, strpos($1, '.'), char_length($1)); 
	end if;
	
	-- check if it is negative
	if (strpos(leftval, '-') =1) then
		sign := -1;
		leftval := substr(leftval, 2, char_length(leftval));
	end if;

	-- now, build up the Float part of the leftVal
	while char_length(leftval)> 0 loop
		-- need to handle "invalid input" when substr hits a ',' or ' '
		digit := substr(leftval, char_length(leftval)) ;
		-- now check that digit is Numeric else ignore
		select into asc_val ascii(digit);
		--perform logger (func, 'leftval digit and asc: ' || digit  || ' ' || asc_val);
		if (asc_val > 47 AND asc_val < 58) then
			sum := sum + 10^exp * cast (digit as int) ;	
			exp := exp + 1 ;
		end if;
		leftval := substr(leftval, 0, char_length(leftval) );
	end loop ;

	-- now, build up the Float part of the rightVal
	exp := -1 * char_length(rightval) + 1 ;
	while char_length(rightval)> 0 loop
		digit := substr(rightval, char_length(rightval));
		-- now check that digit is Numeric else ignore
		select into asc_val ascii(digit);
		if (asc_val > 47 AND asc_val < 58) then
			sum := sum + 10^exp * cast (digit as int) ;	
			exp := exp + 1 ;
		end if;
		rightval := substr(rightval, 0, char_length(rightval) );
		--perform logger (func, 'right val: ' || rightval || ' ' || sum);
	end loop;

	return sign * sum;
end$_$;


ALTER FUNCTION public.str2flt("in" text, exponent text) OWNER TO postgres;

--
-- Name: str2int(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION str2int(str text, exponent text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$declare
------------------------------------------
-- Author: SG Langer, March 2014
-- Purpose: Take any numeric looking string as input
--	Trim off the float part (if one), then
--	create an int and return. This was necessary 
--	because neither Cast nor to_number() in pgSQL work. 
--	Oh, they work when I called them directly like
--	CAST ('123.45' as int)
-- 	but failed when I did this
--	CAST (table.textField as int)
-- 	I kept getting "Wrong input syntax for int: '' "
--	That is to say both CAST and to_number see the textField as NULL
--	As the URL's below show, I was not the first to see this
-- Args: $1 = the numeric string
--	$2 = an exponent if scientific notation (not implemented yet)
-- Caller: numerous
-----------------------------------------
	func text;
	val text;
	sum int;
	exp int;
	digit text;
	sign int;
	asc_val int;
begin
	func :='ddw:str2int';
	exp :=0;
	sum :=0;
	sign := 1;

	-- check if a decimal,and slice off everything to the right of it
	if (strpos($1, '.') < 1) then
		-- casting does not work. CAST thinks $1 is ''
		--val := cast ($1 as int);
		val := $1;
	else
		val := substr($1, 0, strpos($1, '.'));
	end if;
	
	-- check if it is negative
	if (strpos(val, '-') =1) then
		sign := -1;
		val := substr(val, 2, char_length(val));
	end if;

	while char_length(val)> 0 loop
		-- need to handle "invalid input" when substr hits a ',' or ' '
		BEGIN
			digit := substr(val, char_length(val));
			-- now check that digit is Numeric else ignore
			select into asc_val ascii(digit);
			if (asc_val > 47 AND asc_val < 58) then
				sum := sum + 10^exp * cast (digit as int) ; 
				exp := exp + 1 ;
				perform logger (func, 'digit and exp ' || digit || ' ' || exp); 
			end if;
		EXCEPTION WHEN others then
			-- do nothing, just log error
			perform logger (func, 'exception =' || others);
		END; 
		--perform logger (func, val || ' ' || sum);
		val := substr(val, 0, char_length(val) );
	end loop ;
	
	-- THESE all have SAME problem, think $1 is NULL
	-- http://forums.codeguru.com/showthread.php?527147-PL-pgsql-Convert-character-varying-to-an-integer
	--select into val to_number(quote_literal($1), quote_literal(99999999));

	--http://grokbase.com/t/postgresql/pgsql-general/01bv71dv92/casting-varchar-to-numeric
	--select into val $1::double precision::numeric ;
	return sign * sum;
end
$_$;


ALTER FUNCTION public.str2int(str text, exponent text) OWNER TO postgres;

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
	perform logger (func, 'entering 10. examUID = ' || $1);
	
	-- find all series_uid matching exam_uid 
	-- then Qry the series_mapped_table for 
	-- "siemens_MR_shadow" and parse out the PulseSeq
	for result in select * from  series where series.exam_uid = $1 LOOP 
		--perform logger (func, 'stationID = ' || result.station_id);
		--perform logger (func, 'versionID = ' || result.version_id);
		for res2 in select * from series_mapped_values where series_mapped_values.series_uid = result.series_uid LOOP
			-- now parse the tags of interest in series_mapped_values
			-- where series_uids have the parent exam_uid
			if res2.std_name = 'siemens_MR_shadow' then
				-- parse res2.value for CustomerSeq%\\
				value = substr (res2.value, strpos(res2.value,'Seq%\\') + 4, 20);
				value = split_part (value, '""', 1);
				--perform logger (func, value); 
				--  then update the series_derived values
				BEGIN
					insert into series_mapped_values values (result.series_uid, 'pulse_seq', value, 'text');
					status :='ok';
				EXCEPTION WHEN unique_violation then
					-- do nothing
					status :='ok';
				END;
			else
				--perform logger (func, 'std name = ' || res2.std_name); 
				value = '' ;
			end if;
		end LOOP;
	end LOOP;

	return status;
end$_$;


ALTER FUNCTION public.ten(study_uid text) OWNER TO postgres;

--
-- Name: thirteen(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION thirteen("studyUID" text) RETURNS text
    LANGUAGE plpgsql
    AS $_$declare
------------------------------------------
-- Purpose: GE  PET-CT header processor
-- 	This takes in the Dose-SR segment tag0040A730 
--	from the TABLE "exams_mapped_values"
-- 	and parses out the vendor specific
--	labels for the information of interest. This is
--	then stuffed into TABLE "exams_derived_values"
-- Caller: Dispatcher
-----------------------------------------
	func text :='ddw:thirteen';
	status text :='failed';
	res2 exams_mapped_values%ROWTYPE;
	val float;
	stop int;
	i int := 0;
	terms text[];
	tags text[];
	tag text;
	term text;
	buf  text;
	valu text;
begin
	-- These arrays are synced. 
	terms[0] := array['dlp'];
	terms[1] := array['ctdi_vol'];
	tags[0] :=  array['Product'];
	tags[1] :=  array['CTDIvol'];
	-- end at '</tag0040A30A>'
	
	for res2 in select * from exams_mapped_values where exams_mapped_values.exam_uid = $1 LOOP
		if res2.std_name = 'dose_SR' then
			-- Loop over the array of intersting SR tags
			i := 0;
			while (i < 2 ) loop
				buf := res2.value ;
				val := 0;
				tag := substr(tags[i], strpos(tags[i], '{') +1, strpos(tags[i], '}') - 2) ;
				term := substr(terms[i], strpos(terms[i], '{') +1, strpos(terms[i], '}') - 2) ;
				-- Accumulate and sum all occurences of a tag into a Summation Value for the exam
				while (strpos(buf, tag) > 0) loop
					buf := substr(buf, strpos(buf, tag), char_length(buf));
					stop := strpos(buf, '</tag0040A30A>');
					valu := substr(buf, stop - 18, stop- (stop - 18)) ;
					perform logger(func, 'stop: ' || stop || ' length: ' || char_length(buf) || ' value: ' || valu);
					val := val + str2flt (substr (valu, strpos(valu, '>') + 1, char_length(valu)), '');
					buf := substr(buf, stop, char_length(buf));
				end loop;
				perform logger(func, term || ': ' || val);
				BEGIN
					insert into exams_derived_values values (res2.exam_uid, term, cast (val as text), 'text', func) ;
					status :='ok';
				EXCEPTION WHEN unique_violation then
					-- do nothing
					status :='ok';
				END;
				i := i + 1;
			end loop;
		end if;
	end loop;
	
	if status = 'failed' then
		-- if this ExamsNMappedValue entry does not have the SR, check How many times we have tried
		select into i run_trial from exams_to_process where exams_to_process.exam_uid = $1 ;
		if i < 5 then
			-- hope the next Exams_Mapped_Entry will have it
			UPDATE exams_to_process set run_trial = (i + 1) where exams_to_process.exam_uid = $1 ;
		else	
			-- but at some point we have to give up, Maybe CT never sent a DOSE-SR to MIDIA/PACS?
			status :='ok';
		end if;
	end if;
	return status;
end$_$;


ALTER FUNCTION public.thirteen("studyUID" text) OWNER TO postgres;

--
-- Name: three(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION three(study_uid text) RETURNS text
    LANGUAGE plpgsql
    AS $$declare
------------------------------------------
-- Purpose: Fuji CR header processor
-- 	After successful run clears entry from
--	"exams-to-process" table
-- Caller: Dispatcher
-----------------------------------------
	func text :='ddw:three';
	status text :='failed';

begin
	status :='ok';
	-- right now this is just a stub to clear the "exams-to-process" table
	-- and avoid errors in the Log table
	return status ;
end;$$;


ALTER FUNCTION public.three(study_uid text) OWNER TO postgres;

--
-- Name: trunc_last_uid(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION trunc_last_uid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$begin
  PERFORM purger ('', 'trunc-uid');
  return null;
end;$$;


ALTER FUNCTION public.trunc_last_uid() OWNER TO postgres;

--
-- Name: twelve(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION twelve(study_uid text) RETURNS text
    LANGUAGE plpgsql
    AS $$declare
------------------------------------------
-- Purpose: Carestream DR header processor
-- 	After successful run clears entry from
--	"exams-to-process" table
-- Caller: Dispatcher
-----------------------------------------
	func text :='ddw:twelve';
	status text :='failed';

begin
	status :='ok';
	-- right now this is just a stub to clear the "exams-to-process" table
	-- and avoid errors in the Log table
	return status ;
end;$$;


ALTER FUNCTION public.twelve(study_uid text) OWNER TO postgres;

--
-- Name: two(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION two(study_uid text) RETURNS text
    LANGUAGE plpgsql
    AS $_$declare
------------------------------------------
-- Purpose: Siemens CT header processor
-- 	This takes in the Dose-SR segment tag0040A730 
--	from the TABLE "exams_mapped_values"
-- 	and parses out the vendor specific
--	labels for the information of interest. This is
--	then stuffed into TABLE "exams_derived_values"
-- Caller: Dispatcher
-----------------------------------------
	func text :='ddw:two';
	status text :='failed';
	res2 exams_mapped_values%ROWTYPE;
	val float;
	stop int;
	i int ;
	terms text[];
	tags text[];
	tag text;
	term text;
	buf  text;
	valu text;
		gotTo int;
begin
	-- These arrays are synched. Terms are from dict_std_names
	-- tags are from vendor SR object
	terms[0] := array['dlp'];
	terms[1] := array['ctdi_vol'];
	tags[0] :=  array['Product'];
	tags[1] :=  array['CTDIvol'];
	-- end at '</tag0040A30A>'
	gotTo :=1;
		
	for res2 in select * from exams_mapped_values where exams_mapped_values.exam_uid = $1 LOOP
		gotTo :=3;
		if res2.std_name = 'dose_SR' then
			-- Loop over the array of intersting SR tags
			i := 0;
			gotTo :=4;
			while (i < 2 ) loop
				buf := res2.value ;
				val := 0;
				tag := substr(tags[i], strpos(tags[i], '{') +1, strpos(tags[i], '}') - 2) ;
				term := substr(terms[i], strpos(terms[i], '{') +1, strpos(terms[i], '}') - 2) ;
				-- Accumulate and sum all occurences of a tag into a Summation Value for the exam
				while (strpos(buf, tag) > 0) loop
					buf := substr(buf, strpos(buf, tag), char_length(buf));
					stop := strpos(buf, '</tag0040A30A>');
					valu := substr(buf, stop - 18, stop- (stop - 18)) ;
					--perform logger(func, 'stop: ' || stop || ' length: ' || char_length(buf) || ' value: ' || valu);
					val := val + str2flt (substr (valu, strpos(valu, '>') + 1, char_length(valu)), '');
					buf := substr(buf, stop, char_length(buf));
				end loop;
				perform logger(func, term || ': ' || val);
				BEGIN
					insert into exams_derived_values values (res2.exam_uid, term, cast (val as text), 'text', func) ;
					status :='ok';
				EXCEPTION WHEN unique_violation then
					-- do nothing
					status :='ok';
				END;
				i := i + 1;
			end loop;
		end if;
	end loop;

	if status = 'failed' then
		-- if this ExamsNMappedValue entry does not have the SR, check How many times we have tried
		select into i run_trial from exams_to_process where exams_to_process.exam_uid = $1 ;
		if i < 5 then
			-- hope the next Exams_Mapped_Entry will have it
			UPDATE exams_to_process set run_trial = (i + 1) where exams_to_process.exam_uid = $1 ;
		else	
			-- but at some point we have to give up, Maybe CT never sent a DOSE-SR to MIDIA/PACS?
			status :='ok';
		end if;
	end if;
	--perform logger (func, 'exiting. gotTo =  ' || gotTo);
	return status ;
end $_$;


ALTER FUNCTION public.two(study_uid text) OWNER TO postgres;

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
    SELECT DISTINCT dict_std_names.std_name, dict_std_names.unit, dict_std_names.scope, derived_values.version_id FROM derived_values, dict_std_names WHERE (derived_values.std_name = dict_std_names.std_name) ORDER BY derived_values.version_id, dict_std_names.std_name, dict_std_names.unit, dict_std_names.scope;


ALTER TABLE public.derived_view OWNER TO postgres;

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
-- Name: known_scanners_version_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('known_scanners_version_id_seq', 120, true);


--
-- Name: known_scanners; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE known_scanners (
    modality text NOT NULL,
    make text NOT NULL,
    model text NOT NULL,
    vers text NOT NULL,
    group_id integer,
    version_id integer DEFAULT nextval('known_scanners_version_id_seq'::regclass) NOT NULL
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
    last_touched timestamp without time zone DEFAULT now(),
    modality text,
    run_trial integer
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

SET default_with_oids = false;

--
-- Name: last_uids; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE last_uids (
    gateway text NOT NULL,
    study text,
    series text,
    instance text
);


ALTER TABLE public.last_uids OWNER TO postgres;

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
    SELECT DISTINCT dict_std_names.std_name, dict_std_names.unit, dict_std_names.scope, mapped_values.dicom_grp_ele, mapped_values.version_id FROM dict_std_names, mapped_values WHERE (dict_std_names.std_name = mapped_values.std_name) ORDER BY mapped_values.version_id, dict_std_names.std_name, dict_std_names.unit, dict_std_names.scope, mapped_values.dicom_grp_ele;


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
    series_time text,
    modality text
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
40	pulse_seq
40	weighted
23	dlp
23	ctdi_vol
71	dlp
71	ctdi_vol
18	weighted
36	weighted
39	weighted
50	weighted
24848	weighted
57370	weighted
45	weighted
46	weighted
48	weighted
49	weighted
25	weighted
26	weighted
52	weighted
55	weighted
41	weighted
65	weighted
57	weighted
60	weighted
67	weighted
78	weighted
79	weighted
97	weighted
98	weighted
99	weighted
100	weighted
103	weighted
104	weighted
119	weighted
120	weighted
25236	dlp
25236	ctdi_vol
41120	dlp
41120	ctdi_vol
24873	dlp
24873	ctdi_vol
28	dlp
28	ctdi_vol
58	dlp
58	ctdi_vol
68	dlp
68	ctdi_vol
76	dlp
76	ctdi_vol
77	dlp
77	ctdi_vol
109	dlp
109	ctdi_vol
105	dlp
105	ctdi_vol
112	dlp
112	ctdi_vol
80	dlp
80	ctdi_vol
82	dlp
82	ctdi_vol
106	dlp
106	ctdi_vol
83	dlp
83	ctdi_vol
108	dlp
108	ctdi_vol
42	pulse_seq
42	weighted
43	pulse_seq
43	weighted
44	pulse_seq
44	weighted
66	pulse_seq
66	weighted
101	pulse_seq
101	weighted
117	pulse_seq
117	weighted
\.


--
-- Data for Name: dict_alert_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY dict_alert_types (alert_type, scope, criticality, email_to_address, email_title, email_from_address) FROM stdin;
over_dose_ct	exam	3	langer.steve@mayo.edu	alert from ddw: over dose ct	dlradtrac@mayo.edu
over_dose_fluoro	exam	3	langer.steve@mayo.edu	alert from ddq: over dose fluor	dlradtrac@mayo.edu
over_exam_limit	patient	3	langer.steve@mayo.edu	alert from ddw: over CT limit	dlradtrac@mayo.edu
no_patient	exam	1	langer.steve@mayo.edu	alert from ddw: no patient	\N
unknown_version	exam	1	langer.steve@mayo.edu	alert from ddw: unknown version	dlradtrac@mayo.edu
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
scan_seq	text	acquisition
slice_thickness	mm	instance
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
weight	kg	exam
SAR	W/Kg	series
echo_time	ms	series
inversion_time	ms	series
repetition_time	ms	series
weighted	text	series
contrast_agent	text	series
ctdi_vol	mGy	exam
dlp	mGy*cm	exam
SR_object	text	exam
dose_SR	text	exam
image_orientation	direction cosines	series
transmit_gain	text	series
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

COPY exams_to_process (exam_uid, last_touched, modality, run_trial) FROM stdin;
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
MR	GE	Optima MR450w	23_LX_MR Software release:DV23.0_V03_1248.a	1	50
MR	Siemens	Verio	syngo MR B17	10	40
MR	Siemens	Skyra	syngo MR D11	10	42
MR	GE	SIGNA HDx	14_LX_MR Software release:14.0_M5_0737.f	1	24848
MR	GE Medical Systems	Signa HDxt	15_LX_MR Software release:15.0_M4_0910.a	1	57370
CR	Fuji	5000	A18	3	25275
CR	Fuji	5501ES	A07	3	25436
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
MR	GE	Signa HDxt	24_MX_MR Software release:HD16.0_V02_1131.a	1	52
MR	GE	Optima MR450w	23_MX_MR Software release:DV23.0_V03_1248.a	1	55
PACS	GE	Centricity Radiology RA 1000	2062264-017	11	56
MR	GE	DISCOVERY MR750	23_LX_MR Software release:DV22.0_V02_1122.a	1	41
MR	GE	Optima MR450w	23_LX_MR Software release:DV23.1_V02_1317.c	1	65
MR	GE	Optima MR450w	23_MX_MR Software release:DV22.1_V01_1131.a	1	57
CT	Siemens	SOMATOM Definition AS+	syngo CT 2012B	2	58
MR	GE	Signa HDxt	15_LX_MR Software release:15.0_M4A_0947.a	1	60
MR	GE	DISCOVERY MR750w	23_LX_MR Software release:DV23.1_V01_1248.a	1	67
MR	Siemens	Skyra	syngo MR D13	10	66
CR	Philips	PCR Eleva	1.2.1.SP1_PMS1.1.1 XRG GXRIM4.0	5	59
CT	Siemens	SOMATOM Definition Flash	syngo CT 2012B	2	68
DR	Carestream	DRX-1	5.3.607.6	12	69
CT	GE	LightSpeed RT16	qin.3	14	71
DR	GE	Discovery RX	41.04	4	75
DR	GE	Thunder Platform	DM_Platform_Magic_Release_Patch_1-4.3-2	4	25411
CT	Siemens	SOMATOM Definition	syngo CT 2010A	2	76
CT	Siemens	Sensation Open	syngo CT 2009E	2	77
MR	GE	FILMER_3.0	23_LX_MR Software release:DV22.1_V01_1131.a	1	78
MR	GE	DISCOVERY MR450	23_MX_MR Software release:DV22.0_V02_1122.a	1	79
CT	GE	LightSpeed16	07MW11.10	14	80
CT	Philips	BrightView	BrightViewXCTV2.5	15	81
CT	GE	Discovery CT590 RT	qin.3	14	82
CT	Siemens	Optima CT660	12HW28.8	2	109
3D	Terarecon	Aquilion	V4.51ER013	15	89
3D	Terarecon	Aquilion	V3.20ER012	15	90
NM	GE	INFINIA 	2.105.030.10	16	91
DR	GE	DRX-1	5.6.617.3	4	92
DR	GE	DRX-1	5.6.617.29	4	96
MR	GE	DISCOVERY MR750w 	24_LX_MR Software release:DV24.0_R01_1344.a	1	97
MR	GE	DISCOVERY MR750	23_MX_MR Software release:DV22.0_V02_1122.a	1	98
MR	Siemens	Aera	syngo MR D13	10	101
MR	GE	DICOVERY MR750w	23_MX_MR Software release:DV23.1_V01_1248.a	1	99
MR	GE	DISCOVERY MR750w	24_MX_MR Software release:DV24.0_R01_1344.a	1	100
XA	Siemens	Fluorospot Compact FD	VF85B	8	102
MR	GE	DISCOVERY MR750w	23_MX_MR Software release:DV23.1_V01_1248.a	1	103
MR	GE	Optima MR450w	24_LX_MR Software release:DV24.0_R01_1344.a	1	104
PET-CT	GE	Discovery RX	dm09_hl2sp1.23	13	87
PET-CT	GE	Discovery 690	PDR_PDR_1.05-1o	13	88
PET-CT	GE	Discovery 690	Tomografixx 1.5.3	13	94
CT	Siemens	SOMATOM Definition AS	syngo CT 2013B	2	105
CT	GE	LightSpeed QX/i	LightSpeedApps10.5_2.8.2I_H1.3M4	14	106
DR	GE	' '	DR-ID 300CL APL Software V7.3.0007	4	111
CT	Siemens	Sensation 40	syngo CT 2009E	2	112
PET-CT	GE	Discovery 710	pet_coreload.44	13	113
PET-CT	GE	Discovery 710	pet_coreload.44	13	115
MR	Siemens	Aera	syngo MR D11	10	117
CT	GE	LightSpeed VCT	gmp_vct.42	14	83
CT	GE	HiSpeed CT/i	 	14	108
MR	GE	Optima MR450w	24_MX_MR Software release:DV24.0_R01_1344.a	1	119
MR	GE	DISCOVERY MR450	24_LX_MR Software release:DV24.0_R01_1344.a	1	120
PET-CT	GE	Discovery 690	52.00	13	70
PET-CT	GE	Discovery 690	pet_mict_plus.44	13	74
\.


--
-- Data for Name: last_uids; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY last_uids (gateway, study, series, instance) FROM stdin;
mcr-dit2	1.2.840.113717.2.17703170.1	1.2.840.113619.2.5.202418181700.400.1421272392.627	1.2.840.113619.2.5.1203493.719.1421272392.630
mcr-dit	1.2.840.113717.2.17697638.1	1.2.840.114354.30013.2015.1.14.21.14.1.112.7952.7832	1.2.840.114354.30013.2015.1.14.21.14.1.112.7952.7832.17
\.


--
-- Data for Name: log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY log (caller, message, "time") FROM stdin;
ddw:purger	test	2015-01-21 07:48:57.373386-06
\.


--
-- Data for Name: mapped_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY mapped_values (std_name, dicom_grp_ele, version_id) FROM stdin;
sensitivity	tag00186000	25436
view_position	tag00185101	25436
relative_exposure	tag00181405	25436
photometric_interp	tag00280004	25436
win_center	tag00281050	25436
win_width	tag00281051	25436
dist_source_detector	tag00181110	25617
intercept	tag00281052	25436
slope	tag00281053	25436
lut_descrip	tag00283010	25436
processing_descrip	tag00181400	30
processing_code	tag00181401	30
sensitivity	tag00186000	30
view_position	tag00185101	30
relative_exposure	tag00181405	30
photometric_interp	tag00280004	30
win_center	tag00281050	30
win_width	tag00281051	30
intercept	tag00281052	30
slope	tag00281053	30
lut_descrip	tag00283010	30
processing_descrip	tag00181400	25275
processing_code	tag00181401	25275
sensitivity	tag00186000	25275
sensitivity	tag00186000	25314
processing_code	tag00181401	25314
processing_descrip	tag00181400	25314
processing_descrip	tag00181400	35
sensitivity	tag00186000	25411
kvp	tag00180060	25411
exposure_time	tag00181150	25411
tube_current	tag00181151	25411
filter_type	tag00181160	25411
dap	tag0018115E	25411
detector_type	tag00187004	25411
view_position	tag00185101	25411
processing_code	tag00181401	35
sensitivity	tag00186000	35
processing_description	tag00181400	25411
view_position	tag00185101	35
relative_exposure	tag00181405	35
dist_source_isocenter	tag00181111	25617
exposure_time	tag00181150	25617
tube_current	tag00181151	25617
instance_exposure	tag00181152	25411
instance_exposure	tag00181152	25617
compression_force	tag001811A2	25617
focal_spot	tag00181190	25617
view_position	tag00185101	25617
photometric_interp	tag00280004	35
win_center	tag00281050	35
win_width	tag00281051	35
intercept	tag00281052	35
slope	tag00281053	35
lut_descrip	tag00283010	35
slice_thickness	tag00180050	23
dist_source_detect	tag00181110	23
dist_source_isocenter	tag00181111	23
tube_current	tag00181151	23
exposure_time	tag00181150	23
recon_fov	tag00180090	23
filter_type	tag00181160	23
gen_power	tag00181170	23
focal_spot	tag00181190	23
tube_voltage	tag00180060	23
processing_descrip	tag00181400	25436
processing_code	tag00181401	25436
dist_source_detect	tag00181110	83
dist_source_isocenter	tag00181111	83
exposure_time	tag00181150	83
filter_type	tag00181160	83
tube_current	tag00181151	83
tube_voltage	tag00180060	83
image_orientation	tag00200037	83
dose_SR	tag0040A730	71
dose_SR	tag0040A730	108
contrast_agent	tag00180010	108
dist_source_detect	tag00181110	108
dist_source_isocenter	tag00181111	108
exposure_time	tag00181150	108
filter_type	tag00181160	108
tube_current	tag00181151	108
sensitivity	tag00186000	13
processing_code	tag00181401	13
processing_descrip	tag00181400	13
sensitivity	tag00186000	14
processing_code	tag00181401	14
processing_descrip	tag00181400	14
procedure_code_seq	tag00081032	15
tube_voltage	tag00180060	108
image_orientation	tag00200037	108
primary_angle	tag00181510	21
secondary_angle	tag00181511	21
shutter_shape	tag00181600	21
photometric_interp	tag00280004	29
win_width	tag00281051	29
win_center	tag00281050	29
intercept	tag00281052	29
slope	tag00281053	29
lut_descrip	tag00283010	29
dose_SR	tag0040A730	87
contrast_agent	tag00180010	87
dist_source_detect	tag00181110	87
dist_source_isocenter	tag00181111	87
tube_current	tag00181151	87
tube_voltage	tag00180060	87
image_orientation	tag00200037	87
dose_SR	tag0040A730	88
contrast_agent	tag00180010	88
dist_source_detect	tag00181110	88
dist_source_isocenter	tag00181111	88
tube_current	tag00181151	88
tube_voltage	tag00180060	88
image_orientation	tag00200037	88
siemens_MR_shadow	tag00291020	40
dose_SR	tag0040A730	94
contrast_agent	tag00180010	94
dist_source_detect	tag00181110	94
dist_source_isocenter	tag00181111	94
tube_current	tag00181151	94
tube_voltage	tag00180060	94
image_orientation	tag00200037	94
dose_SR	tag0040A730	113
contrast_agent	tag00180010	113
dist_source_detect	tag00181110	113
dist_source_isocenter	tag00181111	113
tube_current	tag00181151	113
tube_voltage	tag00180060	113
image_orientation	tag00200037	113
dose_SR	tag0040A730	115
contrast_agent	tag00180010	115
dist_source_detect	tag00181110	115
dist_source_isocenter	tag00181111	115
tube_current	tag00181151	115
tube_voltage	tag00180060	115
image_orientation	tag00200037	115
dose_SR	tag0040A730	74
contrast_agent	tag00180010	74
dist_source_detect	tag00181110	74
dist_source_isocenter	tag00181111	74
tube_current	tag00181151	74
tube_voltage	tag00180060	74
image_orientation	tag00200037	74
dose_SR	tag0040A730	80
contrast_agent	tag00180010	80
dist_source_detect	tag00181110	80
dist_source_isocenter	tag00181111	80
exposure_time	tag00181150	80
filter_type	tag00181160	80
tube_current	tag00181151	80
tube_voltage	tag00180060	80
image_orientation	tag00200037	80
dose_SR	tag0040A730	82
contrast_agent	tag00180010	82
dist_source_detect	tag00181110	82
weight	tag00101030	40
dist_source_isocenter	tag00181111	82
exposure_time	tag00181150	82
filter_type	tag00181160	82
tube_current	tag00181151	82
tube_voltage	tag00180060	82
image_orientation	tag00200037	82
dose_SR	tag0040A730	106
contrast_agent	tag00180010	106
dist_source_detect	tag00181110	106
dist_source_isocenter	tag00181111	106
exposure_time	tag00181150	106
filter_type	tag00181160	106
tube_current	tag00181151	106
tube_voltage	tag00180060	106
image_orientation	tag00200037	106
dose_SR	tag0040A730	83
contrast_agent	tag00180010	83
contrast_agent	tag00180010	76
image_orientation	tag00200037	76
slice_thickness	tag00180050	77
dist_source_detect	tag00181110	77
dist_source_isocenter	tag00181111	77
tube_current	tag00181151	77
exposure_time	tag00181150	77
recon_fov	tag00180090	77
filter_type	tag00181160	77
gen_power	tag00181170	77
focal_spot	tag00181190	77
tube_voltage	tag00180060	77
dose_SR	tag0040A730	77
series_exposure	tag00181152	77
contrast_agent	tag00180010	77
image_orientation	tag00200037	77
slice_thickness	tag00180050	109
dist_source_detect	tag00181110	109
sensitivity	tag00186000	75
kvp	tag00180060	75
exposure_time	tag00181150	75
tube_current	tag00181151	75
filter_type	tag00181160	75
dap	tag0018115E	75
detector_type	tag00187004	75
view_position	tag00185101	75
processing_description	tag00181400	75
instance_exposure	tag00181152	75
dist_source_isocenter	tag00181111	109
SAR	tag00181316	57730
tube_current	tag00181151	109
exposure_time	tag00181150	109
recon_fov	tag00180090	109
filter_type	tag00181160	109
gen_power	tag00181170	109
focal_spot	tag00181190	109
tube_voltage	tag00180060	109
dose_SR	tag0040A730	109
series_exposure	tag00181152	109
contrast_agent	tag00180010	109
image_orientation	tag00200037	109
slice_thickness	tag00180050	105
echo_time	tag00180081	40
dist_source_detect	tag00181110	105
dist_source_isocenter	tag00181111	105
tube_current	tag00181151	105
exposure_time	tag00181150	105
recon_fov	tag00180090	105
filter_type	tag00181160	105
gen_power	tag00181170	105
focal_spot	tag00181190	105
tube_voltage	tag00180060	105
dose_SR	tag0040A730	105
series_exposure	tag00181152	105
contrast_agent	tag00180010	105
image_orientation	tag00200037	105
slice_thickness	tag00180050	112
dist_source_detect	tag00181110	112
dist_source_isocenter	tag00181111	112
tube_current	tag00181151	112
exposure_time	tag00181150	112
recon_fov	tag00180090	112
filter_type	tag00181160	112
gen_power	tag00181170	112
focal_spot	tag00181190	112
tube_voltage	tag00180060	112
dose_SR	tag0040A730	112
series_exposure	tag00181152	112
repetition_time	tag00180080	40
contrast_agent	tag00180010	112
image_orientation	tag00200037	112
SAR	tag00181316	40
weight	tag00101030	120
SAR	tag00181316	120
contrast_agent	tag00180010	120
image_orientation	tag00200037	120
slice_thickness	tag00180050	25236
dist_source_detect	tag00181110	25236
dist_source_isocenter	tag00181111	25236
tube_current	tag00181151	25236
exposure_time	tag00181150	25236
recon_fov	tag00180090	25236
filter_type	tag00181160	25236
gen_power	tag00181170	25236
focal_spot	tag00181190	25236
tube_voltage	tag00180060	25236
dose_SR	tag0040A730	25236
series_exposure	tag00181152	25236
contrast_agent	tag00180010	25236
image_orientation	tag00200037	25236
slice_thickness	tag00180050	41120
dist_source_detect	tag00181110	41120
dist_source_isocenter	tag00181111	41120
tube_current	tag00181151	41120
exposure_time	tag00181150	41120
recon_fov	tag00180090	41120
filter_type	tag00181160	41120
gen_power	tag00181170	41120
focal_spot	tag00181190	41120
tube_voltage	tag00180060	41120
dose_SR	tag0040A730	41120
series_exposure	tag00181152	41120
contrast_agent	tag00180010	41120
image_orientation	tag00200037	41120
slice_thickness	tag00180050	24873
dist_source_detect	tag00181110	24873
dist_source_isocenter	tag00181111	24873
tube_current	tag00181151	24873
exposure_time	tag00181150	24873
recon_fov	tag00180090	24873
filter_type	tag00181160	24873
gen_power	tag00181170	24873
focal_spot	tag00181190	24873
tube_voltage	tag00180060	24873
dose_SR	tag0040A730	24873
series_exposure	tag00181152	24873
contrast_agent	tag00180010	24873
image_orientation	tag00200037	24873
slice_thickness	tag00180050	28
dist_source_detect	tag00181110	28
dist_source_isocenter	tag00181111	28
tube_current	tag00181151	28
exposure_time	tag00181150	28
recon_fov	tag00180090	28
filter_type	tag00181160	28
gen_power	tag00181170	28
focal_spot	tag00181190	28
tube_voltage	tag00180060	28
dose_SR	tag0040A730	28
series_exposure	tag00181152	28
contrast_agent	tag00180010	28
image_orientation	tag00200037	28
slice_thickness	tag00180050	58
image_freq	tag00180084	18
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
weight	tag00101030	18
SAR	tag00181316	18
contrast_agent	tag00180010	18
dist_source_detect	tag00181110	58
dist_source_isocenter	tag00181111	58
tube_current	tag00181151	58
exposure_time	tag00181150	58
recon_fov	tag00180090	58
filter_type	tag00181160	58
gen_power	tag00181170	58
focal_spot	tag00181190	58
tube_voltage	tag00180060	58
dose_SR	tag0040A730	58
series_exposure	tag00181152	58
image_freq	tag00180084	24848
contrast_agent	tag00180010	58
image_orientation	tag00200037	58
flip_angle	tag00181340	40
slice_thickness	tag00180050	68
image_freq	tag00180084	40
slice_thickness	tag00180050	40
field_strength	tag00180087	40
interslice_space	tag00180088	40
dist_source_detect	tag00181110	68
dist_source_isocenter	tag00181111	68
tube_current	tag00181151	68
exposure_time	tag00181150	68
recon_fov	tag00180090	68
filter_type	tag00181160	68
gen_power	tag00181170	68
focal_spot	tag00181190	68
tube_voltage	tag00180060	68
dose_SR	tag0040A730	68
series_exposure	tag00181152	68
contrast_agent	tag00180010	68
image_orientation	tag00200037	68
slice_thickness	tag00180050	76
dist_source_detect	tag00181110	76
dist_source_isocenter	tag00181111	76
tube_current	tag00181151	76
exposure_time	tag00181150	76
recon_fov	tag00180090	76
filter_type	tag00181160	76
gen_power	tag00181170	76
focal_spot	tag00181190	76
tube_voltage	tag00180060	76
dose_SR	tag0040A730	76
series_exposure	tag00181152	76
contrast_agent	tag00180010	97
image_orientation	tag00200037	97
image_freq	tag00180084	98
slice_thickness	tag00180050	98
field_strength	tag00180087	98
interslice_space	tag00180088	98
flip_angle	tag00181314	98
echo_time	tag00180081	98
repetition_time	tag00180080	98
inversion_time	tag00180082	98
acquisition_type	tag00180023	98
coil	tag00181250	98
pulse_seq	tag0019109C	98
weight	tag00101030	98
SAR	tag00181316	98
contrast_agent	tag00180010	98
image_orientation	tag00200037	98
image_freq	tag00180084	99
slice_thickness	tag00180050	99
field_strength	tag00180087	99
interslice_space	tag00180088	99
flip_angle	tag00181314	99
echo_time	tag00180081	99
repetition_time	tag00180080	99
inversion_time	tag00180082	99
acquisition_type	tag00180023	99
coil	tag00181250	99
pulse_seq	tag0019109C	99
weight	tag00101030	99
SAR	tag00181316	99
contrast_agent	tag00180010	99
image_orientation	tag00200037	99
image_freq	tag00180084	100
slice_thickness	tag00180050	100
field_strength	tag00180087	100
interslice_space	tag00180088	100
flip_angle	tag00181314	100
echo_time	tag00180081	100
repetition_time	tag00180080	100
inversion_time	tag00180082	100
acquisition_type	tag00180023	100
coil	tag00181250	100
pulse_seq	tag0019109C	100
weight	tag00101030	100
SAR	tag00181316	100
contrast_agent	tag00180010	100
dose_SR	tag0040A730	23
image_orientation	tag00200037	100
image_freq	tag00180084	103
slice_thickness	tag00180050	103
field_strength	tag00180087	103
interslice_space	tag00180088	103
flip_angle	tag00181314	103
echo_time	tag00180081	103
repetition_time	tag00180080	103
inversion_time	tag00180082	103
acquisition_type	tag00180023	103
coil	tag00181250	103
pulse_seq	tag0019109C	103
weight	tag00101030	103
SAR	tag00181316	103
contrast_agent	tag00180010	103
image_orientation	tag00200037	103
image_freq	tag00180084	104
slice_thickness	tag00180050	104
field_strength	tag00180087	104
interslice_space	tag00180088	104
flip_angle	tag00181314	104
echo_time	tag00180081	104
repetition_time	tag00180080	104
inversion_time	tag00180082	104
acquisition_type	tag00180023	104
coil	tag00181250	104
pulse_seq	tag0019109C	104
weight	tag00101030	104
SAR	tag00181316	104
contrast_agent	tag00180010	104
image_orientation	tag00200037	104
image_freq	tag00180084	119
slice_thickness	tag00180050	119
field_strength	tag00180087	119
interslice_space	tag00180088	119
flip_angle	tag00181314	119
echo_time	tag00180081	119
repetition_time	tag00180080	119
inversion_time	tag00180082	119
acquisition_type	tag00180023	119
coil	tag00181250	119
pulse_seq	tag0019109C	119
weight	tag00101030	119
SAR	tag00181316	119
contrast_agent	tag00180010	119
image_orientation	tag00200037	119
image_freq	tag00180084	120
slice_thickness	tag00180050	120
field_strength	tag00180087	120
interslice_space	tag00180088	120
flip_angle	tag00181314	120
echo_time	tag00180081	120
repetition_time	tag00180080	120
inversion_time	tag00180082	120
acquisition_type	tag00180023	120
coil	tag00181250	120
pulse_seq	tag0019109C	120
image_freq	tag00180084	65
slice_thickness	tag00180050	65
field_strength	tag00180087	65
interslice_space	tag00180088	65
flip_angle	tag00181314	65
echo_time	tag00180081	65
repetition_time	tag00180080	65
inversion_time	tag00180082	65
acquisition_type	tag00180023	65
coil	tag00181250	65
pulse_seq	tag0019109C	65
weight	tag00101030	65
SAR	tag00181316	65
contrast_agent	tag00180010	65
image_orientation	tag00200037	65
image_freq	tag00180084	57
slice_thickness	tag00180050	57
field_strength	tag00180087	57
interslice_space	tag00180088	57
flip_angle	tag00181314	57
echo_time	tag00180081	57
repetition_time	tag00180080	57
inversion_time	tag00180082	57
acquisition_type	tag00180023	57
coil	tag00181250	57
pulse_seq	tag0019109C	57
weight	tag00101030	57
SAR	tag00181316	57
contrast_agent	tag00180010	57
image_orientation	tag00200037	57
image_freq	tag00180084	60
slice_thickness	tag00180050	60
field_strength	tag00180087	60
interslice_space	tag00180088	60
flip_angle	tag00181314	60
echo_time	tag00180081	60
repetition_time	tag00180080	60
inversion_time	tag00180082	60
acquisition_type	tag00180023	60
coil	tag00181250	60
pulse_seq	tag0019109C	60
weight	tag00101030	60
SAR	tag00181316	60
contrast_agent	tag00180010	60
image_orientation	tag00200037	60
image_freq	tag00180084	67
slice_thickness	tag00180050	67
field_strength	tag00180087	67
interslice_space	tag00180088	67
flip_angle	tag00181314	67
echo_time	tag00180081	67
repetition_time	tag00180080	67
inversion_time	tag00180082	67
view_position	tag00185101	25275
relative_exposure	tag00181405	25275
photometric_interp	tag00280004	25275
win_center	tag00281050	25275
win_width	tag00281051	25275
intercept	tag00281052	25275
slope	tag00281053	25275
lut_descrip	tag00283010	25275
series_exposure	tag00181152	23
contrast_agent	tag00180010	40
acquisition_type	tag00180023	67
coil	tag00181250	67
pulse_seq	tag0019109C	67
weight	tag00101030	67
SAR	tag00181316	67
contrast_agent	tag00180010	67
dose_SR	tag0040A730	70
image_orientation	tag00200037	67
image_freq	tag00180084	78
slice_thickness	tag00180050	78
field_strength	tag00180087	78
interslice_space	tag00180088	78
flip_angle	tag00181314	78
echo_time	tag00180081	78
repetition_time	tag00180080	78
inversion_time	tag00180082	78
acquisition_type	tag00180023	78
coil	tag00181250	78
pulse_seq	tag0019109C	78
weight	tag00101030	78
SAR	tag00181316	78
contrast_agent	tag00180010	78
image_orientation	tag00200037	78
image_freq	tag00180084	79
slice_thickness	tag00180050	79
field_strength	tag00180087	79
interslice_space	tag00180088	79
flip_angle	tag00181314	79
echo_time	tag00180081	79
repetition_time	tag00180080	79
inversion_time	tag00180082	79
acquisition_type	tag00180023	79
coil	tag00181250	79
pulse_seq	tag0019109C	79
weight	tag00101030	79
SAR	tag00181316	79
contrast_agent	tag00180010	79
image_orientation	tag00200037	79
image_freq	tag00180084	97
slice_thickness	tag00180050	97
field_strength	tag00180087	97
interslice_space	tag00180088	97
flip_angle	tag00181314	97
echo_time	tag00180081	97
repetition_time	tag00180080	97
inversion_time	tag00180082	97
acquisition_type	tag00180023	97
coil	tag00181250	97
pulse_seq	tag0019109C	97
weight	tag00101030	97
SAR	tag00181316	97
field_strength	tag00180087	48
interslice_space	tag00180088	48
flip_angle	tag00181314	48
echo_time	tag00180081	48
repetition_time	tag00180080	48
inversion_time	tag00180082	48
acquisition_type	tag00180023	48
coil	tag00181250	48
pulse_seq	tag0019109C	48
weight	tag00101030	48
SAR	tag00181316	48
contrast_agent	tag00180010	71
dist_source_detect	tag00181110	71
dist_source_isocenter	tag00181111	71
exposure_time	tag00181150	71
filter_type	tag00181160	71
tube_current	tag00181151	71
tube_voltage	tag00180060	71
contrast_agent	tag00180010	70
dist_source_detect	tag00181110	70
dist_source_isocenter	tag00181111	70
tube_current	tag00181151	70
tube_voltage	tag00180060	70
contrast_agent	tag00180010	48
image_orientation	tag00200037	48
image_freq	tag00180084	49
slice_thickness	tag00180050	49
field_strength	tag00180087	49
interslice_space	tag00180088	49
flip_angle	tag00181314	49
echo_time	tag00180081	49
repetition_time	tag00180080	49
inversion_time	tag00180082	49
acquisition_type	tag00180023	49
coil	tag00181250	49
pulse_seq	tag0019109C	49
weight	tag00101030	49
SAR	tag00181316	49
contrast_agent	tag00180010	49
image_orientation	tag00200037	49
image_freq	tag00180084	25
slice_thickness	tag00180050	25
field_strength	tag00180087	25
interslice_space	tag00180088	25
flip_angle	tag00181314	25
echo_time	tag00180081	25
repetition_time	tag00180080	25
inversion_time	tag00180082	25
acquisition_type	tag00180023	25
coil	tag00181250	25
pulse_seq	tag0019109C	25
weight	tag00101030	25
SAR	tag00181316	25
contrast_agent	tag00180010	25
image_orientation	tag00200037	25
image_freq	tag00180084	26
slice_thickness	tag00180050	26
field_strength	tag00180087	26
interslice_space	tag00180088	26
flip_angle	tag00181314	26
echo_time	tag00180081	26
repetition_time	tag00180080	26
inversion_time	tag00180082	26
acquisition_type	tag00180023	26
coil	tag00181250	26
pulse_seq	tag0019109C	26
weight	tag00101030	26
SAR	tag00181316	26
contrast_agent	tag00180010	26
image_orientation	tag00200037	26
image_freq	tag00180084	52
slice_thickness	tag00180050	52
field_strength	tag00180087	52
interslice_space	tag00180088	52
flip_angle	tag00181314	52
echo_time	tag00180081	52
repetition_time	tag00180080	52
inversion_time	tag00180082	52
acquisition_type	tag00180023	52
coil	tag00181250	52
pulse_seq	tag0019109C	52
weight	tag00101030	52
SAR	tag00181316	52
contrast_agent	tag00180010	52
image_orientation	tag00200037	52
image_freq	tag00180084	55
slice_thickness	tag00180050	55
field_strength	tag00180087	55
interslice_space	tag00180088	55
flip_angle	tag00181314	55
echo_time	tag00180081	55
repetition_time	tag00180080	55
inversion_time	tag00180082	55
acquisition_type	tag00180023	55
coil	tag00181250	55
pulse_seq	tag0019109C	55
weight	tag00101030	55
SAR	tag00181316	55
contrast_agent	tag00180010	55
image_orientation	tag00200037	55
image_freq	tag00180084	41
slice_thickness	tag00180050	41
field_strength	tag00180087	41
interslice_space	tag00180088	41
flip_angle	tag00181314	41
echo_time	tag00180081	41
repetition_time	tag00180080	41
inversion_time	tag00180082	41
acquisition_type	tag00180023	41
coil	tag00181250	41
pulse_seq	tag0019109C	41
weight	tag00101030	41
SAR	tag00181316	41
contrast_agent	tag00180010	41
image_orientation	tag00200037	41
flip_angle	tag00181314	36
echo_time	tag00180081	36
repetition_time	tag00180080	36
inversion_time	tag00180082	36
acquisition_type	tag00180023	36
coil	tag00181250	36
pulse_seq	tag0019109C	36
weight	tag00101030	36
SAR	tag00181316	36
contrast_agent	tag00180010	36
image_orientation	tag00200037	36
image_freq	tag00180084	39
slice_thickness	tag00180050	39
field_strength	tag00180087	39
interslice_space	tag00180088	39
flip_angle	tag00181314	39
echo_time	tag00180081	39
repetition_time	tag00180080	39
inversion_time	tag00180082	39
acquisition_type	tag00180023	39
coil	tag00181250	39
pulse_seq	tag0019109C	39
weight	tag00101030	39
SAR	tag00181316	39
contrast_agent	tag00180010	39
contrast_agent	tag00180010	23
image_orientation	tag00200037	39
image_freq	tag00180084	50
slice_thickness	tag00180050	50
field_strength	tag00180087	50
interslice_space	tag00180088	50
flip_angle	tag00181314	50
echo_time	tag00180081	50
image_orientation	tag00200037	18
image_orientation	tag00200037	23
image_orientation	tag00200037	40
image_orientation	tag00200037	70
image_orientation	tag00200037	71
image_freq	tag00180084	36
slice_thickness	tag00180050	36
field_strength	tag00180087	36
interslice_space	tag00180088	36
repetition_time	tag00180080	50
inversion_time	tag00180082	50
transmit_gain	tag0019105a	40
siemens_MR_shadow	tag00291020	42
weight	tag00101030	42
echo_time	tag00180081	42
repetition_time	tag00180080	42
SAR	tag00181316	42
flip_angle	tag00181340	42
image_freq	tag00180084	42
slice_thickness	tag00180050	42
field_strength	tag00180087	42
interslice_space	tag00180088	42
contrast_agent	tag00180010	42
image_orientation	tag00200037	42
transmit_gain	tag0019105a	42
siemens_MR_shadow	tag00291020	43
weight	tag00101030	43
echo_time	tag00180081	43
repetition_time	tag00180080	43
SAR	tag00181316	43
flip_angle	tag00181340	43
image_freq	tag00180084	43
slice_thickness	tag00180050	43
field_strength	tag00180087	43
interslice_space	tag00180088	43
contrast_agent	tag00180010	43
image_orientation	tag00200037	43
transmit_gain	tag0019105a	43
siemens_MR_shadow	tag00291020	44
weight	tag00101030	44
echo_time	tag00180081	44
repetition_time	tag00180080	44
SAR	tag00181316	44
flip_angle	tag00181340	44
image_freq	tag00180084	44
acquisition_type	tag00180023	50
coil	tag00181250	50
pulse_seq	tag0019109C	50
weight	tag00101030	50
SAR	tag00181316	50
contrast_agent	tag00180010	50
image_orientation	tag00200037	50
slice_thickness	tag00180050	24848
field_strength	tag00180087	24848
interslice_space	tag00180088	24848
flip_angle	tag00181314	24848
echo_time	tag00180081	24848
repetition_time	tag00180080	24848
inversion_time	tag00180082	24848
acquisition_type	tag00180023	24848
coil	tag00181250	24848
pulse_seq	tag0019109C	24848
weight	tag00101030	24848
SAR	tag00181316	24848
contrast_agent	tag00180010	24848
image_orientation	tag00200037	24848
image_freq	tag00180084	57370
slice_thickness	tag00180050	57370
field_strength	tag00180087	57370
interslice_space	tag00180088	57370
flip_angle	tag00181314	57370
echo_time	tag00180081	57370
repetition_time	tag00180080	57370
inversion_time	tag00180082	57370
acquisition_type	tag00180023	57370
coil	tag00181250	57370
pulse_seq	tag0019109C	57370
weight	tag00101030	57370
SAR	tag00181316	57370
contrast_agent	tag00180010	57370
image_orientation	tag00200037	57370
image_freq	tag00180084	45
slice_thickness	tag00180050	45
field_strength	tag00180087	45
interslice_space	tag00180088	45
flip_angle	tag00181314	45
echo_time	tag00180081	45
repetition_time	tag00180080	45
inversion_time	tag00180082	45
acquisition_type	tag00180023	45
coil	tag00181250	45
pulse_seq	tag0019109C	45
weight	tag00101030	45
SAR	tag00181316	45
contrast_agent	tag00180010	45
image_orientation	tag00200037	45
image_freq	tag00180084	46
slice_thickness	tag00180050	46
field_strength	tag00180087	46
interslice_space	tag00180088	46
flip_angle	tag00181314	46
echo_time	tag00180081	46
repetition_time	tag00180080	46
inversion_time	tag00180082	46
acquisition_type	tag00180023	46
coil	tag00181250	46
pulse_seq	tag0019109C	46
weight	tag00101030	46
SAR	tag00181316	46
contrast_agent	tag00180010	46
image_orientation	tag00200037	46
image_freq	tag00180084	48
slice_thickness	tag00180050	48
slice_thickness	tag00180050	44
field_strength	tag00180087	44
interslice_space	tag00180088	44
contrast_agent	tag00180010	44
image_orientation	tag00200037	44
transmit_gain	tag0019105a	44
siemens_MR_shadow	tag00291020	66
weight	tag00101030	66
echo_time	tag00180081	66
repetition_time	tag00180080	66
SAR	tag00181316	66
flip_angle	tag00181340	66
image_freq	tag00180084	66
slice_thickness	tag00180050	66
field_strength	tag00180087	66
interslice_space	tag00180088	66
contrast_agent	tag00180010	66
image_orientation	tag00200037	66
transmit_gain	tag0019105a	66
siemens_MR_shadow	tag00291020	101
weight	tag00101030	101
echo_time	tag00180081	101
repetition_time	tag00180080	101
SAR	tag00181316	101
flip_angle	tag00181340	101
image_freq	tag00180084	101
slice_thickness	tag00180050	101
field_strength	tag00180087	101
interslice_space	tag00180088	101
contrast_agent	tag00180010	101
image_orientation	tag00200037	101
transmit_gain	tag0019105a	101
siemens_MR_shadow	tag00291020	117
weight	tag00101030	117
echo_time	tag00180081	117
repetition_time	tag00180080	117
SAR	tag00181316	117
flip_angle	tag00181340	117
image_freq	tag00180084	117
slice_thickness	tag00180050	117
field_strength	tag00180087	117
interslice_space	tag00180088	117
contrast_agent	tag00180010	117
image_orientation	tag00200037	117
transmit_gain	tag0019105a	117
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

COPY series (exam_uid, series_uid, station_id, aet, series_description, protocol_name, series_name, body_part, series_number, version_id, series_time, modality) FROM stdin;
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
-- Name: pk_gateway; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY last_uids
    ADD CONSTRAINT pk_gateway PRIMARY KEY (gateway);


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
-- Name: unique_acquisition_derived_values; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY acquisition_derived_values
    ADD CONSTRAINT unique_acquisition_derived_values UNIQUE (event_uid, std_name);


--
-- Name: unique_acquisition_mapped_values; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY acquisition_mapped_values
    ADD CONSTRAINT unique_acquisition_mapped_values UNIQUE (event_uid, std_name);


--
-- Name: unique_derived_values; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY derived_values
    ADD CONSTRAINT unique_derived_values UNIQUE (version_id, std_name);


--
-- Name: unique_dict_std_names; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dict_std_names
    ADD CONSTRAINT unique_dict_std_names UNIQUE (std_name, scope);


--
-- Name: unique_exams_derived_values; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY exams_derived_values
    ADD CONSTRAINT unique_exams_derived_values UNIQUE (exam_uid, std_name);


--
-- Name: unique_exams_mapped_values; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY exams_mapped_values
    ADD CONSTRAINT unique_exams_mapped_values UNIQUE (exam_uid, std_name);


--
-- Name: unique_instance_derived_values; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instance_derived_values
    ADD CONSTRAINT unique_instance_derived_values UNIQUE (instance_uid, std_name);


--
-- Name: unique_instance_mapped_values; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instance_mapped_values
    ADD CONSTRAINT unique_instance_mapped_values UNIQUE (instance_uid, std_name);


--
-- Name: unique_known_scanners; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY known_scanners
    ADD CONSTRAINT unique_known_scanners UNIQUE (vers, version_id);


--
-- Name: unique_mapped_values; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY mapped_values
    ADD CONSTRAINT unique_mapped_values UNIQUE (std_name, version_id);


--
-- Name: unique_series_derived_values; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY series_derived_values
    ADD CONSTRAINT unique_series_derived_values UNIQUE (series_uid, std_name);


--
-- Name: unique_series_mapped_values; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY series_mapped_values
    ADD CONSTRAINT unique_series_mapped_values UNIQUE (series_uid, std_name);


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

CREATE TRIGGER run_dispatcher BEFORE INSERT ON patient FOR EACH ROW EXECUTE PROCEDURE run_dispatcher();


--
-- Name: trunc_uid; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trunc_uid BEFORE INSERT ON alerts FOR EACH ROW EXECUTE PROCEDURE trunc_last_uid();


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

