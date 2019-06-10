---------------------- Bind Variable SQL testing harness  --------------------------------------------------------------------------------------
 
-- Instructions :
--
-- 1.  This script is intended to be used by DBAs fairly familiar with PL/SQL
--     For instance, you will need to add the number and type of bind variables
--     that your target SQL uses in the DECLARE section.  And then you will need to
--     update the DBMS_SQL.BIND_VARIABLE lines to match your bind variables..
-- 
-- I wrote this to work with SQL Developer, but it should work with SQLplus too.
--
-- Paul Stuart
 
VARIABLE sql_id_var        VARCHAR2(64);
VARIABLE sql_child_number_var  NUMBER;
VARIABLE sql_exec_var      NUMBER;
define MODULE_NAME=NEW01
set worksheetname run_&amp;MODULE_NAME
set serveroutput on
whenever sqlerror exit SQL.SQLCODE;
 
ALTER SESSION SET  statistics_level='ALL';
ALTER SESSION SET  nls_date_format='dd/mm/yyyy hh24:mi:ss';
--alter session set current_schema=XXX_YYY;
 
clear screen
 
DECLARE
 
       cursor_name      INTEGER;
       TYPE             ASSOC_ARRAY_T IS TABLE OF INTEGER  INDEX BY VARCHAR2(256);
       StatArray        ASSOC_ARRAY_T;
       l_index          VARCHAR2(256);
       total_fetches    INTEGER;
       sql_text_string  CLOB;
       hints            SYS.SQLPROF_ATTR;
       ret              INTEGER;
       sql_id_cur      SYS_REFCURSOR;
 
 
-------------- Insert the Bind Variables here ---------------------------------
 
--B1  VARCHAR(32) := '20130531';    
--B2 NUMBER:=28287;       
--B3  VARCHAR(32) := 'n1' ;
 
BEGIN
 
-- Use these two lines if you wish to get the sql text from a particular SQL_ID
 
--OPEN sql_id_cur  FOR q'#select sql_text from dba_hist_sqltext where sql_id = 'SQL_ID' #';
--FETCH sql_id_cur INTO sql_text_string;
 
sql_text_string  := q'#
select count(*) from gv$session
#';
 
sql_text_string := sql_text_string || ' /* &amp;MODULE_NAME */ ';
                                
dbms_output.put_line('SQL Text =&gt; ' || sql_text_string);
 
----------------- load the stats  ------------------------------------------------
 
FOR r IN (select SN.name, SS.value FROM v$mystat SS, v$statname SN WHERE SS.statistic# = SN.statistic#) 
  LOOP
     --dbms_output.put_line('loading ' || r.name );
    StatArray(r.name) := r.value;
  END LOOP;
 
 
----------------- now execute the SQL ------------------------------------------------
 
DBMS_APPLICATION_INFO.set_client_info('&amp;MODULE_NAME'); 
 
cursor_name := DBMS_SQL.OPEN_CURSOR;
 
DBMS_SQL.PARSE(cursor_name, sql_text_string, DBMS_SQL.NATIVE);
 
/*
DBMS_SQL.BIND_VARIABLE_CHAR(cursor_name,      ':1', B1 );
DBMS_SQL.BIND_VARIABLE(cursor_name,           ':2', B2 );
DBMS_SQL.BIND_VARIABLE_CHAR(cursor_name,      ':3', B3 );
*/
 
ret := DBMS_SQL.EXECUTE(cursor_name);
 
total_fetches := 0;
 
LOOP                                        
  ret := DBMS_SQL.FETCH_ROWS(cursor_name);
  EXIT WHEN ret = 0;
  total_fetches := total_fetches + 1;
END LOOP;
 
 
DBMS_APPLICATION_INFO.set_client_info('');
 
-------------Now get the SQL_ID and Child Number for the statement --------------------
 
 
SELECT   PREV_SQL_ID, PREV_EXEC_ID, PREV_CHILD_NUMBER INTO :sql_id_var, :sql_exec_var, :sql_child_number_var 
  FROM v$session V
  inner join v$sql S on S.sql_id = V.prev_sql_id
  WHERE SID =  (SELECT dbms_debug_jdwp.current_session_id from dual )
  AND serial# = (select dbms_debug_jdwp.current_session_serial from dual) 
  and parsing_schema_name = user ;
 
DBMS_OUTPUT.PUT_LINE( chr(10) || 'fetched : ' || total_fetches || ' rows. '|| chr(10) );
   
DBMS_SQL.CLOSE_CURSOR(cursor_name);
 
----------------- now output the stats ------------------------------------------------
 
DBMS_OUTPUT.PUT_LINE(chr(10) || 'Stats : ' || chr(10) );
 
FOR r IN (select SN.name, SS.value FROM v$mystat SS, v$statname SN WHERE SS.statistic# = SN.statistic#) 
  LOOP
    -- dbms_output.put_line('modifying ' || r.name || ' before ' || StatArray(r.name) || ' after ' || after );
    StatArray(r.name) :=  r.value - StatArray(r.name) ;
  END LOOP;
 
  -- now print out the array :
l_index := StatArray.FIRST;
WHILE (l_index is not null)
LOOP
    IF ( StatArray(l_index) != 0  )
    THEN
      dbms_output.put_line( RPAD( l_index ,50,' ' )  || ' ' || StatArray(l_index) );
    END IF;
    l_index := StatArray.NEXT(l_index);
END LOOP;
----------------------------------------------------------------------------------------
 
 
END;
/
 
-------------------- Now get the execution plan ----------------------------------------
 
COLUMN INPUT_ARG NEW_VALUE ARG noprint
 
SELECT '''' || :SQL_ID_VAR || ''',' ||  :sql_child_number_var ||  ',''ADVANCED'' ' AS INPUT_ARG FROM dual;
 
select * from table( dbms_xplan.display_cursor( &amp;ARG  ) );
 
----------------------- end of code  -----------------------------------------------------------
