DECLARE @from INT= 9;
DECLARE @till INT= 19;
DECLARE @debug BIT= 0;
DECLARE @monthly BIT= 0;
declare @weekday_from int = 2;
declare @weekday_till int = 7;

/*
IF OBJECT_ID('tempdb.dbo.#ActivityTimes', 'U') IS NOT NULL
    DROP TABLE #ActivityTimes;

IF OBJECT_ID('tempdb.dbo.#us', 'U') IS NOT NULL
	drop table #us

IF OBJECT_ID('tempdb.dbo.#Main', 'U') IS NOT NULL
    DROP TABLE #Main;
*/

IF OBJECT_ID('tempdb.dbo.#ActivityTimes', 'U') IS NULL
    BEGIN
        WITH upddTimes
             AS (SELECT up.systemuser, 
                        up.productivitybase, 
                        SUM(CASE
                              WHEN DATEPART(dw, up.Date) BETWEEN @weekday_from AND @weekday_till
                                   AND HourFrom BETWEEN @from AND @till THEN DailyDuration
                              ELSE 0
                            END) WorkDuration, 
                        SUM(DailyDuration) AllDuration
                 FROM UserProductivityDailyDetail up
                      JOIN ProductivityBase pb ON pb.id = up.ProductivityBase
                 WHERE pb.ResourceName NOT LIKE '%lockapp%'
                 --AND up.SystemUser = 'C088D022-2DCC-4E8A-8E1D-001C0E0651A9'
                 GROUP BY up.SystemUser, 
                          ProductivityBase),
             u1
             AS (SELECT upddTimes.*, 
                        dbo.Sec2TimeD(WorkDuration) WorkDurationTime, 
                 --AllDuration AllDurationSec, 
                        ROW_NUMBER() OVER(PARTITION BY upddTimes.systemuser
                 ORDER BY WorkDuration DESC) rnWorkHours
             --           ROW_NUMBER() OVER(PARTITION BY upddTimes.systemuser, 
             --                                          upddTimes.Y, 
             --                                          upddTimes.M
             --ORDER BY AllDuration DESC) rnAllHours
                 FROM upddTimes)
             --JOIN ProductivityBase pb ON pb.ID = upddTimes.ProductivityBase
             SELECT *
             INTO #ActivityTimes
             FROM u1
             WHERE rnWorkHours < 7
             ORDER BY SystemUser, 
                      rnWorkHours;
END;
IF OBJECT_ID('tempdb.dbo.#us', 'U') IS NULL
    BEGIN
        WITH initial
             AS (SELECT SystemUser, 
                        MachineName + '[' + CAST(COUNT(*) AS VARCHAR(MAX)) + ']' MachineName, 
                        MIN(SaveDate) MinDateUS, 
                        MAX(SaveDate) MaxDateUS
                 FROM dbo.UserSession
                 WHERE SaveDate >= '1Jun2018'
                 GROUP BY systemuser, 
                          machinename)
             SELECT SystemUser, 
                    COUNT(*) ComputersCount, 
                    STUFF(
             (
                 SELECT '; ' + t2.MachineName
                 FROM initial t2
                 WHERE t1.SystemUser = t2.SystemUser
                 ORDER BY t2.MachineName FOR XML PATH(''), TYPE
             ).value('.', 'varchar(max)'), 1, 2, '') AS ComputerNames
             INTO #us
             FROM initial t1
             GROUP BY t1.SystemUser;
