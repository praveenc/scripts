/***************************************/
PRINT 'PROCESSING Grant Permissions '
GO
DECLARE 
 @SPName varchar(100)
,@schema sysname
,@Type varchar(2)

DECLARE MySPCur CURSOR FAST_FORWARD FOR SELECT SCHEMA_NAME(schema_id) AS schemaname, name, type 
                  FROM sys.objects
                        WHERE type in ('P','FN','TF','V')
OPEN MySPCur
FETCH NEXT FROM MySPCur INTO @schema, @SPName, @Type
--Create Role B1_CG_BI_BETA_QA

WHILE @@Fetch_Status = 0
BEGIN
      IF @Type='P' or @Type='FN'
            EXEC('GRANT EXECUTE ON ['+@schema+'].['+@SPName+'] TO [OWLAND1\B1_CG_BI_BETA_QA]')
      --exec ('Grant view definition on dbo.'+@SPName+' to [OWLAND1\B1_CG_BI_BETA_QA]') to be used for non-client facing environments only.
      IF @Type='TF'
            EXEC('GRANT SELECT ON ['+@schema+'].['+@SPName+'] TO [OWLAND1\B1_CG_BI_BETA_QA]') 
      IF @Type='V'
            EXEC('GRANT SELECT,INSERT,UPDATE,DELETE ON ['+@schema+'].['+@SPName+'] TO [OWLAND1\B1_CG_BI_BETA_QA]')            

FETCH NEXT FROM MySPCur INTO @schema, @SPName,@Type
END
CLOSE MySPCur
DEALLOCATE MySPCur
/***************************************/
