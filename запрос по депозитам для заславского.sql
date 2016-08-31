--select * from tdeal
select d.DepositID, d.DateStart, d.DateEnd, d.BranchID, d.Amount, d.Prcnt
 from tDeposit d
inner join tInstrument i
on d.FinOperID = i.InstrumentID
and i.Brief like 'тб_%'
where Flag = 0



DECLARE @Today   date
       ,@DateMax date
       ,@CurDAte date

select @Today = GETDATE()
      ,@DateMax = '20190604'


select @CurDAte = DATEADD(DD,-(Datepart(DD,@Today)-1),@Today)

if object_id('tempdb..#Data') is not null drop table #Data   
create table #Data
                    ( MONTH_YEAR   DSOPERDAY,
                      M_DAYS       int,
                      PRC_SUMM     DSBIGMONEY null,
                      DEP_AMOUNT   DSBIGMONEY null)

while @CurDAte < @DateMax
BEGIN
       insert into #Data (MONTH_YEAR, M_DAYS) values (@CurDAte, DATEDIFF(DD, @CurDAte, DATEADD(MM, 1, @CurDAte)))
       set @CurDAte = DATEADD(MM, 1, @CurDAte)
END

select * from #Data
