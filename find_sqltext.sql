----------------------- settings and config section --------------------------------------------------------------------------------------
 
-- Instructions :
--
-- 1. use the sqlplus variables below to control how you want the script to search for SQL text
-- 2.  place the snippet of sql text in the TargetSQL CLOB below.  The text can contain any characters, including quotes and newlines
-- 3.  Execute the script.
-- 
-- I wrote this to work with SQL Developer, but it should work with SQLplus too.
--
-- Paul Stuart
 
/* 
   CRE TAB      1
   INSERT       2
   SELECT =     3
   UPDATE       6
   DELETE       7
   CRE INDEX    9
   DDL          42
   PL/SQL EXEC 47
   ANALYZE TAB 62
   ANALYZE IDX 63
*/
define COMMAND_TYPE=3
define DAYS_AGO=35
define SEARCH_CURSORCACHE=0
define SEARCH_AWR=1
 
set verify off;
set serveroutput on;
 
 
--------------------------- code begins here ------------------------------------------------------------------------------------------------
 
CLEAR screen
prompt COMMAND_TYPE : &amp;COMMAND_TYPE
prompt DAYS_AGO : &amp;DAYS_AGO
prompt SEARCH_CURSORCACHE : &amp;SEARCH_CURSORCACHE
prompt SEARCH_AWR :  &amp;SEARCH_AWR
prompt
 
-- this section does some quick counting to see what is to be searched :
 
DECLARE
   iCount INTEGER;
 
BEGIN
 
  IF ( &amp;SEARCH_AWR = 1 )
  THEN
    SELECT COUNT(sql_id) into iCount 
              FROM dba_hist_sqltext WHERE command_type = &amp;COMMAND_TYPE
              AND sql_id IN (SELECT DISTINCT sql_id FROM  dba_hist_sqlstat
              WHERE snap_id &gt; (  SELECT min(snap_id) FROM dba_hist_snapshot WHERE trunc(begin_interval_time, 'DD')  &gt;  trunc(SYSDATE - &amp;DAYS_AGO, 'DD')));
 
    dbms_output.put_line('There are ' || iCount || ' sql to be searched in the AWR.' );
  end if;
 
  IF ( &amp;SEARCH_CURSORCACHE = 1)
  THEN
    SELECT count(sql_id) into iCount FROM gv$sqlarea WHERE command_type = &amp;COMMAND_TYPE;
    dbms_output.put_line('There are ' || iCount || ' sql to be searched in the cursor cache.' );
  END IF;
 
END;
/
 
-- now do the actual searching 
 
prompt Beginning search now :
set timing on
 
DECLARE
 
  TargetSQL CLOB  := q'#
SELECT .... etc, etc, etc
#';
 
  TestSQL CLOB;
  iTest   INTEGER;
 
CURSOR sqltext_cur 
    IS
    SELECT sql_id, UPPER(REPLACE(REPLACE(REPLACE(REPLACE(sql_text, CHR(10)), CHR(13)), CHR(9)), CHR(32)) ) as sql_text2  FROM dba_hist_sqltext WHERE command_type = &amp;COMMAND_TYPE
              AND sql_id IN (SELECT DISTINCT sql_id FROM  dba_hist_sqlstat
              WHERE snap_id &gt; (  SELECT min(snap_id) FROM dba_hist_snapshot WHERE trunc(begin_interval_time, 'DD')  &gt;  trunc(SYSDATE - &amp;DAYS_AGO, 'DD')));
 
CURSOR sqltext_cur2
    IS
       SELECT sql_id, UPPER(REPLACE(REPLACE(REPLACE(REPLACE(sql_fulltext, CHR(10)), CHR(13)), CHR(9)), CHR(32)) ) as sql_text2  FROM gv$sqlarea WHERE command_type = &amp;COMMAND_TYPE;
 
    TYPE employees_aat IS TABLE OF sqltext_cur%ROWTYPE
        INDEX BY PLS_INTEGER;
 
    l_sql_array employees_aat;
 
begin
 
TargetSQL :=  UPPER(REPLACE(REPLACE(REPLACE(REPLACE(TargetSQL, CHR(10)), CHR(13)), CHR(9)), CHR(32)) );
 
--TargetSQL := regexp_replace( TargetSQL, '[' || chr(10) || chr(13) || chr(32) ||  ']', '' );
 
DBMS_OUTPUT.put_line ( chr(10) || chr(10) || 'Looking for &gt;&gt;'  || substr( TargetSQL, 1, 2000) || chr(10) || chr(10));
 
IF ( &amp;SEARCH_AWR = 1 )
  THEN
  dbms_output.put_line('Checking AWR &amp;DAYS_AGO days back : ' || chr(10)) ;
 
   
  OPEN sqltext_cur;
     
  FETCH sqltext_cur 
            BULK COLLECT INTO l_sql_array;
          
     FOR indx IN 1 .. l_sql_array.COUNT
        LOOP
            IF ( dbms_lob.instr( l_sql_array(indx).sql_text2, TargetSQL)   &gt; 0 )
            THEN
                dbms_output.put_line( l_sql_array(indx).sql_id ||  '   :    '   ||  dbms_lob.substr(l_sql_array(indx).sql_text2, 200 ) );
            END if;
        END LOOP;      
          
  DBMS_OUTPUT.put_line ( chr(10) || 'Searched ' ||  l_sql_array.COUNT || ' from AWR' || chr(10)  );        
  CLOSE sqltext_cur;
end if ;
 
 
  IF ( &amp;SEARCH_CURSORCACHE = 1 )
  THEN
     dbms_output.put_line('Checking cursor cache : ' || chr(10)) ;
 
     OPEN sqltext_cur2;
     FETCH sqltext_cur2 
            BULK COLLECT INTO l_sql_array;
 
     FOR indx IN 1 .. l_sql_array.COUNT
        LOOP
             
             IF ( dbms_lob.instr( l_sql_array(indx).sql_text2, TargetSQL)   &gt; 0 )
            THEN
                dbms_output.put_line( l_sql_array(indx).sql_id ||  '   :    '   ||  dbms_lob.substr(l_sql_array(indx).sql_text2, 200 )  );
            END if;
        END LOOP;           
 
    DBMS_OUTPUT.put_line ( chr(10) || 'Searched ' ||  l_sql_array.COUNT || ' from the cursor cache'  );
    CLOSE sqltext_cur2;
  END IF;
 
END;
/
set timing off
