Declare @REST DSMONEY
       ,@Prc  DSFLOAT
       ,@RepDate DSOPERDAY

select @RepDate = getdate()


if OBJECT_ID('tempdb..#Contract') is not null  drop table #Contract

select     c.ContractID       CredDogID
          ,c.InstrumentID
          ,c.Number           CredDogNum
		  ,ins.InstitutionID  ClientID 
          , case when ins.PropDealPart = 0 then  ins.Name + ' ' + ins.Name1 + ' '+ ins.Name2
                 else ins.Name
            end               ClientName  
          ,bp.Name            BPName
		  ,case when c.InstrumentID= 10000000377 then c.Amount
		       when c.InstrumentID=10000000378 and cc.LimitType = 1 then c.Amount
		       else cc.AmountAdd
		    end               Amount
          ,c.BankProductID    CredProdID
          ,f.FundID
          ,f.Brief            Currencie
          
		  
		  ,cal.ResourceID     AccSsudID
          ,rs.Brief           AccSsudNo
          ,isnull(@REST,0)    AccSsudRest

		   ,isnull(calPrSSud.ResourceID,0)     AccPrSsudID
          ,isnull(rPrSSud.Brief,0)           AccPrSsudNo
          ,isnull(@REST,0)    AccPrSsudRest
		
	      ,isnull(calPr.ResourceID,0)  AccPrID 
		  ,isnull(rPr.Brief,0)         AccPrNO
		  ,isnull(@REST,0)    AccPrRest  
	
	     	
		  ,calLim.ResourceID  AccLimID 
		  ,rLim.Brief         AccLimNO
		  ,isnull(@REST,0)    AccLimRest  
        


		  ,@Prc               Prc
          ,c.DateFrom         DealDate 
          ,cc.CreditDateTo    DealEnd          
          ,0                  R1
		  ,'0.000'            Risk
		 
          ,COALESCE(cRezGen.ResourceID, cRezPar.ResourceID) RezAccID
          ,@REST              AccRezRest 

INTO #Contract
--select * from   #CredInfo            
from tContract c
left join tFund f
       on c.FundID = f.FundID
left join tInstitution ins
       on c.InstitutionID = ins.InstitutionID
left join tBankProduct  bp
       on c.BankProductID = bp.BankProductID

left join tConsAccountLink calLim
       on c.ContractID = calLim.ContractID
      and calLim.RuleID in (select TypeAccLinkID from tTypeAccLink where Brief='КР_Л_НИ' or Brief='КР_ЛИМ_З' ) 
left join tResource rLim
       on calLim.ResourceID=rLim.ResourceID

left join tConsAccountLink calPrSSud
       on c.ContractID = calPrSSud.ContractID
      and calPrSSud.RuleID in (select TypeAccLinkID from tTypeAccLink where Brief='ПР_ССУДНЫЙ') 
left join tResource rPrSSud
       on calPrSSud.ResourceID=rPrSSud.ResourceID

	   left join tConsAccountLink calPr
       on c.ContractID = calPrSSud.ContractID
      and calPr.RuleID in (select TypeAccLinkID from tTypeAccLink where Brief='ПРОЦ_ТРЕБ') 
left join tResource rPr
       on calPr.ResourceID=rPr.ResourceID


left join tConsAccountLink cal
       on c.ContractID = cal.ContractID
      and cal.RuleID in (select TypeAccLinkID from tTypeAccLink where Brief='ССУДНЫЙ')   --ССУДНЫЙ







left join tConsAccountLink cRezGen
       on c.ContractID = cRezGen.ContractID
      and cRezGen.RuleID in (select TypeAccLinkID from tTypeAccLink where Brief='РЕЗЕРВЫ')   --ССУДНЫЙ
left join tResource rs
       on rs.ResourceID = cal.ResourceID  
inner join tContractCredit cc
       on c.ContractID = cc.ContractCreditID
left join tContract cp
       on cc.MainContractID = cp.ContractID
left join tConsAccountLink cRezPar
       on c.ContractID = cRezPar.ContractID
      and cRezPar.RuleID in (select TypeAccLinkID from tTypeAccLink where Brief='РЕЗЕРВЫ')   --ССУДНЫЙ
where c.IsActive=2
and c.InstrumentID not in  (3477,10000000379) -- доп и транши
--and c.ContractID=10000002744




---- для линий находим сумму срочной задолженности для всех ссудных счетов-------

if OBJECT_ID('tempdb..#ContractTransh') is not null  drop table #ContractTransh

select 
       c.ContractID       ContractID,
	   c.Number             num,
       cal.ResourceID      ResourceID,
	   LTRIM(Rtrim(r.brief)) AccNo,
	   @rest                  ResourceRest,
	   cc.MainContractID    LineID
into #ContractTransh

from tConsAccountLink cal
inner join tContract c
    on cal.ContractID=c.ContractID
	and c.InstrumentID=10000000379
	and c.IsActive=2
inner join tContractCredit cc
    on c.ContractID=cc.ContractCreditID
inner join tResource r
    on cal.ResourceID= r.ResourceID
where cal.RuleID in (select TypeAccLinkID from tTypeAccLink where Brief='ССУДНЫЙ')

delete pResource where SPID = @@SPID
insert into pResource (SPID, ResourceID)
select distinct @@SPID, ResourceID from #ContractTransh 
--where AccSsudID is not null

exec AccList_Rest @Date     = @RepDate 
                 ,@CalcType = 1

update #ContractTransh set ResourceRest = p.Rest
from pResList p where #ContractTransh.ResourceID = p.ResourceID and p.SPID = @@SPID --and #Contract.FundID=2 

