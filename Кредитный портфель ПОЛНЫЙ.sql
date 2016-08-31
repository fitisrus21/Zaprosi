Declare @DateStart DSOPERDAY,
		@DateEnd DSOPERDAY,
		@RepDate DSOPERDAY,
		@CourseDate DSOPERDAY,
        @Date      DSOPERDAY,
		@txt varchar(max),
		@money DSMONEY,
		@PRC DSFLOAT,
		@USD DSMONEY,
		@EUR DSMONEY,
		@AccID DSIDENTIFIER
	   ,@s1        DSIDENTIFIER                  
       ,@s2        DSIDENTIFIER                  
       ,@s3        DSIDENTIFIER                  
       ,@s4        DSIDENTIFIER                  
       ,@s5        DSIDENTIFIER
	   ,@s6        DSIDENTIFIER
	   ,@s7        DSIDENTIFIER

 	
select @DateStart = '20160701',
       @DateEnd   = '20161231',
       @RepDate   = '20160722'

select @CourseDate = max(Date_Time) from  tCurrencyRate where Date_Time <= @RepDate
select @USD = Course from tCurrencyRate where  Date_Time = @CourseDate and ObjectID = 1
select @EUR = Course from tCurrencyRate where  Date_Time = @CourseDate and ObjectID = 90001299
			 

if OBJECT_ID('tempdb..#contract') is not null drop table #contract
if OBJECT_ID('tempdb..#OKVED') is not null drop table #OKVED

select c.ContractID  ContractID
,cc.MainContractID            
,c.InstrumentID
,c.InstitutionID     ClientID
, i.Brief            Client
,coalesce(il.NumDoc,'')           OGRN
,i.INN                           
,@txt                 OKVED
,case i.PropDealPart when 1 then 'Кредитование юридических лиц'
                     when 0 then 'Кредитование физических лиц'
end                   ClientType
,coalesce(ia.Name,ia1.Name,'нет данных')     Adress
,coalesce(eav.Value,'нет данных')            TipPred

,c.BankProductID
,bp.Name
,c.Number
,coalesce(ac.Name,'нет данных')              Cel

, case when c.BankProductID in (10000000002,10000000003) then cc.AmountAdd    -- сумма договора для банковских продуктов лимита выдачи
       else c.Amount                                   -- сумма договора для лимита задолженности и разовых договоров
 end                  Amount 
, case when  c.BankProductID in (10000000002,10000000003) and c.FundID = 1 then cc.AmountAdd * @USD
       when  c.BankProductID in (10000000002,10000000003) and c.FundID = 90001299 then cc.AmountAdd * @EUR
	   when  c.BankProductID in (10000000002,10000000003) and c.FundID = 2 then cc.AmountAdd 
	   when  c.BankProductID not in (10000000002,10000000003) and c.FundID = 1 then c.Amount * @USD
       when  c.BankProductID not in (10000000002,10000000003) and c.FundID = 90001299 then c.Amount * @EUR
	   when  c.BankProductID not in (10000000002,10000000003) and c.FundID = 2 then c.Amount 
end                  AmountCur

,c.FundID
,c.InstitutionID
,c.DateFrom          DogStart
,  case when c.DateTo = '19000101' then null
        when c.DateTo > '19000101' then c.DateTo
     end            DogEndFact
,cc.CreditDateTo                       -- 
,@Date               DogEndPlan        -- дата погашения
,@Date               DogEndPlanIzm     --Дата погашения с учетом изменений в договоре


,@PRC                PRC
,@PRC                Prc_Pros
,cc.CreditPeriod
,DATEDIFF(DD, @RepDate, cc.CreditDateTo) AmounDaysEnd  -- Кол.дней до погаш. (разница планового окончания и тдатой отчета)


-- счета лимита
,@AccID               AccLimitID

,@money               AccLimitRest

,@AccID              VnAccID
,@money              VnAccSsudRest 
,@money              VnAccPrSsudRest
,@money              VnAccProcRest
,@money              VnAccProcVRest
,@money              VnAccPrPcocRest
,@money              VnAccPrPcocVRest

