declare @DateRep dsoperday,
        @s1        DSIDENTIFIER      --����������    RestSsud               
       ,@s2        DSIDENTIFIER       --����������   RestPrSsud           
       ,@s3        DSIDENTIFIER       --����������   RestSrPrc           
       ,@s4        DSIDENTIFIER       --����������   RestPrcPrSsud          
       ,@s5        DSIDENTIFIER       --��������     RestPrPrc
	   ,@s6        DSIDENTIFIER       --����������   RestPrPrcPrSsud   
	   ,@ContractID  DSIDENTIFIER


select @DateRep='20160525'
select @ContractID=ID 
from tDocMark where SPID=@@SPID
and type = 119

select @ContractID = 10000002745

create table #Account
       (
       ContractID    DSIDENTIFIER 
      ,LinkSysType   DSBRIEFNAME
      ,ResourceID    DSIDENTIFIER       
	  ,Rest          DSMONEY
	   )   
create table #Result
      (
	  Client         varchar(60) 	     null
      ,Number        varchar(10)         null
       ,DateDog       DSOPERDAY          null 
	  ,Limit         DSMONEY             null
	  ,Prc           DSFLOAT             null
	  , CredDogID    DSIDENTIFIER        null
       ,InstrumentID  DSIDENTIFIER        null
       ,FundID         DSIDENTIFIER       null

      ,RestNeusZaCredit          DSMONEY null -- �� �����������
      ,RestNeusZaPrc          DSMONEY    null -- �� �����������
	  ,RestPrPrc          DSMONEY        null
	  ,RestSrPrc          DSMONEY        null
	  ,RestPrSsud          DSMONEY       null  
	  ,RestSsud          DSMONEY         null 
	  ,RestPrcPrSsud           DSMONEY   null
	  ,RestPrPrcPrSsud           DSMONEY null
	  )  

insert into #Result (Client, Number, DateDog, Limit, CredDogID, InstrumentID, FundID)
select 
	 case when ins.PropDealPart = 0 then  ins.Name + ' ' + ins.Name1 + ' '+ ins.Name2
					 else ins.Name
				end  
	,c.Number
	,c.DateFrom
	,case when c.InstrumentID= 10000000377 then 0
                       when c.InstrumentID=10000000378 and cc.LimitType = 1 then c.Amount
                       else cc.AmountAdd
                    end               
	,@ContractID
	,c.InstrumentID
	,c.FundID
from   tInstitution ins, tContract c, tContractCredit cc
where c.ContractID=@ContractID
and c.InstitutionID=ins.InstitutionID
and c.ContractID=cc.ContractCreditID  	

--// ���������� ������
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
  from #Result  -- #M_NOLOCK_INDEX(0)      

exec Mass_CreditPrc
       @BeginDate   = @DateRep,
       @EndDate     = @DateRep,
       @PercentType = 201,
       @Alg         = 6


update #Result
   set Prc = isnull(p.Prcnt,0)
  from #Result ca   --#M_UPDLOCK
 inner join pAPI_ACCR_ObjInterestRate p --#M_NOLOCK_INDEX(XPKpAPI_ACCR_ObjInterestRate)
         on p.ObjectID = ca.CredDogID
        and p.SPID = @@SPID

--����� �������� ������ �� ���

update #Result
   set RestSsud = ABS(ps.qty)
  from #Result r   --#M_UPDLOCK
 inner join tPaySchedule ps --#M_NOLOCK_INDEX(XPKpAPI_ACCR_ObjInterestRate)
         on r.CredDogID = ps.ContractID
       -- and ABS(Qty)
		and DATEPART(MM,@DateRep) = DATEPART(MM, @DateRep)
       and DatePay > @DateRep
	   and ps.PayType=206	-- ��������� ������� ������� �������������
		

update #Result
   set RestSrPrc = ABS(ps.qty)
  from #Result r   --#M_UPDLOCK
 inner join tPaySchedule ps --#M_NOLOCK_INDEX(XPKpAPI_ACCR_ObjInterestRate)
         on r.CredDogID = ps.ContractID
       -- and ABS(Qty)
		and DATEPART(MM,@DateRep) = DATEPART(MM, @DateRep)
       and DatePay > @DateRep
	   and ps.PayType=201	-- ��������� ������� ���������
	   
	   		
    
/*

select ABS(Qty),  * from tPaySchedule where ContractID = 10000002745

and DATEPART(MM,DatePay) = DATEPART(MM, GetDate())
and DatePay > GetDate()

*/
	      
exec FCD_Cons_tProperty
         @PropType = 67  --RESDEP_ACC_TYPE 

insert #Account --#M_WITH_ROWLOCK
       (
       ContractID  
      ,LinkSysType 
      ,ResourceID    
      ,Rest        
       )
select @ContractID
      ,p.Brief
      ,al.ResourceID
      ,0
  from --tDocmark             dm --  #M_NOLOCK_INDEX(XPKtDocmark)
