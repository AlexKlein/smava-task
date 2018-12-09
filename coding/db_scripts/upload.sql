create or replace procedure upload (pSrcSchemaName varchar(256),
                                    pSrcTableName  varchar(256),
                                    pTgtSchemaName varchar(256),
                                    pTgtTableName  varchar(256),
                                    pLoadType      integer default 1)
as $$
declare
    vColConstList  varchar(1024);  -- list of columns in constraint
    vColUpdList    varchar(1024);  -- list of columns in update clause
	vColForUpdList varchar(1024);  -- list of columns for update
	vColDifUpdList varchar(1024);  -- list of columns with different values
    vColumnList    varchar(1024);  -- list of columns in table
    vSQL           varchar(4000);  -- text of SQL for executing
    r information_schema.constraint_column_usage%rowtype;  -- rows of constraint_column_usage query
	q information_schema.columns%rowtype;                  -- rows of columns query
begin
    
    if pLoadType = 1 then -- increment upload
        -- collecting list of columns in constraint
        vColConstList := ' ';
		for r in select *
                 from   information_schema.constraint_column_usage
                 where  lower(table_schema) = lower(pTgtSchemaName) and
                        lower(table_name)   = lower(pTgtTableName) loop
			vColConstList := vColConstList||chr(10)||'src.'||r.column_name||' = tgt.'||r.column_name||',';
        end loop;
        
        -- collecting list of columns in table
        select string_agg(tgtCols.column_name, ', ')
        into   vColumnList
        from   information_schema.columns srcCols
        inner join information_schema.columns tgtCols
                on lower(tgtCols.table_schema) = lower(pTgtSchemaName) and
                   lower(tgtCols.table_name)   = lower(pTgtTableName) and
                   lower(tgtCols.column_name)  = lower(srcCols.column_name)
        where  lower(srcCols.table_schema) = lower(pSrcSchemaName) and
               lower(srcCols.table_name)   = lower(pSrcTableName);
        
        -- preparing DML operation insert
        vSQL := 'insert into '||pTgtSchemaName||'.'||pTgtTableName||'('||vColumnList||')'||chr(10)||
                'select src.'||replace(vColumnList,', ', ', src.')||chr(10)||
                'from   '||pSrcSchemaName||'.'||pSrcTableName||' src'||chr(10)||
                'left outer join '||pTgtSchemaName||'.'||pTgtTableName||' tgt'||chr(10)||
                '             on '||replace(replace(substr(vColConstList,1,length(vColConstList)-1), ',', ' and '), chr(10), '')||chr(10)||
                'where  '||substr(vColConstList,position('tgt' in vColConstList),position(',' in vColConstList)-position('tgt' in vColConstList))||' is null';
		insert into upload_log (date_time,
					   			pLoadType,
								SQL_text) values (clock_timestamp(),
												  pLoadType,
												  vSQL);
		execute vSQL;
        commit;
        
        -- collecting list of columns in update clause
		vColUpdList := ' ';
        for r in select *
                 from   information_schema.constraint_column_usage
                 where  lower(table_schema) = lower(pTgtSchemaName) and
                        lower(table_name)   = lower(pTgtTableName) loop
            vColUpdList := vColUpdList||chr(10)||r.column_name||' = tgt.'||r.column_name||',';
        end loop;
        
		-- collecting list of columns for update
		vColForUpdList := ' ';
		vColDifUpdList := ' ';
        for q in select tgt.*
                 from   information_schema.columns src
				 inner join information_schema.columns tgt
				         on src.column_name = tgt.column_name and
							lower(tgt.table_schema) = lower(pTgtSchemaName) and
                            lower(tgt.table_name)   = lower(pTgtTableName)
                 left outer join information_schema.constraint_column_usage const
                 			   on  src.column_name = const.column_name and
							       lower(const.table_schema) = lower(pTgtSchemaName) and
                        		   lower(const.table_name)   = lower(pTgtTableName)
				 where  lower(src.table_schema) = lower(pSrcSchemaName) and
                        lower(src.table_name)   = lower(pSrcTableName) and
					    const.column_name is null loop
            vColForUpdList := vColForUpdList||q.column_name||' = tgt.'||q.column_name||',';
			vColDifUpdList := vColDifUpdList||'src.'||q.column_name||' != tgt.'||q.column_name||' or ';
        end loop;

        -- preparing DML operation update
        vSQL := 'update '||pTgtSchemaName||'.'||pTgtTableName||' tgt'||chr(10)||
                'set '||substr(vColForUpdList,1,length(vColForUpdList)-1)||chr(10)||
                'from (select * '||chr(10)||
                '      from   '||pSrcSchemaName||'.'||pSrcTableName||') AS src '||chr(10)||
                'where '||replace(replace(substr(vColConstList,1,length(vColConstList)-1), ',', ' and '), chr(10), '')||chr(10)||
				'  and ('||substr(vColDifUpdList,1,length(vColDifUpdList)-3)||')';
        insert into upload_log (date_time,
					   			pLoadType,
								SQL_text) values (clock_timestamp(),
												  pLoadType,
												  vSQL);
		execute vSQL;
        commit;
    
    elsif pLoadType = 2 then -- full reload
        -- full clean of table
        vSQL := 'truncate table '||pTgtSchemaName||'.'||pTgtTableName;
        insert into upload_log (date_time,
					   			pLoadType,
								SQL_text) values (clock_timestamp(),
												  pLoadType,
												  vSQL);
		execute vSQL;
        
        -- collecting list of columns in table
        select string_agg(tgtCols.column_name, ',')
        into   vColumnList
        from   information_schema.columns srcCols
        inner join information_schema.columns tgtCols
                on lower(tgtCols.table_schema) = lower(pTgtSchemaName) and
                   lower(tgtCols.table_name)   = lower(pTgtTableName) and
                   lower(tgtCols.column_name)  = lower(srcCols.column_name)
        where  lower(srcCols.table_schema) = lower(pSrcSchemaName) and
               lower(srcCols.table_name)   = lower(pSrcTableName);
        
        -- preparing DML operation insert
        vSQL := 'insert into '||pTgtSchemaName||'.'||pTgtTableName||'('||vColumnList||')'||chr(10)||
                'select '||vColumnList||chr(10)||
                'from   '||pSrcSchemaName||'.'||pSrcTableName;
		insert into upload_log (date_time,
					   			pLoadType,
								SQL_text) values (clock_timestamp(),
												  pLoadType,
												  vSQL);
		execute vSQL;
        commit;
        
    end if;
    
end;
$$ language plpgsql;