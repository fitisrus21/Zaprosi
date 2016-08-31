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
,case i.PropDealPart when 1 then '������������ ����������� ���'
                     when 0 then '������������ ���������� ���'
end                   ClientType
,coalesce(ia.Name,ia1.Name,'��� ������')     Adress
,coalesce(eav.Value,'��� ������')            TipPred

,c.BankProductID
,bp.Name
,c.Number
,coalesce(ac.Name,'��� ������')              Cel

, case when c.BankProductID in (10000000002,10000000003) then cc.AmountAdd    -- ����� �������� ��� ���������� ��������� ������ ������
       else c.Amount                                   -- ����� �������� ��� ������ ������������� � ������� ���������
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
,@Date               DogEndPlan        -- ���� ���������
,@Date               DogEndPlanIzm     --���� ��������� � ������ ��������� � ��������


,@PRC                PRC
,@PRC                Prc_Pros
,cc.CreditPeriod
,DATEDIFF(DD, @RepDate, cc.CreditDateTo) AmounDaysEnd  -- ���.���� �� �����. (������� ��������� ��������� � ������ ������)


-- ����� ������
,@AccID               AccLimitID

,@money               AccLimitRest

,@AccID              VnAccID
,@money              VnAccSsudRest 
,@money              VnAccPrSsudRest
,@money              VnAccProcRest
,@money              VnAccProcVRest
,@money              VnAccPrPcocRest
,@money              VnAccPrPcocVRest

,wor.ChildID         ObecID                --ID �������� �����������
,d.InstrumentID      FOObecID              -- FO �������� �����������    
,@txt                VidObec              ---��� �����������
,@txt                Poruch               -- ����������
,@txt                NumObec               -- ����� �������� �����������
,@txt                KatKatcOb               -- �������� �������� �����������   
,@money              RinQTY                -- �������� ���������
,@money              ZalQTY                -- ��������� ���������
,@money              SprQTY                -- ������������ ���������

,@txt                KOD                   -- �������� ������������ �����
,@txt                FP                    -- ���������� ���������

,@txt                R1                     -- ��������� ��������
,@txt                Risk                   -- ����� ��������������

--������ �� ���������� �������� ----
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
	   and il.DocTypeID = 35001428  -- ���������(����)
       and il.Failed = 0   -- 0 - ���� �� �������� ����
       and il.RegTmp = 0   -- 0 - ���� �� ���������

left join tInstAddress  ia
        on i.InstitutionID = ia.InstitutionID
	   and ia.AddressTypeID = 1  -- ����������� �����
	   and i.PropDealPart = 1     -- �� ����
	   and ia.Sign!=2             -- ������ ������� �� ��������������
left join tInstAddress  ia1
        on i.InstitutionID = ia1.InstitutionID
	   and ia1.AddressTypeID = 5    -- ����� ����� �����������
	   and i.PropDealPart = 0     -- ��� ����
	    and ia1.Sign!=2             -- ������ ������� �� ��������������
	   	
left join tAimContent ac
       on ac.DealID = c.ContractID
left join tEntAttrValue eav
       on c.InstitutionID = eav.ObjectID
	   and eav.AttributeID = 10000001671 -- ������� �������� �������������������

--����� �����������
left join tWarObjectRelation wor 
       on c.ContractID = wor.ParentID
left join tdeal d
       on   d.DealID = wor.ChildID

-- ��� ������� ��� �������� ����������� ���������

 
where c.InstrumentID in (10000000377,10000000378,10000000379) -- �� ���������, ���������, ����������
and (c.DateTo > @RepDate or c.DateTo = '19000101') -- ���� �������� ������ �������� ���� ��� ����������� ��������� 19000101
and c.DateFrom <= @RepDate          -- ���� ������� ������ ����� ���� ������

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


----- ��������� ����� ������ � ���� �������-----
update #contract
set OKVED = coalesce((select  rtrim(r.Reuters) + ', ' 
             from tReuters r
			 where   #contract.InstitutionID = r.InstitutionID
                    and r.TradingSysID = 8
             for xml path('')),'')
