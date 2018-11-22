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



--Insert into ProductivityBase
WITH cte
     AS (SELECT left(dbo.LeftFrom('aspx', Description),500) NewResourceName, 
                resourcename ExistingResourceName, 
                SUM(activeduration) SumActiveDuration, 
                --dbo.Sec2TimeD(SUM(activeduration)), 
                COUNT(*) RCount
         FROM Reporting.UserActivities2Clarify
         --WHERE resourcename NOT IN('google.ge', 'google.com', 'google.ru', 'bing.com', 'yahoo.com')
         GROUP BY description, 
                  resourcename
         HAVING SUM(activeduration) > 600),
     resourcesToInsertInProductivityBase
     AS (SELECT cte.NewResourceName
         FROM cte
              LEFT JOIN ProductivityBase pb ON pb.ResourceName = cte.NewResourceName
         WHERE pb.ID IS NULL)
     INSERT INTO ProductivityBase
     (ApplicationOrWebsite, 
      CreatedOn, 
      SavedOn, 
      ResourceName
     )
     SELECT 1, 
            GETDATE(), 
            GETDATE(), 
            left(dbo.LeftFrom('aspx', NewResourceName),500)
     FROM resourcesToInsertInProductivityBase
     ORDER BY LEN(dbo.LeftFrom('aspx', NewResourceName)) DESC;