,wor.ChildID         ObecID                --ID договора обеспечения
,d.InstrumentID      FOObecID              -- FO договора обеспечения    
,@txt                VidObec              ---Вид обеспечения
,@txt                Poruch               -- Поручитель
,@txt                NumObec               -- номер договора обеспечения
,@txt                KatKatcOb               -- Категоря качества обеспечения   
,@money              RinQTY                -- Рыночная стоимость
,@money              ZalQTY                -- Залоговая стоимость
,@money              SprQTY                -- Справедливая стоимость

,@txt                KOD                   -- качество обслуживания долга
,@txt                FP                    -- финансовое положение

,@txt                R1                     -- категория качества
,@txt                Risk                   -- норма резервирования

--данные из управления резервов ----
,@money              RasRez254
,@money              SforRez254
,@money              RasRez283
,@money              SforRez283
,@money              RezProc
,@txt                RasAcc
,@txt                SsudAcc
,@txt                RezSsudAcc
,@txt                LimitAcc
,@txt                RezLimitAcc
,@txt                PrcAcc
,@txt                PrPrcAcc
,@txt                RezPrcAcc



    
 


into #contract
  
 from tcontract c
inner join tContractCredit cc
        on c.ContractID = cc.ContractCreditID
inner join tInstitution i
        on c.InstitutionID = i.InstitutionID
inner join tBankProduct bp
        on c.BankProductID =bp.BankProductID  
left join tInstLicense il
        on i.InstitutionID = il.InstitutionID
	   and il.DocTypeID = 35001428  -- ГосРегНом(ОГРН)
       and il.Failed = 0   -- 0 - ОГРН не утратило силу
       and il.RegTmp = 0   -- 0 - ОГРН не временное

left join tInstAddress  ia
        on i.InstitutionID = ia.InstitutionID
	   and ia.AddressTypeID = 1  -- юридический адрес
	   and i.PropDealPart = 1     -- Юр лицо
	   and ia.Sign!=2             -- адресс отличен от недействуещего
left join tInstAddress  ia1
        on i.InstitutionID = ia1.InstitutionID
	   and ia1.AddressTypeID = 5    -- адрес места регистрации
	   and i.PropDealPart = 0     -- Физ лицо
	    and ia1.Sign!=2             -- адресс отличен от недействуещего
	   	
left join tAimContent ac
       on ac.DealID = c.ContractID
left join tEntAttrValue eav
       on c.InstitutionID = eav.ObjectID
	   and eav.AttributeID = 10000001671 -- Признак субъекта предпринимательства

--Вяжем обеспечение
left join tWarObjectRelation wor 
       on c.ContractID = wor.ParentID
left join tdeal d
       on   d.DealID = wor.ChildID

-- доп атрибут для Договора обеспечения имущества

 
where c.InstrumentID in (10000000377,10000000378,10000000379) -- ФО ТБПотрКрд, ТБКредЛин, ТБТрнКрЛин
and (c.DateTo > @RepDate or c.DateTo = '19000101') -- дата договора меньше плановой даты или фактическое окончание 19000101
and c.DateFrom <= @RepDate          -- дата кредита меньше равна даты отчета

--and c.ContractID = 10000002784



--and cc.MainContractID = 0
--and c.InstrumentID=10000000378

/*
select * from tInstitution
select * from tInstLicense il where il.InstLicenseID in (10000003822,10000004149)
select * from tInstLicense il where il.InstLicenseID in (10000002979,10000004149)
select * from tDocType
 select * from tReuterTypeCode 
 select *  from tInstAddress 
 select * from tAddressType 
 select * from tAim 
 select * from tAimContent          

 */


----- Обновляем ОКВЭД выводя в одну строчку-----
update #contract
set OKVED = coalesce((select  rtrim(r.Reuters) + ', ' 
             from tReuters r
			 where   #contract.InstitutionID = r.InstitutionID
                    and r.TradingSysID = 8
             for xml path('')),'')