----------------------------------------------

--- ��������� ���� ����������� ���������------
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
/* % ������ �� ������� ������������� */

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
       @PercentType = 201,        -- �������� �� ������� ������� ������������� �� ���������������� ������� 
--     @PercentType = 210,        -- �������� �� ������������ ������� ������������� �� ���������������� �������       
--     @PercentType = 216,       -- ������ � ���� �� ������������ ������� ������������� �� ��������������� ��������       

       @Alg         = 6


update #Contract
   set Prc = isnull(p.Prcnt,0)
  from #Contract ca   --#M_UPDLOCK
 inner join pAPI_ACCR_ObjInterestRate p --#M_NOLOCK_INDEX(XPKpAPI_ACCR_ObjInterestRate)
         on p.ObjectID = ca.ContractID
        and p.SPID = @@SPID
------------------------------------------------------------------
/* % ������ �� ������������ ������������� */  

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
--     @PercentType = 201,         -- �������� �� ������� ������� ������������� �� ���������������� ������� 
       @PercentType = 210,        -- �������� �� ������������ ������� ������������� �� ���������������� �������       
--     @PercentType = 216,       -- ������ � ���� �� ������������ ������� ������������� �� ��������������� ��������  
       @Alg         = 6


update #Contract
   set Prc_Pros = isnull(p.Prcnt,0)
  from #Contract ca   --#M_UPDLOCK
 inner join pAPI_ACCR_ObjInterestRate p --#M_NOLOCK_INDEX(XPKpAPI_ACCR_ObjInterestRate)
         on p.ObjectID = ca.ContractID
        and p.SPID = @@SPID
-------------------------------------------------------------------------------

--- ���� ������ � ��� �������---------
update #Contract
set AccLimitID = cal.ResourceID, LimitAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and (cra.Brief like '��_���_�' or cra.Brief like '��_�_��') 
inner join tResource r
        on cal.ResourceID = r.ResourceID
-------- ������� �� ����� ������----------

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
--- ���� ����������� �����---------
update #Contract
set VnAccID = cal.ResourceID--, AccLimit =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like '�������' 
inner join tResource r
        on cal.ResourceID = r.ResourceID
----------


--������� �� ���������� �����
select @s1 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'LOAN_DEBTS_DEPARTMENT_ID'       --���������� 
--#M_ISOLAT
 
select @s2 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'OVERDUE_DEBTS_DEPARTMENT_ID'    --���������� 
--#M_ISOLAT 
 
select @s3 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'PERCENT_DEPARTMENT_ID'          --����������
--#M_ISOLAT 
  
select @s4 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'PERCENT_OVERDUE_DEBTS_DEPARTME' --���������� 
--#M_ISOLAT 
 
select @s5 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'OVERDPERCENT_DEPARTMENT_ID'     --��������   
--#M_ISOLAT

select @s6 = DepartmentID   
  from tDepartment  
 where Brief = '�����������' 
 
select @s7 = DepartmentID   
  from tDepartment  
 where Brief = '���������'                 

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
       VnAccID, -- ���� ����������� �����.
       1,
       @s1    --���������� 
  from #contract-- #M_NOLOCK_INDEX(0)
-- where LinkSysType = '���_�����'
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
       VnAccID, -- ���� ����������� �����.
       2,
       @s2    --���������� 
  from #contract --#M_NOLOCK_INDEX(0)
 --where LinkSysType = '���_�����' 
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
       VnAccID, -- ���� ����������� �����.
       3,
       @s3    --����������  
  from #contract --#M_NOLOCK_INDEX(0)
 --where LinkSysType = '���_�����' 
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
       VnAccID, -- ���� ����������� �����.
       4,
       @s4    --����������  
  from #contract --#M_NOLOCK_INDEX(0)
 --where LinkSysType = '���_�����'   
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
       VnAccID, -- ���� ����������� �����.
       5,
       @s5   --��������
  from #contract --#M_NOLOCK_INDEX(0)
