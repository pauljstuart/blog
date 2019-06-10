set termout off
begin
sqltxadmin.sqlt$a.reset_directories;
end;
/
set termout on
set serveroutput on
 
prompt you will need 'grant read on directory SQLT$BDUMP to SQLT_USER_ROLE';
 
define MAX_LENGTH=5000000
DECLARE
 
  s_instance_name VARCHAR2(1024);
  s_alert_log_name VARCHAR2(1024);
  src_clobBFILE;
  dest_clob CLOB;
  i_offsetnumber := 1;
  i_amountinteger;
  lc_buffer varchar2(32767);
  warning int;
  dest_offint:=1;
  src_off int:=1;
  lang_ctxint:=0;
  i_length integer;
 
BEGIN
 
  DBMS_OUTPUT.ENABLE (buffer_size =&amp;gt; NULL);
 
  select instance_name into s_instance_name from v$instance;
  s_alert_log_name := 'alert_' || s_instance_name || '.log';
 
  dbms_output.put_line('Getting ' || s_alert_log_name );
  src_clob := BFILENAME('SQLT$BDUMP', s_alert_log_name );
 
  DBMS_LOB.FILEOPEN(src_clob, DBMS_LOB.LOB_READONLY);
  DBMS_LOB.CREATETEMPORARY(dest_clob,true);
 
  i_length := dbms_lob.getlength( src_clob);
  src_off := greatest(1, i_length - &amp;amp;MAX_LENGTH);
 
  WHILE ( src_off &amp;lt; i_length )
  LOOP
 
    dest_off := 1;
    i_offset := 1;
    i_amount := least(32676 , i_length - src_off) ;
    DBMS_LOB.LoadCLOBFromFile( dest_lob =&amp;gt; dest_clob,
        src_bfile=&amp;gt; src_clob,
        amount =&amp;gt; i_amount ,
        dest_offset =&amp;gt; dest_off,
        src_offset =&amp;gt; src_off,
        bfile_csid =&amp;gt; 0,
        lang_context =&amp;gt; lang_ctx,
        warning =&amp;gt; warning );
 
    DBMS_LOB.READ ( lob_loc =&amp;gt; dest_clob, amount =&amp;gt; i_amount,offset =&amp;gt; i_offset, buffer =&amp;gt; lc_buffer);
    dbms_output.put_line(lc_buffer);
 
  END LOOP;
  dbms_output.put_line('The total size is ' ||to_char(i_length,'999,999,999,999,999') || ' bytes.');
  dbms_output.put_line('Displayed the last ' ||to_char( '&amp;amp;MAX_LENGTH','999,999,999,999,999') || ' bytes. ');
 
  DBMS_LOB.FILECLOSE(src_clob);
 
exception
  when UTL_FILE.INVALID_FILENAME THEN
  DBMS_OUTPUT.PUT_LINE('INVALID FILE NAME : The file name parameter is invalid.');
  when utl_file.invalid_path then
  raise_application_error(-20001,
  'INVALID PATH: File location or filename was invalid.');
  when utl_file.invalid_mode then
  raise_application_error(-20002,
  'INVALID MODE: The open_mode parameter in FOPEN was invalid');
  when utl_file.invalid_filehandle then
  raise_application_error(-20003,
  'INVALID OPERATION:The file could not be opened or operated on as requested.');
  when utl_file.read_error then
  raise_application_error(-20004,'READ_ERROR:An operating system error occured during the read operation.');
  when utl_file.write_error then
  raise_application_error(-20005,
  'WRITE_ERROR: An operating system error occured during the write operation.');
  when utl_file.internal_error then
  raise_application_error(-20006,
  'INTERNAL_ERROR: An unspecified error in PL/SQL');
  when others then
  DBMS_OUTPUT.PUT_LINE('OTHER ERROR - ' || SQLERRM);
END;
/