----------------------------------------------

--- обновляем даты заверешения договоров------
if (exists (select * from tContract c
                    inner join #Contract c1
                    on  c.ContractID = c1.ContractID 
                    inner join tContractCredit cc
                   on c.ContractID = cc.ContractCreditID
				   where c1.Instrumentid = 3477) )
	
begin
    update #contract
    set DogEndPlan = coalesce(min(cc.CreditDateCreate),c1.CreditDateTo)
    from #contract c
    inner join tContract c1
            on  c.ContractID= c1.contractid
			and  c1.InstrumentID = 3477
    inner join tContractCredit cc 
            on ContractID = cc.ContractCreditID
		  -- and min(cc.CreditDateCreate)
           
      -- order by cc.contractcreditid
end
 else 
 begin
  update #contract
    set DogEndPlan = DateTo
    from #contract
    /*inner join tContract c1
            on  c1.contractid = ContractID
    inner join tContractCredit cc 
            on ContractID = cc.ContractCreditID
		   and min(cc.CreditDateCreate)
         where  c1.Instrumentid = 3477
       order by cc.maincontractid*/
 end 


--if OBJECT_ID('tempdb..#PRC') is not null drop table #PRC
/* % ставка на срочную задолженность */

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
       @PercentType = 201,        -- Проценты на срочную ссудную задолженность по потребительскому кредиту 
--     @PercentType = 210,        -- Проценты на просроченную ссудную задолженность по потребительскому кредиту       
--     @PercentType = 216,       -- Штрафы и пени на просроченную ссудную задолженность по потребительским кредитам       

       @Alg         = 6


update #Contract
   set Prc = isnull(p.Prcnt,0)
  from #Contract ca   --#M_UPDLOCK
 inner join pAPI_ACCR_ObjInterestRate p --#M_NOLOCK_INDEX(XPKpAPI_ACCR_ObjInterestRate)
         on p.ObjectID = ca.ContractID
        and p.SPID = @@SPID
------------------------------------------------------------------
/* % ставка на ПРОСРОЧЕННУЮ задолженность */  

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
--     @PercentType = 201,         -- Проценты на срочную ссудную задолженность по потребительскому кредиту 
       @PercentType = 210,        -- Проценты на просроченную ссудную задолженность по потребительскому кредиту       
--     @PercentType = 216,       -- Штрафы и пени на просроченную ссудную задолженность по потребительским кредитам  
       @Alg         = 6


update #Contract
   set Prc_Pros = isnull(p.Prcnt,0)
  from #Contract ca   --#M_UPDLOCK
 inner join pAPI_ACCR_ObjInterestRate p --#M_NOLOCK_INDEX(XPKpAPI_ACCR_ObjInterestRate)
         on p.ObjectID = ca.ContractID
        and p.SPID = @@SPID
-------------------------------------------------------------------------------

--- счет лимита и его остаток---------
update #Contract
set AccLimitID = cal.ResourceID, LimitAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and (cra.Brief like 'КР_ЛИМ_З' or cra.Brief like 'КР_Л_НИ') 
inner join tResource r
        on cal.ResourceID = r.ResourceID
-------- остаток на счете Лимита----------

delete pResource where SPID = @@SPID

insert into pResource (SPID, ResourceID)
select distinct @@SPID, AccLimitID from #Contract 
where AccLimitID is not null
--select * from pResource where spid = @@SPID 
exec AccList_Rest @Date     = @RepDate 
                 ,@CalcType = 1

--select * from pResList where SPID = @@SPID
update #Contract  set AccLimitRest = -1 * p.Rest
from pResList p where AccLimitID = p.ResourceID and p.SPID = @@SPID

-------------------
--- счет внутреннего учета---------
update #Contract
set VnAccID = cal.ResourceID--, AccLimit =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like 'ВНУТРЕН' 
inner join tResource r
        on cal.ResourceID = r.ResourceID
----------


--остатки на внутреннем счете
select @s1 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'LOAN_DEBTS_DEPARTMENT_ID'       --СрочСсудЗд 
--#M_ISOLAT
 
