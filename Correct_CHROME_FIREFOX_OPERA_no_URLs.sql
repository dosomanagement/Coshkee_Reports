UPDATE productivitybase
  SET 
      expiredon = GETDATE()
WHERE id IN
(
    SELECT MAX(id)--, resourcename, count(*) 
    FROM productivitybase
    WHERE expiredon IS NULL
          AND LTRIM(RTRIM(resourcename)) != ''
    GROUP BY resourcename
    HAVING COUNT(*) > 1
);

-- in the future, only new UserActivity records will have to be added and thus no need to evaluate those that already have UPDD set

--drop table #UserActivities2Clarify
SELECT ua.ID, 
       ua.FirstCapturedOn, 
       LEFT(dbo.LeftFrom('.com/', dbo.LeftFrom('./Search', dbo.LeftFrom('.pdf', dbo.LeftFrom('.htm', dbo.LeftFrom('aspx', ua.Description))))), 500) NewResourceName, 
       ua.Url, 
       pb.ResourceName, 
       ua.ActiveDuration, 
       updd.Oid UPDDOid
INTO #UserActivities2Clarify
FROM UserActivity ua
     JOIN ProductivityBase pb ON pb.ID = ua.ProductivityBase
     --AND pb.ExpiredOn IS NULL
     LEFT JOIN UserProductivityDailyDetail updd ON ua.UserProductivityDailyDetail = updd.Oid
WHERE pb.ResourceName IN
('google chrome - chrome.exe', 'opera internet browser - opera.exe', 'firefox - firefox.exe'
--,'google.ge','google.com','google.ru','bing.com','yahoo.com'
)
--and UserProductivityDailyDetail is null
and ua.ActiveDuration > 0
and ltrim(rtrim(isnull(ua.Description,''))) != ''
option (recompile);


--alter table UserProductivityDailyDetail add Recalculate bit

--Insert into ProductivityBase
WITH cte
     AS (SELECT NewResourceName, 
                resourcename ExistingResourceName, 
                SUM(activeduration) SumActiveDuration, 
                --dbo.Sec2TimeD(SUM(activeduration)), 
                COUNT(*) RCount
         FROM #UserActivities2Clarify
         GROUP BY NewResourceName, 
                  ResourceName
         HAVING SUM(activeduration) > 30 ),
     resourcesToInsertInProductivityBase
     AS (SELECT cte.NewResourceName
         FROM cte
              LEFT JOIN ProductivityBase pb ON pb.ResourceName = cte.NewResourceName and pb.ExpiredOn is null
         WHERE pb.ID IS NULL)
     INSERT INTO ProductivityBase
     (BrowserRelated, 
      ApplicationOrWebsite, 
      CreatedOn, 
      SavedOn, 
      ResourceName
     )
            SELECT 1, 
                   1, 
                   GETDATE(), 
                   GETDATE(), 
                   NewResourceName
            FROM resourcesToInsertInProductivityBase
            ORDER BY NewResourceName DESC;

--select * From productivitybase where productivitytype is null
--update productivitybase set browserrelated = 1 where productivitytype is null

--DECLARE @LastUADate DATETIME;
--SELECT @LastUADate = ISNULL(MAX(LastUserActivityProcessDate), '1jan2010')
--FROM UserActivityBrowserProcessing;



--update updd
--set updd.Recalculate = true
--from UserProductivityDailyDetail updd
--	join unique_updd on unique_updd.UPDDOid = updd.Oid

--select * From #UserActivities2Clarify where UPDDOid = '2f7c4467-0d3f-403e-9c97-d9c0104a7f50'

UPDATE ua
  SET 
      ua.UserProductivityDailyDetail = NULL, 
      ProductivityBase = pb.ID
--SELECT ua.ProductivityBase,        pbold.ResourceName,        pb.id,        pb.ResourceName,        rua.*,        pb.ResourceName pbrn
       --pb.BrowserRelated
FROM #UserActivities2Clarify rua
     JOIN UserActivity ua ON rua.ID = ua.ID
     LEFT JOIN productivitybase pbold ON pbold.id = ua.ProductivityBase
     JOIN
(
    SELECT MIN(id) ID, 
           ResourceName
    FROM ProductivityBase
    WHERE expiredon IS NULL
          AND BrowserRelated = 1
    GROUP BY ResourceName
) pb ON pb.ResourceName = rua.NewResourceName
WHERE ua.ProductivityBase != pb.ID;

--select * From #UserActivities2Clarify rua order by len(newresourcename) desc

-- remaining are FIREFOX, CHROME items, not updated by the previous script?!

--drop table #unique_updd
SELECT DISTINCT 
                UPDDOid
    into #unique_updd
	     FROM #UserActivities2Clarify rua
	--???		join ProductivityBase pb on pb.ResourceName = rua.NewResourceName and pb.BrowserRelated = 1 and pb.ExpiredOn is null
	



     --select pb.resourcename, pb.browserrelated, * 
	 update ua
	 set ua.UserProductivityDailyDetail = null
	 From useractivity ua
		--join productivitybase pb on pb.id = ua.ProductivityBase
	 where UserProductivityDailyDetail in (select upddoid from #unique_updd)
	 
DELETE FROM UserProductivityDailyDetail
WHERE oid IN
(
    SELECT UPDDOid
    FROM #unique_updd
);


--select * From UserActivityBrowserProcessing
--alter table ProductivityBase add BrowserRelated bit