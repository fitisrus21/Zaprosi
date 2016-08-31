Declare
        @RepDate dsoperday,
		@money DSMONEY,
		@PRC DSFLOAT,
		@AccID DSIDENTIFIER,
		@type int

select @RepDate = '20160729'
if OBJECT_ID('tempdb..#contract') is not null drop table #contract

select 
c.ContractID,
c.InstrumentID,
c.FundID,
i.Brief,
c.Number,
@PRC    prc,
c.DateFrom,
c.DateTo,
cc.CreditDateTo,
@AccID    VnSsudAcc,
@money    OborotVnSsud,


@AccID    SsudAcc, 
@money    OborotSsud,
@type     SsudType, 


@AccID    RezLimAcc, 
@money    OborotRezLim,
@AccID    RezAcc, 
@money    OborotRez,
@RepDate  RepDate


into #contract

 from tContract c
 left join tContractCredit cc
 on c.ContractID = cc.ContractCreditID
 inner join tInstitution i
         on c.InstitutionID = i.InstitutionID
where c.InstrumentID in (10000000377,10000000378,10000000379) -- ФО ТБПотрКрд, ТБКредЛин, ТБТрнКрЛин
and (c.DateTo >= @RepDate or c.DateTo='19000101')

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


--- счет лимита --------
update #Contract
set SsudAcc = cal.ResourceID--, LimitAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
             and (cra.Brief like 'КР_ЛИМ_З' or cra.Brief like 'КР_Л_НИ') 
inner join tResource r
        on cal.ResourceID = r.ResourceID

--счет ссудный
update #Contract
set SsudAcc = cal.ResourceID--, LimitAcc =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
             and cra.Brief like 'Ссудный'
inner join tResource r
        on cal.ResourceID = r.ResourceID


--- счет внутреннего учета---------
update #Contract
set VnSsudAcc = cal.ResourceID--, AccLimit =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
             and cra.Brief like 'ВНУТРЕН' 
inner join tResource r
        on cal.ResourceID = r.ResourceID


update #Contract
set RezLimAcc = cal.ResourceID--, AccLimit =RTRIM(r.brief)
from #Contract c 
inner join tConsAccountLink cal
        on c.ContractID = cal.ContractID
inner join tConsRuleAccSync cra
        on cal.RuleID = cra.RuleID
             and cra.Brief like 'РЕЗЕРВЫ_ПА' 
inner join tResource r
        on cal.ResourceID = r.ResourceID

---- Обороты по ссудному счету
update #Contract
set OborotSsud = op.qty, SsudType = op.CharType
from #Contract c 
inner join tOperPart op
        on c.SsudAcc = op.ResourceID
		and op.OperDate = @RepDate




select * from #contract
