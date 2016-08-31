declare @RepDate     dsoperday
       ,@CourseDate  DSOPERDAY 
       ,@USD         DSMONEY
       ,@EUR         DSMONEY
select @RepDate = getdate()

DECLARE @SDate DSOPERDAY
       ,@EDate DSOPERDAY 
       ,@Money       DSMONEY
       ,@xtx         varchar(max)
       ,@ID          DSIDENTIFIER


 ------------------ 
select @SDate = '20160701' 
      ,@EDate = '20161231'
     
 ------------------         



-- начитку курсов нужно исправить чтобы если нет курсов в этой дате то брать последние доступные!!!!!!!!!!!!!!
select @CourseDate = max(Date_Time) from  tCurrencyRate where Date_Time <= @RepDate
select @USD = Course from tCurrencyRate where  Date_Time = @CourseDate and ObjectID = 1
select @EUR = Course from tCurrencyRate where  Date_Time = @CourseDate and ObjectID = 90001299

if OBJECT_ID('tempdb..#departMonth') is not null drop table #departMonth
if OBJECT_ID('tempdb..#Contract') is not null drop table #Contract
if OBJECT_ID('tempdb..#CreditEnd') is not null drop table #CreditEnd
if OBJECT_ID('tempdb..#TOTALbyMonth') is not null drop table #TOTALbyMonth






 
---- Заносим информацию по договору во временную такблицу

select  
        case when i.PropDealPart = 0 then  i.Name + ' ' + i.Name1 + ' '+ i.Name2
             else i.Name
        end                        ClientName  
        ,c.ContractID              ContractID
        ,c.InstrumentID            InstrumentID
        ,c.Number                  Number
        ,0                         Prc
        ,c.FundID                  FundID
        ,cc.CreditDateFrom         DateStart 
        ,cc.CreditDateTo           DateEnd
        ,dateadd(dd,-(datepart(dd, cc.CreditDateTo  )-1), cc.CreditDateTo)          YeMo
        
into #Contract
from tContract c
inner join tContractCredit cc
        on c.ContractID = cc.ContractCreditID
		and cc.CreditDateTo between  @SDate and @EDate
inner join tInstitution i
        on c.InstitutionID = i.InstitutionID

where IsActive = 2 -- Действующие договора
  and c.InstrumentID not in (3477,10000000378) -- Исключаем допсоглашения и кредитные линии
--  and c.ContractID = 10000005481
--and c.Number= '01-01/16-10' or c.Number= '01-01/16-8'

/* % ставка */

delete pAPI_Accrual_Object
  from pAPI_Accrual_Object -- #M_ROWLOCK_INDEX(XPKpAPI_Accrual_Object)
where spid = @@spid

insert pAPI_Accrual_Object-- #M_WITH_ROWLOCK
       (
       SPID, 
       ObjectID,
       FinOperID,
       CrnID
       )
select distinct 
       @@spid,
       ContractID,
       InstrumentID,
       FundID
  from #Contract  -- #M_NOLOCK_INDEX(0)      

exec Mass_CreditPrc
       @BeginDate   = @RepDate,
       @EndDate     = @RepDate,
       @PercentType = 201,
       @Alg         = 6


update #Contract
   set Prc = isnull(p.Prcnt,0)
  from #Contract ccc   --#M_UPDLOCK
 inner join pAPI_ACCR_ObjInterestRate p --#M_NOLOCK_INDEX(XPKpAPI_ACCR_ObjInterestRate)
         on p.ObjectID = ccc.ContractID
        and p.SPID = @@SPID
------------------------------------------------------

