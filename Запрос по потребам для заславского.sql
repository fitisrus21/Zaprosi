 DATEADD(DD,-(Datepart(DD,@Today)-1),@Today)

 select Datepart(YY,'20160405')
select  DATEADD(DD,Datepart(DD,'20160405'),'20160601')
select  DATEDiff(DD,'20160405','20160601')


select * from tPaySchedule ps, tPayScheduleExt pse where ps.PayScheduleID=pse.PayScheduleID
and ps.Version=0
and ps.DatePay between '20160501' and '20171231' 


drop table #PotData
select 
Datepart(MM, ps.DatePay)        PerPayMM,
Datepart(YY, ps.DatePay)      PerPayYY,   
ps.ContractID      ContractID,
ps.PayType         PayType    ,
abs(ps.Qty)             Qty,
ps.DatePay         DatePay,
pse.Interest

into #PotData
from tPaySchedule ps
left join tPayScheduleExt pse
       on ps.PayScheduleID=pse.PayScheduleID
left join tContract c
       on ps.ContractID=c.ContractID
	   and c.InstrumentID!=10000000379 

where ps.Version=0
and ps.DatePay between '20160601' and '20251231' 

select * from #PotData

select convert(varchar, PerPayMM) +'.'+convert(varchar, PerPayYY) PerPay, 
case when PayType=206 then 'поашение ОД'
     when PayType=201 then 'поашение %%' 
end PayType
, sum(Qty)   from #PotData
group by PerPayMM,PerPayYY,PayType
Order by  PerPay