select @s2 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'OVERDUE_DEBTS_DEPARTMENT_ID'    --ПрсрСсудЗд 
--#M_ISOLAT 
 
select @s3 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'PERCENT_DEPARTMENT_ID'          --СрПрСрСсЗд
--#M_ISOLAT 
  
select @s4 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'PERCENT_OVERDUE_DEBTS_DEPARTME' --СрПрПрсСсЗ 
--#M_ISOLAT 
 
select @s5 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'OVERDPERCENT_DEPARTMENT_ID'     --ПрсрПроц   
--#M_ISOLAT

select @s6 = DepartmentID   
  from tDepartment  
 where Brief = 'СрПрСрСсЗдВ' 
 
select @s7 = DepartmentID   
  from tDepartment  
 where Brief = 'ПрсрПроцВ'                 

delete pResource
  from pResource --#M_ROWLOCK_INDEX(XPKpResource)
 where Spid = @@spid

 
insert pResource --#M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       VnAccID, -- счет внутреннего учета.
       1,
       @s1    --СрочСсудЗд 
  from #contract-- #M_NOLOCK_INDEX(0)
-- where LinkSysType = 'КрВ_Догов'
where VnAccID is not null                   
 group by VnAccID 
  
insert pResource-- #M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       VnAccID, -- счет внутреннего учета.
       2,
       @s2    --ПрсрСсудЗд 
  from #contract --#M_NOLOCK_INDEX(0)
 --where LinkSysType = 'КрВ_Догов' 
 where VnAccID is not null                   
 group by VnAccID 
 
insert pResource --#M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       VnAccID, -- счет внутреннего учета.
       3,
       @s3    --СрПрСрСсЗд  
  from #contract --#M_NOLOCK_INDEX(0)
 --where LinkSysType = 'КрВ_Догов' 
 where VnAccID is not null                   
 group by VnAccID  
  
insert pResource --#M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       VnAccID, -- счет внутреннего учета.
       4,
       @s4    --СрПрПрсСсЗ  
  from #contract --#M_NOLOCK_INDEX(0)
 --where LinkSysType = 'КрВ_Догов'   
 where VnAccID is not null                 
 group by VnAccID 
  
insert pResource-- #M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       VnAccID, -- счет внутреннего учета.
       5,
       @s5   --ПрсрПроц
  from #contract --#M_NOLOCK_INDEX(0)
-- where LinkSysType = 'КрВ_Догов'  
where VnAccID is not null                  
 group by VnAccID 

insert pResource-- #M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       VnAccID, -- счет внутреннего учета.
       6,
       @s6   --ПрсрПроц
  from #contract --#M_NOLOCK_INDEX(0)
-- where LinkSysType = 'КрВ_Догов'  
where VnAccID is not null                  
 group by VnAccID 

insert pResource-- #M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       VnAccID, -- счет внутреннего учета.
       7,
       @s7   --ПрсрПроц
  from #contract --#M_NOLOCK_INDEX(0)
-- where LinkSysType = 'КрВ_Догов'  
where VnAccID is not null                  
 group by VnAccID 



 
exec DepList_Rest
       @Date      = @RepDate

--select * from pResource
update #Contract
   set VnAccSsudRest = rs.Rest --isnull(rs.Rest,0)
  from #Contract     c --  #M_UPDLOCK_INDEX(0)
  inner join pDepResList  rs --#M_NOLOCK_INDEX(XPKpDepResList)
         on rs.spid = @@SPID
        and rs.ResourceID = c.VnAccID
		        and rs.Num        = 1   --СрочСсудЗд

update #Contract
   set VnAccPrSsudRest = rs.Rest --isnull(rs.Rest,0)
  from #Contract     c --  #M_UPDLOCK_INDEX(0)
  inner join pDepResList  rs --#M_NOLOCK_INDEX(XPKpDepResList)
         on rs.spid = @@SPID
        and rs.ResourceID = c.VnAccID
		        and rs.Num        = 2   --ПрсрСсудЗд