--select distinct LineID,AccNo,ResourceRest from #ContractTransh 

if OBJECT_ID('tempdb..#AccLineRes') is not null  drop table #AccLineRes
select distinct --ResourceID ResourceID 
            sum(ResourceRest)   ResourceRest
			,lineid  lineid
into #AccLineRes
from #ContractTransh
GROUP BY lineid 

update #Contract
set #Contract.AccSsudRest=#AccLineRes.ResourceRest,
    #Contract.CredDogID=#AccLineRes.Lineid
from #AccLineRes, #Contract
where #AccLineRes.lineid = #Contract.CredDogID

/*inner join #Contract
on #AccLineRes.lineid = #Contract.CredDogID

group by #AccLineRes.Lineid*/


------находим группу риска и норму резервирования-----------   
delete pAPI_CCred_CCredID
  from pAPI_CCred_CCredID -- #M_ROWLOCK_INDEX (XPKpAPI_CCred_CCredID)
 where spid = @@SPID 
 
insert pAPI_CCred_CCredID --#M_WITH_ROWLOCK
       (
       SPID
      ,CCredID
       )
select @@SPID
      ,CredDogID
  from #Contract --#M_NOLOCK_INDEX(0)
  
exec API_CCred_GetListQualityByID
       @Date = @RepDate 
       
update #Contract
   set R1    = convert(varchar,left(r.QualityBrief, 1)),
       Risk = convert(varchar,r.Norm)       
    
      --,PlanPog = r.Norm
  from #Contract  c-- #M_UPDLOCK_INDEX(0)
 inner join pAPI_CCred_FindQuality  r  -- #M_NOLOCK_INDEX(XPKpAPI_CCred_FindQuality)
         on r.spid = @@SPID
        and r.ContractCreditID = c.CredDogID 
/*

---------------Поиск счета лимита-------------------------------
update #Contract
   set -- #Contract.AccLimID  = cal.ResourceID
       --,
	   #Contract.AccLimNO = LTRIM(rtrim(r.brief))--convert(varchar(20),LTRIM(rtrim(r.brief)))
from   #Contract
inner join tConsAccountLink cal
       on #Contract.CredDogID = cal.ContractID
      and cal.RuleID in (select TypeAccLinkID from tTypeAccLink where Brief='КР_Л_НИ' or Brief='КР_ЛИМ_З' ) 
left join tResource r
     on cal.ResourceID=r.ResourceID
     
*/

/* остаток на счете Лимита */ 
delete pResource where SPID = @@SPID
insert into pResource (SPID, ResourceID)
select distinct @@SPID, AccLimID from #Contract 
where AccLimID is not null

exec AccList_Rest @Date     = @RepDate 
                 ,@CalcType = 1

update #Contract set AccLimRest = -1*p.Rest
from pResList p where #Contract.AccLimID = p.ResourceID and p.SPID = @@SPID

/* остаток на счете Проценты */ 
delete pResource where SPID = @@SPID
insert into pResource (SPID, ResourceID)
select distinct @@SPID, AccPrID from #Contract 
where AccPrID is not null

exec AccList_Rest @Date     = @RepDate 
                 ,@CalcType = 1

update #Contract set AccPrRest = -1*p.Rest
from pResList p where #Contract.AccPrID = p.ResourceID and p.SPID = @@SPID




/*остаток на просроченной ссудной задолженности*/
delete pResource where SPID = @@SPID
insert into pResource (SPID, ResourceID)
select distinct @@SPID, AccPrSsudID from #Contract 
where AccLimID is not null

exec AccList_Rest @Date     = @RepDate 
                 ,@CalcType = 1

update #Contract set AccPrSsudRest = -1*p.Rest
from pResList p where #Contract.AccPrSsudID = p.ResourceID and p.SPID = @@SPID
and #Contract.AccPrSsudID is not null



/* остаток на ССУДНОМ счете */ 
/*
delete pResource where SPID = @@SPID
insert into pResource (SPID, ResourceID)
select distinct @@SPID, AccSsudID from #Contract 
where AccSsudID is not null

exec AccList_Rest @Date     = @RepDate 
                 ,@CalcType = 1

update #Contract set AccSsudRest = p.Rest
from pResList p where #Contract.AccSsudID = p.ResourceID and p.SPID = @@SPID and #Contract.FundID=2 

update #Contract set AccSsudRest = p.RestBs
from pResList p where #Contract.AccSsudID = p.ResourceID and p.SPID = @@SPID and #Contract.FundID!=2 
*/

/* остаток на РЕЗЕРВНОМ счете */ 
delete pResource where SPID = @@SPID
insert into pResource (SPID, ResourceID)
select distinct @@SPID, RezAccID from #Contract
where RezAccID is not null


exec AccList_Rest @Date     = @RepDate 
                 ,@CalcType = 1

update #Contract set AccRezRest = p.Rest*-1
from pResList p where #Contract.RezAccID = p.ResourceID and p.SPID = @@SPID

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
       CredDogID,
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
  from #Contract ca   --#M_UPDLOCK
 inner join pAPI_ACCR_ObjInterestRate p --#M_NOLOCK_INDEX(XPKpAPI_ACCR_ObjInterestRate)
         on p.ObjectID = ca.CredDogID
        and p.SPID = @@SPID


select ClientName
		,CredDogNum
		,Prc
		,Currencie
		,BPName
		,Amount
		,DealDate
		,DealEnd
	
		--,AccLimNO
		,AccLimRest
	
	    -- ,AccSsudID
	--	,AccSsudNo
		,AccSsudRest
		,AccPrSsudRest
    --   ,@RepDate RepDate 
from #Contract