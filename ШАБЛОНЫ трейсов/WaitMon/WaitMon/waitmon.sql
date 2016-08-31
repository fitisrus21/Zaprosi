use BASE  -- DATABASE NAME
go
set nocount on
go
if object_id('tempdb..#waitmon') is NOT NULL drop table #waitmon
go
create table #waitmon
(
	spid	    smallint,
	blocked	    smallint,
	waittime	bigint,
	open_tran	smallint,
	status	    nchar(60),
	cmd	        nchar(32),
	sql_handle	binary(20),
	stmt_start	int,
	stmt_end	int,
	rsc_dbid	smallint,
	rsc_indid	smallint,
	rsc_objid	int,
	rsc_type	nvarchar(4),
	rsc_text    nvarchar(16),
	req_mode	nvarchar(8),
	req_status	nvarchar(5)
)
go
if object_id('tempdb..#waitmondbcc') is NOT NULL drop table #waitmondbcc
go
create table #waitmondbcc
(
	eventtype varchar(64),
	parameters int,
	sqltxt varchar(4096)
)
go

SET TRANSACTION ISOLATION LEVEL READ COMMITTED

declare @waitms int
declare @mondelay varchar(12)

SET @waitms = 500
SET @mondelay = '00:00:02.000'

declare @node int

declare @blocked     smallint,
        @blockedprev smallint,
        @spid        smallint

declare @sqltxt varchar(1024),
        @dbid smallint,
        @objid int,
        @sqlh varbinary(20),
        @stmt_start int,
        @stmt_stop int

declare tmpcur cursor for select distinct blocked, spid from #waitmon where blocked != 0