-----Заноисим информацию в #departMonth(добавляем к информации из #Contract информацию из графика платежей
select c1.ClientName  
           ,c1.ContractID
           ,c1.InstrumentID
           ,c1.Number
           ,c1.Prc
           ,c1.FundID
		   ,case when c1.FundID = 2 then 'RUB'
				 when c1.FundID = 1 then 'USD'
				 else 'EUR'           
			 end	                  Fund
				 	
           ,c1.DateStart 
           ,c1.DateEnd
           ,ps.ActionType             TypePog
           ,ps.DatePay                DatePay
           ,abs(ps.Qty)               QTY

           ,dateadd(dd,-(datepart(dd, ps.datePay)-1), ps.datePay)          YeMo
           
 into #departMonth
 from #Contract c1
 inner join tPaySchedule ps
         on c1.ContractID = ps.ContractID
        and ps.Version = 0
        and ps.ActionType in (2,4)  --  2 - погашение ОД, 4 - погашение процентов
        and ps.DatePay > @RepDate

        --- Создаем #CreditEnd в которой будут только последние погашения договора.

select      c1.ClientName  
           ,c1.ContractID
           ,c1.InstrumentID
           ,c1.Number
           ,c1.Prc
           ,c1.FundID
		   ,case when c1.FundID = 2 then 'RUB'
				 when c1.FundID = 1 then 'USD'
				 else 'EUR'           
			 end	                  Fund
           ,c1.DateStart 
           ,c1.DateEnd
           ,abs(ps.Qty)                QTY
           ,abs(ps1.Qty)               QTY_PRC
           ,dateadd(dd,-(datepart(dd, ps.datePay)-1), ps.datePay)          YeMo
        
 
 into #CreditEnd
 from #Contract c1
 inner join tPaySchedule ps
         on c1.ContractID = ps.ContractID
        and ps.Version = 0
        and ps.ActionType in (2)  --  2 - погашение ОД, 4 - погашение процентов
        and datepart(YYYY,c1.DateEnd) = datepart(YYYY,ps.datePay)
        and datepart(MM,c1.DateEnd) = datepart(MM,ps.datePay)
        and ps.DatePay > @RepDate  
 inner join tPaySchedule ps1
         on c1.ContractID = ps1.ContractID
        and ps1.Version = 0
        and ps1.ActionType in (4)  --  2 - погашение ОД, 4 - погашение процентов
        and datepart(YYYY,c1.DateEnd) = datepart(YYYY,ps1.datePay)
        and datepart(MM,c1.DateEnd) = datepart(MM,ps1.datePay)
        and ps1.DatePay > @RepDate  



 --select * from #CreditEnd  order by  YeMo

/* select SUM(QTY),
        sum(QTY_PRC),
		YeMo,
		Fund,
		@USD,
		@EUR
		
  from #CreditEnd
  Group by YeMo,Fund */
-----------------------------------------------------

-----Удаляем из #departMonth платежы который попадают в последний месяц обслуживания.
delete from #departMonth
      where datepart(yyyy,DatePay) = datepart(yyyy,DateEnd)
        and datepart(MM,DatePay) = datepart(MM,DateEnd)

select sum(QTY) totalQTY
		       ,fund
			   ,FundID
			   ,YeMo
into #TOTALbyMonth
from #departMonth
group by fund, fundid, YeMo
order by YeMo,fund 


--select * from #TOTALbyMonth
/*select * from #departMonth
order by  YeMo*/

select 

coalesce(tm.fund,ce.fund)         fund,	
coalesce(tm.YeMo, ce.YeMo)   YeMo,
isnull(ce.ClientName, '************') ClientName,	
isnull(ce.Number,'')                 Number,
isnull(ce.Prc,0)                         Prc,
isnull(ce.DateStart,'19000101')         DateStart,
isnull(ce.DateEnd, '19000101')                 DateEnd,
isnull(ce.QTY,0)                                 QTY,
isnull(ce.QTY_PRC,0)                      QTY_PRC,
isnull(tm.totalQTY,0)    totalQTY,
case when coalesce(tm.FundID, ce.fundid) = 2 then tm.totalQTY
	 when coalesce(tm.FundID, ce.fundid) = 1 then tm.totalQTY * @USD
	 else  tm.totalQTY * @EUR
end   totalQTY_BS,
@USD USD,
@EUR EUR, 
@SDate RepStart, 
@EDate  RepEnd   


 from #TOTALbyMonth tm
full join #CreditEnd ce  
on tm.YeMo  = ce.YeMo
and tm.FundID = ce.FundID

order by coalesce(tm.YeMo, ce.YeMo), fund