create or replace procedure upload(pSrcSchemaName varchar(256),
                                   pSrcTableName  varchar(256),
                                   pTgtSchemaName varchar(256),
                                   pTgtTableName  varchar(256),
                                   pLoadType      integer default 1)
as $$
declare
    vColConstList varchar(1024);  -- list of columns in constraint
    vColUpdList   varchar(1024);  -- list of columns in update clause
    vColumnList   varchar(1024);  -- list of columns in table
    vSQL          varchar(4000);  -- text of SQL for executing
    r             integer;        -- counter of query rows
begin
    
    if pLoadType = 1 then -- increment upload
        -- collecting list of columns in constraint
        for r in (select column_name
                  from   information_schema.constraint_column_usage
                  where  lower(table_schema) = lower(pTgtSchemaName) and
                         lower(table_name)   = lower(pTgtTableName)) loop
            vColConstList := '\n'||'src.'||r.column_name||' = tgt.'||r.column_name||',';
        end loop;
        
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
        vSQL := 'insert into '||pTgtSchemaName||'.'||pTgtTableName||'('||vColumnList||')'||'\n'||
                'select '||vColumnList||'\n'||
                'from   '||pSrcSchemaName||'.'||pSrcTableName||' src'||'\n'
                'left outer join '||pTgtSchemaName||'.'||pTgtTableName||' tgt'
                 '             on '||substr(vColConstList,1,length(vColConstList)-1)
                'where  '||substr(vColConstList,position('tgt' in vColConstList),position(',' in vColConstList)-position('tgt' in vColConstList))||' is null';
    
        execute vSQL;
        commit;
        
        -- collecting list of columns in update clause
        for r in (select column_name
                  from   information_schema.constraint_column_usage
                  where  lower(table_schema) = lower(pTgtSchemaName) and
                         lower(table_name)   = lower(pTgtTableName)) loop
            vColUpdList := '\n'||r.column_name||' = tgt.'||r.column_name||',';
        end loop;
        
        -- preparing DML operation update
        vSQL := 'update '||pTgtSchemaName||'.'||pTgtTableName||' tgt'||'\n'||
                'set '||substr(vColUpdList,1,length(vColUpdList)-1)
                'from (select * '||'\n'||
                '      from   '||pSrcSchemaName||'.'||pSrcTableName||') AS src '||'\n'||
                'where '||vColConstList;
        
        execute vSQL;
        commit;
    
    elsif pLoadType = 2 then -- full reload
        -- full clean of table
        vSQL := 'truncate table '||pTgtSchemaName||'.'||pTgtTableName;
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
        vSQL := 'insert into '||pTgtSchemaName||'.'||pTgtTableName||'('||vColumnList||')'||'\n'||
                'select '||vColumnList||'\n'||
                'from   '||pTgtSchemaName||'.'||pTgtTableName;
        execute vSQL;
        
        commit;
        
    end if;
    
end;
$$ language plpgsql;