update #Contract
   set VnAccProcRest = rs.Rest --isnull(rs.Rest,0)
  from #Contract     c --  #M_UPDLOCK_INDEX(0)
  inner join pDepResList  rs --#M_NOLOCK_INDEX(XPKpDepResList)
         on rs.spid = @@SPID
        and rs.ResourceID = c.VnAccID
		        and rs.Num        = 3   --СрПрСрСсЗд

update #Contract
   set VnAccProcVRest = rs.Rest --isnull(rs.Rest,0)
  from #Contract     c --  #M_UPDLOCK_INDEX(0)
  inner join pDepResList  rs --#M_NOLOCK_INDEX(XPKpDepResList)
         on rs.spid = @@SPID
        and rs.ResourceID = c.VnAccID
		        and rs.Num        = 6   --СрПрСрСсЗдВ

update #Contract
   set VnAccPrPcocRest = isnull(rs.Rest,0)
  from #Contract     c --  #M_UPDLOCK_INDEX(0)
  inner join pDepResList  rs --#M_NOLOCK_INDEX(XPKpDepResList)
         on rs.spid = @@SPID
        and rs.ResourceID = c.VnAccID
		        and rs.Num        = 5   --ПрсрПроц



update #Contract
   set VnAccPrPcocVRest = isnull(rs.Rest,0)
  from #Contract     c --  #M_UPDLOCK_INDEX(0)
  inner join pDepResList  rs --#M_NOLOCK_INDEX(XPKpDepResList)
         on rs.spid = @@SPID
        and rs.ResourceID = c.VnAccID
		        and rs.Num        = 7   --ПрсрПроцВ

-------------  обновляем Вид обеспечения из доп атрибута договора обеспечения

update #Contract 
set VidObec = eav.Value
from #Contract 
left join tEntAttrValue eav
       on ObecID = eav.ObjectID
	   and eav.AttributeID = 10000001671 -- доп атрибут Тип обеспечения
	  where  FOObecID = 10000000371        -- ОбспИмущ

update #Contract 
set VidObec = eav.Value
from #Contract 
left join tEntAttrValue eav
       on ObecID = eav.ObjectID
	   and eav.AttributeID = 10000001672 -- доп атрибут Тип обеспечения
where FOObecID = 10000000372        -- ОбспГарПор

-- Обновляем Наименование поручителя
update #Contract 
set Poruch = case i.PropDealPart when 1 then rtrim(i.Name)
                                 when 0 then rtrim(i.Brief)
             end                    

from #Contract 
left join tDeal d
       on ObecID = d.DealID  

left join tInstitution i
       on d.InstitutionID = i.InstitutionID
-------- Обновляем номер договора обеспечения
update #Contract 
set NumObec = rtrim(d.Number)               

from #Contract 
left join tDeal d
       on ObecID = d.DealID  


--Обновляем категорию качества обеспечения

update #Contract 
set KatKatcOb = case d.NominalCourse when 1 then 'I категория'
                                     when 0.5 then 'II категория'
				end

from #Contract 
left join tDeal d
       on ObecID = d.DealID  


-------------Обновляем стоимости обеспечения
update #Contract 
set RinQTY = d.Qty,
    ZalQTY = d.InstQty,
	SprQTY = d.NominalQty             

from #Contract 
left join tDeal d
       on ObecID = d.DealID  

------ Обновляем категорию качества обслуживания долга и Финансовое положение (доп атрибуты на клиенте)
update #Contract 
set  KOD = eav.value  
 from #Contract           left join tEntAttrValue  eav
       on ClientID = eav.ObjectID
      and eav.AttributeID    = 10000001682 -- Доп апртибут "Качество обслуживание долга"

update #Contract 
set  FP = eav.value
from #Contract  left join tEntAttrValue  eav
       on ClientID = eav.ObjectID
      and eav.AttributeID    = 10000001681 -- Доп атрибут "Финансовое положение"