WHILE 1=1
BEGIN
	
	truncate table #waitmon
	
	insert into #waitmon
	select sp.spid, sp.blocked, sp.waittime, sp.open_tran, sp.status, sp.cmd, sp.sql_handle, sp.stmt_start / 2, case when sp.stmt_end = -1 then -1 else stmt_end / 2 end, sli.rsc_dbid, sli.rsc_indid, sli.rsc_objid, substring (v.name, 1, 4), substring (sli.rsc_text, 1, 16), substring (u.name, 1, 8), substring (x.name, 1, 5)
	  from master..sysprocesses sp,
               ( select distinct blocked  from master..sysprocesses where blocked != 0 ) spp,
               master..syslockinfo sli,
               master.dbo.spt_values v,  
               master.dbo.spt_values x,  
               master.dbo.spt_values u  
	 where 1=1
	   and ( sp.spid = spp.blocked
	         or sp.blocked != 0 )
	   and sp.spid = sli.req_spid
		and sli.rsc_type = v.number  
		and v.type = 'LR'  
		and sli.req_status = x.number  
		and x.type = 'LS'  
		and sli.req_mode + 1 = u.number  
		and u.type = 'L'  
	
	
	if @waitms <= ( select max(waittime) from #waitmon )
	begin
		print ''
		print '²²²²±±±°°°°°°°±±±±±²²²²²²²²²²²±±±°°°°°°°±±±±±²²²²²²²²²²²±±±°°°°°°°±±±±±²²²²²²²²²²²±±±°°°°°°°±±±±±²²²²²²²²²²²±±±°°°°°°°±±±±±²²²²²²²²²²²±±±°°°°°°°±±±±±²²²²²²²'
		print '²²²²²±±±±°°°°°°°°±±±±²²²²²²²²²²±±±±°°°°°°°°±±±±²²²²²²²²²²±±±±°°°°°°°°±±±±²²²²²²²²²²±±±±°°°°°°°°±±±±²²²²²²²²²²±±±±°°°°°°°°±±±±²²²²²²²²²²±±±±°°°°°°°°±±±±²²²²²'
		print '²²²²²²²±±±±±°°°°°°°±±±²²²²²²²²²²²±±±±±°°°°°°°±±±²²²²²²²²²²²±±±±±°°°°°°°±±±²²²²²²²²²²²±±±±±°°°°°°°±±±²²²²²²²²²²²±±±±±°°°°°°°±±±²²²²²²²²²²²±±±±±°°°°°°°±±±²²²²'
		print 'DATETIME: ' + convert(varchar, getdate(), 112) + ' ' + convert(varchar, getdate(), 108)

		SET @node = 0
		SET @blockedprev = NULL

		open tmpcur
		
		WAITFOR DELAY '00:00:00.250'
		
		while 1=1
		begin
			fetch tmpcur into @blocked, @spid
			if (@@fetch_status = 0)
			begin
				
				select @dbid = NULL,
						 @objid = NULL,
						 @sqltxt = NULL

				if @blocked != @spid
				begin
					SET @node = @node + 1
					
					if (isnull(@blockedprev, '') = '') or (isnull(@blockedprev, '') != @blocked)
					begin
						print ''
						print ''
						print '²²²²²'
						print '²²²²²'
						print ''
						print 'ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿'
						print '³ ACTIVE PROCESS ³'
						print 'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ'
						print ''
	
	
						select distinct w1.spid, w1.blocked, w1.waittime, w1.open_tran, convert(varchar(14), w1.status) as 'status', convert(varchar(20), cmd) as 'cmd', w1.rsc_dbid, w1.rsc_indid, w1.rsc_objid, w1.rsc_type, convert(varchar(16),w1.rsc_text) as 'rsc_text', convert(varchar(8),w1.req_mode) as 'req_mode', w1.req_status
						  from #waitmon w1--,
								 --( select rsc_dbid, rsc_indid, rsc_objid  from #waitmon where blocked = @blocked and req_status != 'GRANT' ) w2
						 where w1.spid = @blocked
	                                           --and w1.rsc_dbid = w2.rsc_dbid
	                                           --and w1.rsc_indid = w2.rsc_indid
	                                           --and w1.rsc_objid = w2.rsc_objid
						set rowcount 1
						select @sqlh = sql_handle, @stmt_start = stmt_start, @stmt_stop = stmt_end from #waitmon where spid = @blocked
						set rowcount 0
						select @dbid = dbid, @objid = objectid, @sqltxt = substring(text, @stmt_start + 1, case @stmt_stop when -1 then datalength(text) else @stmt_stop - @stmt_start + 1 end ) from sys.dm_exec_sql_text(@sqlh) --from ::fn_get_sql(@sqlh)
						if (@@rowcount > 0)				
						begin
                            if @stmt_start = 0 SET @sqltxt = '...somewhere inside...'
							if datalength(@sqltxt) > 850
								SET @sqltxt = substring(@sqltxt, 1, 850) + '...' + char(10)
							SET @sqltxt = '³ ' + replace(@sqltxt, char(13) + char(10), char(10) + '³ ')
							if @dbid is NULL 
								print 'ÚÄ´ SQLTEXT :: BATCH :: SPID ' + convert(varchar, @blocked) + ' ÃÄ' + char(10) + '³'
							else
								print 'ÚÄ´ SQLTEXT :: SP-' + convert(varchar, @dbid) + '-' + convert(varchar, @objid) + ' :: SPID ' + convert(varchar, @blocked) + ' ÃÄ' + char(10) + '³'
							print @sqltxt
						end
						else
						begin
							truncate table #waitmondbcc
							SET @sqltxt = 'dbcc inputbuffer (' + convert(varchar,@blocked) + ') WITH NO_INFOMSGS'
							insert into #waitmondbcc
							exec(@sqltxt)   
							select @sqltxt = sqltxt from #waitmondbcc
							if datalength(@sqltxt) > 850
							SET @sqltxt = substring(@sqltxt, 1, 850) + '...' + char(10)
							SET @sqltxt = '³ ' + replace(@sqltxt, char(13) + char(10), char(10) + '³ ')
							print 'ÚÄ´ SQLTEXT :: BATCH :: SPID ' + convert(varchar, @blocked) + ' ÃÄ' + char(10) + '³'
							print @sqltxt
						end
						print ''
						print 'ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿'
						print '³ WAITING PROCESS ³'
						print 'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ'
						print ''
					end
	
					select distinct w1.spid, w1.blocked, w1.waittime, w1.open_tran, convert(varchar(14), w1.status) as 'status', convert(varchar(20), cmd) as 'cmd', w1.rsc_dbid, w1.rsc_indid, w1.rsc_objid, w1.rsc_type, convert(varchar(16),w1.rsc_text) as 'rsc_text', convert(varchar(8),w1.req_mode) as 'req_mode', w1.req_status
					  from #waitmon w1
	             where spid = @spid 
	               --and req_status != 'GRANT'
	
					set rowcount 1
					select @sqlh = sql_handle, @stmt_start = stmt_start, @stmt_stop = stmt_end from #waitmon where spid = @spid
					set rowcount 0
					select @dbid = dbid, @objid = objectid, @sqltxt = substring(text, @stmt_start + 1, case @stmt_stop when -1 then datalength(text) else @stmt_stop - @stmt_start + 1 end ) from sys.dm_exec_sql_text(@sqlh) -- from ::fn_get_sql(@sqlh)
					if (@@rowcount > 0)				
					begin
                                                if @stmt_start = 0 SET @sqltxt = '...somewhere inside...'
						if datalength(@sqltxt) > 850
							SET @sqltxt = substring(@sqltxt, 1, 850) + '...' + char(10)
						SET @sqltxt = '³ ' + replace(@sqltxt, char(13) + char(10), char(10) + '³ ')
						if @dbid is NULL 
							print 'ÚÄ´ SQLTEXT :: BATCH :: SPID ' + convert(varchar, @spid) + ' ÃÄ' + char(10) + '³'
						else
							print 'ÚÄ´ SQLTEXT :: SP-' + convert(varchar, @dbid) + '-' + convert(varchar, @objid) + ' :: SPID ' + convert(varchar, @spid) + ' ÃÄ' + char(10) + '³'
						print @sqltxt
					end
					else
					begin
						truncate table #waitmondbcc
						SET @sqltxt = 'dbcc inputbuffer (' + convert(varchar,@spid) + ') WITH NO_INFOMSGS'
						insert into #waitmondbcc
						exec(@sqltxt)   
						select @sqltxt = sqltxt from #waitmondbcc
						if datalength(@sqltxt) > 850
							SET @sqltxt = substring(@sqltxt, 1, 850) + '...' + char(10)
						SET @sqltxt = '³ ' + replace(@sqltxt, char(13) + char(10), char(10) + '³ ')
						print 'ÚÄ´ SQLTEXT :: BATCH :: SPID ' + convert(varchar, @spid) + ' ÃÄ' + char(10) + '³'
						print @sqltxt
					end
					
					SET @blockedprev = @blocked
				end
			end
			else break
		end
		close tmpcur
	
	end
	
	WAITFOR DELAY @mondelay
END
deallocate tmpcur
go