-- where LinkSysType = '���_�����'  
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
       VnAccID, -- ���� ����������� �����.
       6,
       @s6   --��������
  from #contract --#M_NOLOCK_INDEX(0)
-- where LinkSysType = '���_�����'  
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
       VnAccID, -- ���� ����������� �����.
       7,
       @s7   --��������
  from #contract --#M_NOLOCK_INDEX(0)
-- where LinkSysType = '���_�����'  
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
		        and rs.Num        = 1   --����������

update #Contract
   set VnAccPrSsudRest = rs.Rest --isnull(rs.Rest,0)
  from #Contract     c --  #M_UPDLOCK_INDEX(0)
  inner join pDepResList  rs --#M_NOLOCK_INDEX(XPKpDepResList)
         on rs.spid = @@SPID
        and rs.ResourceID = c.VnAccID
		        and rs.Num        = 2   --����������

update #Contract
   set VnAccProcRest = rs.Rest --isnull(rs.Rest,0)
  from #Contract     c --  #M_UPDLOCK_INDEX(0)
  inner join pDepResList  rs --#M_NOLOCK_INDEX(XPKpDepResList)
         on rs.spid = @@SPID
        and rs.ResourceID = c.VnAccID
		        and rs.Num        = 3   --����������

update #Contract
   set VnAccProcVRest = rs.Rest --isnull(rs.Rest,0)
  from #Contract     c --  #M_UPDLOCK_INDEX(0)
  inner join pDepResList  rs --#M_NOLOCK_INDEX(XPKpDepResList)
         on rs.spid = @@SPID
        and rs.ResourceID = c.VnAccID
		        and rs.Num        = 6   --�����������

update #Contract
   set VnAccPrPcocRest = isnull(rs.Rest,0)
  from #Contract     c --  #M_UPDLOCK_INDEX(0)
  inner join pDepResList  rs --#M_NOLOCK_INDEX(XPKpDepResList)
         on rs.spid = @@SPID
        and rs.ResourceID = c.VnAccID
		        and rs.Num        = 5   --��������



update #Contract
   set VnAccPrPcocVRest = isnull(rs.Rest,0)
  from #Contract     c --  #M_UPDLOCK_INDEX(0)
  inner join pDepResList  rs --#M_NOLOCK_INDEX(XPKpDepResList)
         on rs.spid = @@SPID
        and rs.ResourceID = c.VnAccID
		        and rs.Num        = 7   --���������

-------------  ��������� ��� ����������� �� ��� �������� �������� �����������

update #Contract 
set VidObec = eav.Value
from #Contract 
left join tEntAttrValue eav
       on ObecID = eav.ObjectID
	   and eav.AttributeID = 10000001671 -- ��� ������� ��� �����������
	  where  FOObecID = 10000000371        -- ��������

update #Contract 
set VidObec = eav.Value
from #Contract 
left join tEntAttrValue eav
       on ObecID = eav.ObjectID
	   and eav.AttributeID = 10000001672 -- ��� ������� ��� �����������
where FOObecID = 10000000372        -- ����������

-- ��������� ������������ ����������
update #Contract 
set Poruch = case i.PropDealPart when 1 then rtrim(i.Name)
                                 when 0 then rtrim(i.Brief)
             end                    

from #Contract 
left join tDeal d
       on ObecID = d.DealID  

left join tInstitution i
       on d.InstitutionID = i.InstitutionID
-------- ��������� ����� �������� �����������
update #Contract 
set NumObec = rtrim(d.Number)               

from #Contract 
left join tDeal d
       on ObecID = d.DealID  


--��������� ��������� �������� �����������

update #Contract 
set KatKatcOb = case d.NominalCourse when 1 then 'I ���������'
                                     when 0.5 then 'II ���������'
				end

from #Contract 
left join tDeal d
       on ObecID = d.DealID  


-------------��������� ��������� �����������
update #Contract 
set RinQTY = d.Qty,
    ZalQTY = d.InstQty,
	SprQTY = d.NominalQty             

from #Contract 
left join tDeal d
       on ObecID = d.DealID  