END;
IF OBJECT_ID('tempdb.dbo.#Main', 'U') IS NULL
    BEGIN
        WITH cte
             AS (SELECT up.date, 
                        MIN(up.ActivityStart) MinActivityStart, 
                        MAX(up.ActivityEnd) MaxActivityEnd, 
                        dbo.Sec2Time(DATEDIFF(s, up.date, MIN(up.ActivityStart))) MinActivityStartTime, 
                        dbo.Sec2Time(DATEDIFF(s, up.date, MAX(up.ActivityEnd))) MaxActivityEndTime, 
                        (DATEDIFF(s, up.date, MIN(up.ActivityStart))) MinActivityStartTimeSeconds, 
                        (DATEDIFF(s, up.date, MAX(up.ActivityEnd))) MaxActivityEndTimeSeconds, 
                        SUM(up.DailyDuration) SumDailyDuration, 
                        SUM(CASE
                              WHEN up.AdjustedProductivityType = 1 THEN up.DailyDuration
                              ELSE NULL
                            END) SumProductive, 
                        SUM(CASE
                              WHEN up.AdjustedProductivityType = 2 THEN up.DailyDuration
                              ELSE NULL
                            END) SumDistracting, 
                        SUM(CASE
                              WHEN up.AdjustedProductivityType = 3 THEN up.DailyDuration
                              ELSE NULL
                            END) SumNeutral, 
                        SUM(CASE
                              WHEN ISNULL(up.AdjustedProductivityType, 0) = 0 THEN up.DailyDuration
                              ELSE NULL
                            END) SumUndefined, 
                        MIN(upwh.ActivityStart) MinActivityStartWH, 
                        MAX(upwh.ActivityEnd) MaxActivityEndWH, 
                        dbo.Sec2Time(DATEDIFF(s, up.date, MIN(upwh.ActivityStart))) MinActivityStartTimeWH, 
                        dbo.Sec2Time(DATEDIFF(s, up.date, MAX(upwh.ActivityEnd))) MaxActivityEndTimeWH, 
                        (DATEDIFF(s, up.date, MIN(upwh.ActivityStart))) MinActivityStartTimeSecondsWH, 
                        (DATEDIFF(s, up.date, MAX(upwh.ActivityEnd))) MaxActivityEndTimeSecondsWH, 
                        SUM(upwh.DailyDuration) SumDailyDurationWH, 
                        SUM(CASE
                              WHEN upwh.AdjustedProductivityType = 1 THEN upwh.DailyDuration
                              ELSE NULL
                            END) SumProductiveWH, 
                        SUM(CASE
                              WHEN upwh.AdjustedProductivityType = 2 THEN upwh.DailyDuration
                              ELSE NULL
                            END) SumDistractingWH, 
                        SUM(CASE
                              WHEN upwh.AdjustedProductivityType = 3 THEN upwh.DailyDuration
                              ELSE NULL
                            END) SumNeutralWH, 
                        SUM(CASE
                              WHEN ISNULL(upwh.AdjustedProductivityType, 0) = 0 THEN upwh.DailyDuration
                              ELSE NULL
                            END) SumUndefinedWH,

--SUM(CASE WHEN up.AdjustedProductivityType not in (1,2,3,0) then up.DailyDuration else 0 END) SumOther,
                        up.SystemUser
--into reporting.UPDD
                 FROM UserProductivityDailyDetail up
                      JOIN ProductivityBase pb ON pb.ID = up.ProductivityBase
                      LEFT JOIN UserProductivityDailyDetail upwh ON up.oid = upwh.Oid
                                                                    AND upwh.HourFrom BETWEEN @from AND @till
                                                                    AND DATEPART(dw, upwh.Date) BETWEEN @weekday_from and @weekday_till
                 WHERE pb.ResourceName NOT LIKE '%lockapp%'
                       AND up.Date BETWEEN '1Jun2018' AND GETDATE()
                 --     JOIN ProductivityBase pb ON pb.ID = up.ProductivityBase
                 --WHERE pb.ResourceName NOT LIKE '%lockapp%'
                 --AND up.SystemUser = 'F4D698FC-39D5-478B-9A8A-009D14E620F2'
                 --and up.Date between '2018-06-01' and '2018-07-01'
                 GROUP BY up.date, 
                          up.SystemUser)
             SELECT COUNT(*) NumberOfDaysObserved, 
                    cte.SystemUser, 
                    su.Name, 
					MIN(cte.Date) MinDate,
					MAX(cte.Date) MaxDate,
                    dbo.Sec2Time(AVG(ISNULL(SumDailyDurationWH, 0))) AvgDailyDurationWH, 
                    dbo.Sec2Time(AVG(ISNULL(SumProductiveWH, 0))) AvgProductiveWH, 
                    dbo.Sec2Time(AVG(ISNULL(SumDistractingWH, 0))) AvgDistractingWH, 
                    dbo.Sec2Time(AVG(ISNULL(SumNeutralWH, 0))) AvgNeutralWH, 
                    dbo.Sec2Time(AVG(ISNULL(SumUndefinedWH, 0))) AvgUndefinedWH, 
                    dbo.Sec2Time(AVG(MinActivityStartTimeSecondsWH)) AS AverageStartTimeWH, 
                    dbo.Sec2Time(AVG(MaxActivityEndTimeSecondsWH)) AS AverageEndTimeWH, 
                    dbo.Sec2Time(AVG(ISNULL(SumDailyDuration, 0))) AvgDailyDuration, 
                    dbo.Sec2Time(AVG(ISNULL(SumProductive, 0))) AvgProductive, 
                    dbo.Sec2Time(AVG(ISNULL(SumDistracting, 0))) AvgDistracting, 
                    dbo.Sec2Time(AVG(ISNULL(SumNeutral, 0))) AvgNeutral, 
                    dbo.Sec2Time(AVG(ISNULL(SumUndefined, 0))) AvgUndefined, 
                    dbo.Sec2Time(AVG(MinActivityStartTimeSeconds)) AS AverageStartTime, 
                    dbo.Sec2Time(AVG(MaxActivityEndTimeSeconds)) AS AverageEndTime