-- inner join
  tConsAccountLink         al --  #M_NOLOCK_INDEX(XIE1tConsAccountLink)
         /*on al.ContractID = @ContractID
        and al.OnDate              <= @DateRep
        and (al.DateLast > @DateRep or al.DateLast = '19000101')  */         
 inner join tConsRuleAccSync         ra  -- #M_NOLOCK_INDEX(XPKtConsRuleAccSync)
         on ra.RuleID  = al.RuleID
        and ra.RelType = 1
--        and ra.Status  = 0  --����� ���������
 inner join pAPI_Property_Value      p --   #M_NOLOCK_INDEX(XPKpAPI_Property_Value)
         on p.SPID  = @@SPID
        and p.Value = ra.PropVal
        and p.Brief like '���_�����'--CONVERT(NCHAR,p.Brief) in ( '���_�����')  
 where --dm.SPID = @@spid
   --and dm.Type = 119  
   al.ContractID =  @ContractID
       and al.OnDate              <= @DateRep
        and (al.DateLast > @DateRep or al.DateLast = '19000101')      
--#M_FORCEORDER
select * from #Account

select @s1 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'LOAN_DEBTS_DEPARTMENT_ID'       --���������� 
--#M_ISOLAT
 
select @s2 = ID   
  from tConfigParam -- #M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'OVERDUE_DEBTS_DEPARTMENT_ID'    --���������� 
--#M_ISOLAT 
 
select @s3 = ID   
  from tConfigParam -- #M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'PERCENT_DEPARTMENT_ID'          --����������
--#M_ISOLAT 
  
select @s4 = ID   
  from tConfigParam  --#M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'PERCENT_OVERDUE_DEBTS_DEPARTME' --���������� 
--#M_ISOLAT 
 
select @s5 = ID   
  from tConfigParam -- #M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'OVERDPERCENT_DEPARTMENT_ID'     --��������  
 
 select @s6 = ID   
  from tConfigParam -- #M_NOLOCK_INDEX(XAK0tConfigParam)
 where SysName = 'OVERDPRC_OVERDDEBTS_DEPARTM_ID' --����������

delete pResource
  from pResource-- #M_ROWLOCK_INDEX(XPKpResource)
 where Spid = @@spid 
 
insert pResource --#M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       ResourceID, -- ���� ����������� �����.
       1,
       @s1    --���������� 
  from #Account-- #M_NOLOCK_INDEX(0)
 where LinkSysType = '���_�����'                   
 group by ResourceID 
  
insert pResource-- #M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       ResourceID, -- ���� ����������� �����.
       2,
       @s2    --���������� 
  from #Account --#M_NOLOCK_INDEX(0)
 where LinkSysType = '���_�����'                   
 group by ResourceID 
 
insert pResource-- #M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       ResourceID, -- ���� ����������� �����.
       3,
       @s3    --����������  
  from #Account-- #M_NOLOCK_INDEX(0)
 where LinkSysType = '���_�����'                   
 group by ResourceID  
  
insert pResource-- #M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       ResourceID, -- ���� ����������� �����.
       4,
       @s4    --����������  
  from #Account --#M_NOLOCK_INDEX(0)
 where LinkSysType = '���_�����'                   
 group by ResourceID 
  
insert pResource --#M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       ResourceID, -- ���� ����������� �����.
       5,
       @s5   --��������
  from #Account --#M_NOLOCK_INDEX(0)
 where LinkSysType = '���_�����'                   
 group by ResourceID 
 
 insert pResource --#M_WITH_ROWLOCK
       (
       SPID,
       ResourceID,
       Num,
       DepID1  
       )
select @@spid,
       ResourceID, -- ���� ����������� �����.
       6,
       @s6   --���������� 
  from #Account --#M_NOLOCK_INDEX(0)
 where LinkSysType = '���_�����'                   
 group by ResourceID 
--select * from pResource  where spid = @@SPID

exec DepList_Rest
       @Date      = @DateRep


update #Result
set RestPrPrc=drl.rest
from pDepResList  drl
where drl.spid=@@SPID
and drl.Num=5

update #Result
set RestPrSsud=drl.rest
from pDepResList  drl
where drl.spid=@@SPID
and drl.Num=2   


update #Result
set RestPrcPrSsud=drl.rest
from pDepResList  drl
where drl.spid=@@SPID
and drl.Num=4   

update #Result
set RestPrPrcPrSsud=drl.rest
from pDepResList  drl
where drl.spid=@@SPID
and drl.Num=6   



--select * from pResource  where spid = @@SPID
--select * from pDepResList where spid = @@SPID

--select * from #Account



select  Client        
      ,Number       
      ,DateDog      
	  ,Limit         
	  ,Prc          
	  ,RestNeusZaCredit       -- �� �����������
      ,RestNeusZaPrc          -- �� �����������
	  ,RestPrPrc         
	  ,RestSrPrc          
	  ,RestPrSsud        
	  ,RestSsud          
	  ,RestPrcPrSsud         
	  ,RestPrPrcPrSsud          
 from #Result

Drop  table #Account
Drop  table #Result