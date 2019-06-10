
set serveroutput ON
 
DECLARE
 
TYPE             ASSOC_ARRAY_T IS TABLE OF INTEGER  INDEX BY VARCHAR2(256);
StatArray        ASSOC_ARRAY_T;
l_index          VARCHAR2(256);
cursor_name      INTEGER;
i_total_fetches  INTEGER := 0;
i_timestart      NUMBER := dbms_utility.get_time();
i_elapsed_time   NUMBER;
sql_text_string  CLOB;
ret              INTEGER;
adjusted_value   NUMBER;
s_SQL_ID VARCHAR2(13);
i_CHILD_NO integer;
i_SQL_EXEC_ID integer;
 
BEGIN
 
-- insert the SQL that you want to execute here :
 
sql_text_string  := q'#
 
select /*+ monitor parallel(2) */ count(*) from dba_segments
 
#';
 
----------------------------- 1st stats snapshot --------------------------------------------------
 
FOR r IN (select SN.name, SS.value FROM v$mystat SS, v$statname SN WHERE SS.statistic# = SN.statistic#)
LOOP
StatArray(r.name) := r.value;
END LOOP;
 
--------------------------- now execute the SQL ------------------------------------------------
 
cursor_name := DBMS_SQL.OPEN_CURSOR;
 
DBMS_SQL.PARSE(cursor_name, sql_text_string, DBMS_SQL.NATIVE);
 
ret := DBMS_SQL.EXECUTE(cursor_name);
 
LOOP
ret := DBMS_SQL.FETCH_ROWS(cursor_name);
EXIT WHEN ret = 0;
i_total_fetches := i_total_fetches + 1;
END LOOP;
 
DBMS_SQL.CLOSE_CURSOR(cursor_name);
 
---------------------Now get the SQL_ID and SQL_EXEC_ID for the statement ------------------------------
 
begin
select  prev_sql_id, prev_child_number ,prev_exec_id into s_SQL_ID, i_CHILD_NO, i_SQL_EXEC_ID
from v$session
where sid = dbms_debug_jdwp.current_session_id and serial#  = dbms_debug_jdwp.current_session_serial ;
EXCEPTION
when NO_DATA_FOUND THEN
dbms_output.put_line( 'Problems finding the SQL_ID  - ' || SQLERRM);
end;
 
i_elapsed_time := (dbms_utility.get_time() - i_timestart)/100;
 
------------- Output the stats, adjusting for the existing values in v$mystat and getting the parallel process SIDs from gv$sql_monitor -------------------------
 
for stats_cursor in (
select /*+ PUSH_PRED(SS) */ sn.name, sum(value) as value
from gv$sesstat ss
inner join v$statname sn on sn.statistic# = ss.statistic#
inner join  gv$sql_monitor sm on sm.inst_id = ss.inst_id and sm.sid = ss.sid  and sm.sql_id =  s_SQL_ID and sm.sql_exec_id = i_SQL_EXEC_ID
and value != 0
group by sn.name
order by sn.name
)
loop
adjusted_value := stats_cursor.value -  StatArray(stats_cursor.name);
if ( adjusted_value != 0) then
dbms_output.put_line( rpad(stats_cursor.name, 40) || ' : ' || lpad(to_char(adjusted_value,'999,999,999,999,999'),35)  );
end if;
end loop;
 
------------------------------- some output ---------------------------------------------------------
DBMS_OUTPUT.PUT_LINE( chr(10) || 'Fetched : ' || i_total_fetches || ' rows in '|| i_elapsed_time || ' secs.' || chr(10) );
DBMS_OUTPUT.PUT_LINE(chr(13) ||'SQL_ID=' || s_SQL_ID );
DBMS_OUTPUT.PUT_LINE('SQL_EXEC_ID=' || i_SQL_EXEC_ID );
DBMS_OUTPUT.PUT_LINE('SQL_CHILD_NO=' || i_CHILD_NO);
----------------------------------------------------------------------------------------------------
 
END;
/
