select Number, *  from tDeposit where (DateClose  between '20160825' and '20160830') and FinOperID not in (10000000054,3887)
select Number, *  from tDeposit where (DateClose  >= '20200101' ) and FinOperID not in (10000000054,3887)

select * from tInstrument where InstrumentID in (10000000054,3887,10000000080)
--order by Number