------ ��������� ��������� �������� ������������ ����� � ���������� ��������� (��� �������� �� �������)
update #Contract 
set  KOD = eav.value  
 from #Contract           left join tEntAttrValue  eav
       on ClientID = eav.ObjectID
      and eav.AttributeID    = 10000001682 -- ��� �������� "�������� ������������ �����"

update #Contract 
set  FP = eav.value
from #Contract  left join tEntAttrValue  eav
       on ClientID = eav.ObjectID
      and eav.AttributeID    = 10000001681 -- ��� ������� "���������� ���������"

------������� ������ ����� � ����� �������������� ���������� �� ���� ������-----------   
update #Contract
   set R1    = convert(varchar,left(r.Brief, 1)),
       Risk = convert(varchar,r.ValueMin)       
  from #Contract  c,-- #M_UPDLOCK_INDEX(0)
 
   tRiskCtrRelation rcr,-- WITH (NOLOCK index=XAK1tRiskCtrRelation),
       tRisk            r --WITH (NOLOCK index=XPKtRisk),
     where r.RiskID = rcr.RiskID
   and rcr.DealID = c.ClientID /* :DealID */

   and rcr.RiskDate between (select max(RiskDate) from tRiskCtrRelation where DealID =ClientID  and RiskDate < @RepDate) and @RepDate

--- ���������� ��������---
update #Contract 
   set RasRez254 = rh.ReserveCalculated,
       SforRez254 = rh.ReserveToForming
   from #Contract
   left join tRPElement r
          on ContractID = r.ObjectID
   left join tRPElementHistory rh
           on r.RPElementID = rh.RPElementID
		   and @RepDate between rh.DateBegin and rh.DateEnd   -- � ������� ��������� ������� ����� �� ������� �������� �� �������� ����
	left join tRPPortfolio rp
	       on r.RPPortfolioID = rp.RPPortfolioID
		where rp.RPPortfolioKindID = 16   -- ������ �� ������� �������������

update #Contract 
   set RasRez283 = rh.ReserveCalculated,
       SforRez283 = rh.ReserveToForming
   from #Contract
   left join tRPElement r
          on ContractID = r.ObjectID
   left join tRPElementHistory rh
           on r.RPElementID = rh.RPElementID
		   and @RepDate between rh.DateBegin and rh.DateEnd   -- � ������� ��������� ������� ����� �� ������� �������� �� �������� ����
	left join tRPPortfolio rp
	       on r.RPPortfolioID = rp.RPPortfolioID
		 where rp.RPPortfolioKindID =  6   -- ������ �� ������


update #Contract 
   set RezProc =rh.ReserveToForming
       --SforRez283 = rh.ReserveToForming
   from #Contract
   left join tRPElement r
          on ContractID = r.ObjectID
   left join tRPElementHistory rh
           on r.RPElementID = rh.RPElementID
		   and @RepDate between rh.DateBegin and rh.DateEnd   -- � ������� ��������� ������� ����� �� ������� �������� �� �������� ����
	left join tRPPortfolio rp
	       on r.RPPortfolioID = rp.RPPortfolioID
		 where rp.RPPortfolioKindID =  29   -- ������ �� ������


------ ����� ����� ����������� � ���������
update #Contract
set RasAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like '�������'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set SsudAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like '�������'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set RezSsudAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like '�������'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set RezLimitAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like '�������_��'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set PrcAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like '����_����'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set PrPrcAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like '���_����'
inner join tResource r
        on cal.ResourceID = r.ResourceID

update #Contract
set RezPrcAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
		and cra.Brief like '���_����'
inner join tResource r
        on cal.ResourceID = r.ResourceID




                     



  

/*select * from pDepResList*/
/*select * from tContract c 
where c.InstrumentID in (10000000377,10000000378,10000000379) -- �� ���������, ���������, ����������
and (c.DateTo > @RepDate or c.DateTo = '19000101')
and c.DateFrom <= @RepDate*/

select * from #contract






/*select * 
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where name like '��������%' SysName = 'OVERDPERCENT_DEPARTMENT_ID'
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
