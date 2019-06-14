
prompt
prompt =====================================
prompt


column P_USER new_value 1 format A10
column P_SQL_ID new_value 2 format A10
column P_STATUS new_value 3 format A10

select null P_USER, null P_SQL_ID, null P_STATUS from dual where 1=2;
select nvl( '&1','&_USER') P_USER, nvl('&2','%') P_SQL_ID, nvl('&3','EXECUTING') P_STATUS from dual ;


define USERNAME=&1
define SQL_ID=&2     
define STATUS=&3

undefine 1
undefine 2
undefine 3

 
prompt
prompt
prompt SQL Monitor :
prompt
prompt SQL_ID : &SQL_ID
prompt Status : &STATUS
prompt
prompt
 
COLUMN INST_ID FORMAT 99
COLUMN module FORMAT A20 TRUNCATE
COLUMN sid FORMAT 99999
COLUMN STATUS FORMAT a8
COLUMN buffer_gets FORMAT 999,999,999,999
COLUMN username FORMAT A15
COLUMN sql_text FORMAT A200 TRUNCATE
COLUMN program FORMAT A20  TRUNCATE
COLUMN osuser FORMAT A10  TRUNCATE
COLUMN status FORMAT A20 TRUNCATE;
COLUMN sql_id FORMAT A14
COLUMN current_workarea_mem_mb  FORMAT 999,999,999
COLUMN current_temp_mb FORMAT 999,999,999
COLUMN max_temp_mb  FORMAT 999,999,999
COLUMN max_workarea_mem_mb FORMAT 999,999,999
COLUMN sql_exec_start FORMAT A20
COLUMN total_px_buffers FORMAT 999,999,999,999
COLUMN TOTAL_PX_PHYS_READ_MB FORMAT 999,999,999,999
COLUMN TOTAL_PX_PHYS_WRITE_MB FORMAT 999,999,999,999
COLUMN sql_PLAN_HASH_VALUE FORMAT 999999999999999
COLUMN etime_mins FORMAT 999,999.9
COLUMN px_servers_allocated FORMAT 999
COLUMN sql_exec_id FORMAT 999999999
COLUMN rows_process FORMAT 999,999,999,999
 
WITH
sql_monitor_plan_summary AS
    (
    SELECT
    sql_id,
    sql_exec_id,
    SUM(workarea_mem)        /(1024*1024) current_workarea_mem_mb ,
    SUM(workarea_tempseg)    /(1024*1024) current_temp_mb ,
    SUM(workarea_max_tempseg)/(1024*1024) max_temp_mb,
    SUM(workarea_max_mem)    /(1024*1024) max_workarea_mem_mb,
    SUM(output_rows) rows_processed
    FROM
    gv$sql_plan_monitor
    WHERE
    sql_id LIKE '&QL_ID'
    GROUP BY
    sql_id,
    sql_exec_id
    )
,
sql_monitor_summary AS
    (
    SELECT
    sql_id,
    sql_exec_id,
    SUM(buffer_gets)                      total_px_buffers,
    SUM(physical_read_bytes) /(1024*1024) total_px_phys_read_mb,
    SUM(physical_write_bytes)/(1024*1024) total_px_phys_write_mb,
    COUNT(px_server#)                     total_px_servers,
    ( max(last_refresh_time) - min(first_refresh_time) )*60*24 px_etime_mins
    FROM
    gv$sql_monitor
    WHERE
    sql_id LIKE '&amp;SQL_ID'
    GROUP BY
    sql_id,
    sql_exec_id
    )
SELECT
SM.inst_id,
SM.sid,
SM.session_serial# serial#,
SM.username,
SM.program,
SM.module,
SESS.osuser,
SM.sql_id,
SM.sql_exec_id,
DECODE(SQL.command_type, 1,'CRE TAB', 2,'INSERT', 3,'SELECT', 6,'UPDATE', 7,'DELETE', 9,'CRE INDEX', 
        12,'DROP TABLE', 15,'ALT TABLE',39,'CRE TBLSPC', 42, 'DDL', 44,'COMMIT', 
        45,'ROLLBACK', 47,'PL/SQL EXEC', 48,'SET XACTN', 62, 'ANALYZE TAB', 63,'ANALYZE IX', 
         71,'CREATE MLOG', 74,'CREATE SNAP',79, 'ALTER ROLE', 85,'TRUNC TAB' ) type,
SM.status,
SM.sql_exec_start,
SMS.px_etime_mins etime_mins,
SM.sql_plan_hash_value,
SM.px_servers_allocated,
SMS.total_px_buffers,
SMS.total_px_phys_read_mb,
SMS.total_px_phys_write_mb,
SPS.current_temp_mb ,
SPS.max_temp_mb,
SPS.current_workarea_mem_mb,
SPS.max_workarea_mem_mb,
SPS.rows_processed
FROM
gv$sql_monitor SM
INNER JOIN  gv$session SESS ON SM.sid = SESS.sid AND SM.inst_id = SESS.inst_id and SM.SESSION_SERIAL# = SESS.SERIAL#
INNER JOIN gv$sql SQL      ON         SM.sql_child_address = SQL.child_address AND SM.inst_id = SQL.inst_id
INNER JOIN sql_monitor_plan_summary SPS on   SM.sql_id = SPS.sql_id and SM.sql_exec_id = SPS.sql_exec_id
INNER JOIN sql_monitor_summary SMS  on   SM.sql_id = SMS.sql_id and SM.sql_exec_id = SMS.sql_exec_id
WHERE      SM.sql_id like '&SQL_ID'
AND        SM.status like '%&STATUS%'
and        (SM.process_name = 'ora' or SM.process_name like 'j%')
and       SM.elapsed_time &gt; 0
ORDER BY   SM.inst_id, SM.sql_exec_start;