INTO #Main
             FROM cte
                  JOIN SystemUser su ON su.Oid = cte.SystemUser
             GROUP BY su.Name, 
                      cte.SystemUser;
END;
IF(@debug = 0
   AND @monthly = 0)
    BEGIN
        WITH cte3
             AS (SELECT act.SystemUser, 
                        rnWorkHours, 
                        pb.ResourceName + act.WorkDurationTime WorkActivityWithTime
                 --pb.ResourceName + '[' + CAST(dbo.Sec2Time(AllDuration) AS VARCHAR(MAX)) + ']' AllActivityWithTime
                 FROM #activitytimes act
                      JOIN ProductivityBase pb ON pb.id = act.ProductivityBase),
             cte4
             AS (SELECT DISTINCT 
                        SystemUser
                 FROM cte3),
             cte5
             AS (SELECT *, 
                 (
                     SELECT _1.WorkActivityWithTime
                     FROM cte3 _1
                     WHERE _1.rnWorkHours = 1
                           AND cte4.SystemUser = _1.SystemUser
                 ) T1, 
                 (
                     SELECT _1.WorkActivityWithTime
                     FROM cte3 _1
                     WHERE _1.rnWorkHours = 2
                           AND cte4.SystemUser = _1.SystemUser
                 ) T2, 
                 (
                     SELECT _1.WorkActivityWithTime
                     FROM cte3 _1
                     WHERE _1.rnWorkHours = 3
                           AND cte4.SystemUser = _1.SystemUser
                 ) T3, 
                 (
                     SELECT _1.WorkActivityWithTime
                     FROM cte3 _1
                     WHERE _1.rnWorkHours = 4
                           AND cte4.SystemUser = _1.SystemUser
                 ) T4, 
                 (
                     SELECT _1.WorkActivityWithTime
                     FROM cte3 _1
                     WHERE _1.rnWorkHours = 5
                           AND cte4.SystemUser = _1.SystemUser
                 ) T5, 
                 (
                     SELECT _1.WorkActivityWithTime
                     FROM cte3 _1
                     WHERE _1.rnWorkHours = 6
                           AND cte4.SystemUser = _1.SystemUser
                 ) T6
                 FROM cte4)
             SELECT m.Name UserName, 
                    m.NumberOfDaysObserved, 
                    ISNULL(d.Name, '-') Department, 
                    isnull(cast(us.ComputersCount as varchar),'-') as ComputersCount, 
					--us.ComputersCount, 
                    --us.MinDate, 
                    --us.MaxDate, 
					m.MinDate,
					m.MaxDate,
                    m.AvgDailyDurationWH, 
                    m.AvgProductiveWH, 
                    m.AvgDistractingWH, 
                    m.AvgNeutralWH, 
                    m.AvgUndefinedWH, 
                    m.AverageStartTimeWH, 
                    m.AverageEndTimeWH, 
                    m.AvgDailyDuration, 
                    m.AvgProductive, 
                    m.AvgDistracting, 
                    m.AvgNeutral, 
                    m.AvgUndefined, 
                    m.AverageStartTime, 
                    m.AverageEndTime, 
                    us.ComputerNames, 
                    c.T1, 
                    c.T2, 
                    c.T3, 
                    c.T4, 
                    c.T5, 
                    c.T6
             FROM #main m
                  JOIN SystemUser su ON su.Oid = m.SystemUser
                  LEFT JOIN cte5 c ON c.SystemUser = m.SystemUser
                  LEFT JOIN #us us ON us.SystemUser = m.SystemUser
                  LEFT JOIN Department d ON d.Oid = su.WorkingDepartment

             --where m.Name like '%EVEX\lomiadze%'
             ORDER BY UserName;
END;

--select * from #activitytimes

