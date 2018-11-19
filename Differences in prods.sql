SELECT COUNT(*)

FROM UserActivity wn
WHERE wn.ObjectType = 8
     AND wn.UserProductivityDailyDetail IS NULL
     AND wn.ProductivityBase IS NOT NULL
     AND wn.InactivitySet = 1
     AND wn.ActiveDuration > 0;


	 IF(OBJECT_ID('tempdb..#a') Is Not Null)
Begin
   Drop Table #a
END;
with cte as (SELECT updd.Oid,
      updd.Date,
      SUM(ua.ActiveDuration) SumActiveDuration,
      updd.DailyDuration
FROM UserProductivityDailyDetail updd
    JOIN UserActivity ua ON updd.Oid = ua.UserProductivityDailyDetail
GROUP BY updd.Oid,
        updd.Date,
        updd.DailyDuration
HAVING SUM(ua.ActiveDuration) > updd.DailyDuration+2
--and updd.date = '1nov2017'
)
select *,cte.SumActiveDuration - cte.DailyDuration DiffDuration

into #a
from cte
order by cte.SumActiveDuration - cte.DailyDuration 


select * from #a order by DiffDuration

--update Useractivity ua 
--set ua.UserProductivityDailyDetail = null
--where ua.UserProductivityDailyDetail 
--in
--(select Oid from #a)