------находим группу риска и норму резервирования актуальная на дату отчета-----------   
update #Contract
   set R1    = convert(varchar,left(r.Brief, 1)),
       Risk = convert(varchar,r.ValueMin)       
  from #Contract  c,-- #M_UPDLOCK_INDEX(0)
 
   tRiskCtrRelation rcr,-- WITH (NOLOCK index=XAK1tRiskCtrRelation),
       tRisk            r --WITH (NOLOCK index=XPKtRisk),
     where r.RiskID = rcr.RiskID
   and rcr.DealID = c.ClientID /* :DealID */

   and rcr.RiskDate between (select max(RiskDate) from tRiskCtrRelation where DealID =ClientID  and RiskDate < @RepDate) and @RepDate

--- Обновление резервов---
update #Contract 
   set RasRez254 = rh.ReserveCalculated,
       SforRez254 = rh.ReserveToForming
   from #Contract
   left join tRPElement r
          on ContractID = r.ObjectID
   left join tRPElementHistory rh
           on r.RPElementID = rh.RPElementID
		   and @RepDate between rh.DateBegin and rh.DateEnd   -- в истории несколько записей тянем ту которая попадает на отчетную дату
	left join tRPPortfolio rp
	       on r.RPPortfolioID = rp.RPPortfolioID
		where rp.RPPortfolioKindID = 16   -- резерв на ссудную задолженность

update #Contract 
   set RasRez283 = rh.ReserveCalculated,
       SforRez283 = rh.ReserveToForming
   from #Contract
   left join tRPElement r
          on ContractID = r.ObjectID
   left join tRPElementHistory rh
           on r.RPElementID = rh.RPElementID
		   and @RepDate between rh.DateBegin and rh.DateEnd   -- в истории несколько записей тянем ту которая попадает на отчетную дату
	left join tRPPortfolio rp
	       on r.RPPortfolioID = rp.RPPortfolioID
		 where rp.RPPortfolioKindID =  6   -- резерв на лимиты


update #Contract 
   set RezProc =rh.ReserveToForming
       --SforRez283 = rh.ReserveToForming
   from #Contract
   left join tRPElement r
          on ContractID = r.ObjectID
   left join tRPElementHistory rh
           on r.RPElementID = rh.RPElementID
		   and @RepDate between rh.DateBegin and rh.DateEnd   -- в истории несколько записей тянем ту которая попадает на отчетную дату
	left join tRPPortfolio rp
	       on r.RPPortfolioID = rp.RPPortfolioID
		 where rp.RPPortfolioKindID =  29   -- резерв на лимиты


------ Тянем счета привязанные к договорам
update #Contract
set RasAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like 'РАСЧЕТЫ'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set SsudAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like 'ССУДНЫЙ'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set RezSsudAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like 'РЕЗЕРВЫ'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set RezLimitAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like 'РЕЗЕРВЫ_ПА'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set PrcAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like 'ПРОЦ_ТРЕБ'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set PrPrcAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like 'ПРВ_ПРОЦ'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set RezPrcAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like 'РЕЗ_ПРОЦ'
inner join tResource r
        on cal.ResourceID = r.ResourceID




                     



  

/*select * from pDepResList*/
/*select * from tContract c 
where c.InstrumentID in (10000000377,10000000378,10000000379) -- ФО ТБПотрКрд, ТБКредЛин, ТБТрнКрЛин
and (c.DateTo > @RepDate or c.DateTo = '19000101')
and c.DateFrom <= @RepDate*/

select * from #contract






/*select * 
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where name like 'Субконто%' SysName = 'OVERDPERCENT_DEPARTMENT_ID'
 */

/*
select * from tContract where ContractID =10000002628
select * from tContract where number = '02-21/15'
select * from tContractCredit where MainContractID =10000002628
select * from tContractCreditExt where ContractCreditID =10000006625
select * from tPercentType
select * from tConsRuleAccSync 
select * from tConsAccountLink  

select * from pResource    


select * from tCurrencyRate
select * from tEntAttrValue where AttributeID = 10000001685
*/
