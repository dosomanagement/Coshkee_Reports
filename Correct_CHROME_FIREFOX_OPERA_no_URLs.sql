--drop table Reporting.UserActivities2Clarify
SELECT ua.ID, ua.Description, ua.Url, pb.ResourceName, ua.ActiveDuration
into Reporting.UserActivities2Clarify
FROM UserProductivityDailyDetail (nolock) updd
     JOIN UserActivity ua (nolock) ON ua.UserProductivityDailyDetail = updd.Oid
	 join ProductivityBase (nolock) pb on pb.ID = updd.ProductivityBase
where 	 pb.ResourceName in 
(
'google chrome - chrome.exe',
'opera internet browser - opera.exe',
'firefox - firefox.exe'
--,'google.ge','google.com','google.ru','bing.com','yahoo.com'
)
option (recompile)


select top 1000 id from useractivity order by id 
--select min(id) from UserActivity
--DBCC CHECKIDENT ('[UserActivity]', RESEED, 0);

SELECT description, 
       resourcename, 
       SUM(activeduration) SumActiveDuration, 
       dbo.Sec2TimeD(SUM(activeduration)), 
       COUNT(*)
FROM Reporting.UserActivities2Clarify
WHERE resourcename NOT IN('google.ge', 'google.com', 'google.ru', 'bing.com', 'yahoo.com')
GROUP BY description, 
         resourcename
HAVING SUM(activeduration) > 600
ORDER BY SUM(activeduration) DESC;