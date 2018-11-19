WITH cte
     AS (SELECT up.date, 
                MIN(up.ActivityStart) MinActivityStart, 
                MAX(up.ActivityEnd) MaxActivityEnd, 
                CAST(DATEADD(s, (DATEDIFF(s, date, MIN(up.ActivityStart))), '00:00:00') AS TIME) MinActivityStartTime, 
                CAST(DATEADD(s, (DATEDIFF(s, date, MAX(up.ActivityEnd))), '00:00:00') AS TIME) MaxActivityEndTime, 
                (DATEDIFF(s, date, MIN(up.ActivityStart))) MinActivityStartTimeSeconds, 
                (DATEDIFF(s, date, MAX(up.ActivityEnd))) MaxActivityEndTimeSeconds, 
                SUM(up.DailyDuration) SumDailyDuration, 
				SUM(CASE WHEN up.AdjustedProductivityType = 1 then up.DailyDuration else 0 END) SumProductive,
				SUM(CASE WHEN up.AdjustedProductivityType = 2 then up.DailyDuration else 0 END) SumDistracting,
				SUM(CASE WHEN up.AdjustedProductivityType = 3 then up.DailyDuration else 0 END) SumNeutral,
				SUM(CASE WHEN up.AdjustedProductivityType = 0 then up.DailyDuration else 0 END) SumUndefined,
				--SUM(CASE WHEN up.AdjustedProductivityType not in (1,2,3,0) then up.DailyDuration else 0 END) SumOther,
                up.SystemUser
         --into reporting.UPDD
         FROM UserProductivityDailyDetail up
              JOIN ProductivityBase pb ON pb.ID = up.ProductivityBase
         WHERE pb.ResourceName NOT LIKE '%lockapp%'
         GROUP BY up.date, 
                  up.SystemUser)
     SELECT CAST(YEAR(date) AS VARCHAR) + '-' + RIGHT('0' + CAST(MONTH(date) AS VARCHAR), 2) YearMonth, 
            COUNT(*) NumberOfDaysObserved, 
            --SystemUser, 
            su.Name, 
            CAST(DATEADD(s, SUM(SumDailyDuration), '00:00:00') AS TIME) SumDailyDuration,
			CAST(DATEADD(s, SUM(SumProductive), '00:00:00') AS TIME) SumProductive,
			CAST(DATEADD(s, SUM(SumDistracting), '00:00:00') AS TIME) SumDistracting,
			CAST(DATEADD(s, SUM(SumNeutral), '00:00:00') AS TIME) SumNeutral,
			CAST(DATEADD(s, SUM(SumUndefined), '00:00:00') AS TIME) SumUndefined,
			--CAST(DATEADD(s, SUM(SumOther), '00:00:00') AS TIME) SumOther,
            CAST(DATEADD(s, AVG(MinActivityStartTimeSeconds), '00:00:00') AS TIME) AS AverageStartTime,
            CAST(DATEADD(s, AVG(MaxActivityEndTimeSeconds), '00:00:00') AS TIME) AS AverageEndTime
     FROM cte
          JOIN SystemUser su ON su.Oid = cte.SystemUser
     GROUP BY MONTH(date), 
              YEAR(date), 
              su.Name, 
              SystemUser;


--, avg(MaxActivityEnd)


     
     JOIN ProductivityBase pb ON pb.ID = up.ProductivityBase

--drop table reporting.updd

SELECT top 100 pb.ResourceName, 
       ISNULL(su.FriendlyName, replace(su.Name, 'EVEX\', '')) Name, 
       SUM(up.dailyDuration) AS Duration,
       up.HourFrom,
       CASE up.adjustedProductivityType
           WHEN 1
           THEN 'Productive'
           WHEN 2
           THEN 'UnProductive'
           WHEN 3
           THEN 'Neutral'
           ELSE 'Undefined'
       END AS ProductivityType, 
       DATEADD(month, DATEDIFF(month, 0, up.date), 0) Month
--into reporting.UPDD
FROM UserProductivityDailyDetail up
     JOIN systemUser su ON su.Oid = up.systemuser
     JOIN ProductivityBase pb ON pb.ID = up.ProductivityBase
WHERE up.date > '1oct2018'
      AND pb.ResourceName NOT LIKE '%lockapp%'
GROUP BY up.systemuser, 
         su.Name, 
         su.FriendlyName, 
         DATEADD(month, DATEDIFF(month, 0, up.date), 0), 
         pb.ResourceName, 
         up.hourFrom, 
         up.adjustedProductivityType;

