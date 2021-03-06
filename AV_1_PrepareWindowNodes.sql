USE [Coshkee];
GO

/****** Object:  StoredProcedure [dbo].[AV_1_PrepareWindowNodes]    Script Date: 11/22/2018 5:43:52 PM ******/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
ALTER PROC [dbo].[AV_1_PrepareWindowNodes]
AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @cnt INT= 0;
        BEGIN
            EXEC ShowMessage 
                 'Executing AggregateValues_1_PrepareWindowNodes';
            EXEC ShowMessage 
                 'Update WindowNode.InactiveDuration';
        END;
        DECLARE @infoMessage VARCHAR(1000)= '';
        BEGIN
            SELECT TOP 50000 wnpnb.ID, 
                             wnus.SystemUser, 
                             wnus.IPAddress, 
                             wnpnb.FirstCapturedOn, 
                             wnpnb.LastCapturedOn,

                             --PETRE--Added MachineName on 2018-11-22
                             wnus.MachineName
            --PETRE--Added MachineName on 2018-11-22
            INTO #wnpnb
            FROM dbo.UserActivity wnpnb(NOLOCK)
                 INNER JOIN dbo.UserSession wnus(NOLOCK) ON wnus.ID = wnpnb.UserSession
            WHERE wnpnb.ObjectType = 8 --select OID From xpobjecttype where typename like '%windownode%'
                  AND wnpnb.InactivitySet IS NULL --Removed ISNULL(wnpnb.InactivitySet,0) = 0 due to iAV1 not being matched!
                  AND wnpnb.FirstCapturedOn < wnpnb.LastCapturedOn
                  --MergeInactivities only picks up InactivityBases whose UserSession has SystemUser assigned!!
                  AND wnus.SystemUser IS NOT NULL
            ORDER BY wnpnb.FirstCapturedOn DESC OPTION(RECOMPILE);

            -- Message 

            SET @infoMessage = '======= PrepareWindowNodes =======Element count in #wnpnb: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
            EXEC dbo.ShowMessage 
                 @infoMessage;
            --!Message

        END;

/* !! #wnpnb ში მოგვაქვს ტოპ რამდენიმე აქთივითი რომელსაც იუზერი აქვს მინიჭებული 
		მაგრამ ინაქთივითის დრო არ აქვს გამოთვლილი (იუზერფროდაქთივისთვის)
		*/

        BEGIN
            DECLARE @startDate NVARCHAR(30)=
            (
                SELECT MIN(FirstCapturedOn)
                FROM #wnpnb
            );
            DECLARE @endDate NVARCHAR(30)=
            (
                SELECT MAX(FirstCapturedOn)
                FROM #wnpnb
            );
            SET @infoMessage = 'Getting top 100000 window record in time range ' + @startDate + ' to ' + @endDate;
            EXEC dbo.ShowMessage 
                 @infoMessage;

            --PETRE--Added MachineName on 2018-11-22
            CREATE INDEX i#wnpnb_SystemUser ON #wnpnb
            (SystemUser, MachineName
            );
            --PETRE--Added MachineName on 2018-11-22
            CREATE INDEX i#wnpnb_SystemUser_1 ON #wnpnb
            (SystemUser, MachineName, FirstCapturedOn, LastCapturedOn DESC
            );
            --PETRE--Added MachineName on 2018-11-22
        END;
        BEGIN
            SELECT wnpnb.ID, --ავიღოთ ID
                   ISNULL(SUM(DATEDIFF(SECOND, dbo.Maxi(wnpnb.FirstCapturedOn, i.FirstCapturedOn), dbo.Mini(wnpnb.LastCapturedOn, i.LastCapturedOn))), 0) InactivityAdjustment, 
                   MAX(CASE
                         WHEN i.FirstCapturedOn BETWEEN wnpnb.FirstCapturedOn AND wnpnb.LastCapturedOn THEN wnpnb.FirstCapturedOn
                         WHEN i.LastCapturedOn > wnpnb.LastCapturedOn THEN NULL --Inactive Window!
                         ELSE i.LastCapturedOn
                       END) MaxFirstCapturedOn, 
                   MIN(CASE
                         WHEN i.LastCapturedOn BETWEEN wnpnb.FirstCapturedOn AND wnpnb.LastCapturedOn THEN wnpnb.LastCapturedOn
                         WHEN i.FirstCapturedOn < wnpnb.FirstCapturedOn THEN NULL --Inactive Window!
                         ELSE i.FirstCapturedOn
                       END) MinLastCapturedOn
        INTO #wnia
            FROM #wnpnb wnpnb
                 INNER JOIN(dbo.UserActivity i(NOLOCK)
                            INNER JOIN dbo.UserSession ius(NOLOCK) ON ius.ID = i.UserSession) ON wnpnb.SystemUser = ius.SystemUser
                                                                                                 --PETRE--Added MachineName on 2018-11-22
                                                                                                 --AND wnpnb.MachineName = ius.MachineName
                                                                                                 --PETRE--Added MachineName on 2018-11-22
                                                                                                 AND wnpnb.IPAddress = ius.IPAddress
                                                                                                 AND i.FirstCapturedOn < wnpnb.LastCapturedOn
                                                                                                 AND i.LastCapturedOn > wnpnb.FirstCapturedOn
            WHERE i.ObjectType = 9--select * from xpobjecttype where TypeName like '%inactivity'
                  AND DATEDIFF(SECOND, i.FirstCapturedOn, i.LastCapturedOn) > 40--@MinimumConsiderableInactivityDuration
                  AND DATEDIFF(DAY, i.FirstCapturedOn, i.LastCapturedOn) < 2--@MinimumConsiderableInactivityDuration
            GROUP BY wnpnb.ID OPTION(RECOMPILE);
        END;

/* #wnia ში მოგვაქვს ისეთი ინაქთივითიები როლებიც უკვე არჩეულ აქთივითიებს (#wnpnb ში რომ ავირჩიეთ ზემოთ)
		შეესაბამება იუზერით(ნეიმი და IP) და არის დროით თანაკვეთაში აქთივითისთან
		*/

        BEGIN
            EXEC ShowMessage 
                 'Getting #wnia';
            CREATE INDEX i#wnia_id ON #wnia(ID);
            CREATE INDEX i#wnpnb_id ON #wnpnb(ID);
        END;
        BEGIN
            DECLARE @startDate1 NVARCHAR(30)=
            (
                SELECT MIN(FirstCapturedOn)
                FROM #wnpnb
            );
            DECLARE @endDate1 NVARCHAR(30)=
            (
                SELECT MAX(FirstCapturedOn)
                FROM #wnpnb
            );
            --print dbo.GDate() + 'about to update evaluated activity time in window records in time range '+@startDate1+ ' to '+ @endDate1

            DECLARE @startDatenew NVARCHAR(30)=
            (
                SELECT MIN(FirstCapturedOn)
                FROM #wnpnb
            );
            DECLARE @endDatenew NVARCHAR(30)=
            (
                SELECT MAX(FirstCapturedOn)
                FROM #wnpnb
            );
            --PRINT dbo.GDate()
            --    + 'aggregated window record time range = '
            --    + @startDatenew + ' to ' + @endDatenew

            UPDATE ua
              SET 
                  ua.InactiveDuration = ISNULL(wnia.InactivityAdjustment, 0), 
                  ua.ActiveDuration = DATEDIFF(SECOND, ua.FirstCapturedOn, ua.LastCapturedOn) --აქტივობას მთლიან დროს
                                      - ISNULL(wnia.InactivityAdjustment, 0), --გამოკლებული ინაქტივობა
                  ua.MaxFirstCapturedOn = CASE
                                            WHEN wnia.ID IS NOT NULL THEN wnia.MaxFirstCapturedOn
                                            ELSE ua.FirstCapturedOn
                                          END, --ISNULL(wnia.MaxFirstCapturedOn, wn.FirstCapturedOn) ,
                  ua.MinLastCapturedOn = CASE
                                           WHEN wnia.ID IS NOT NULL THEN wnia.MinLastCapturedOn
                                           ELSE ua.LastCapturedOn
                                         END, --ISNULL(wnia.MinLastCapturedOn, wn.LastCapturedOn) ,
                  ua.InactivitySet = 1
            FROM dbo.UserActivity ua
                 JOIN #wnpnb ON #wnpnb.ID = ua.ID
                 LEFT JOIN #wnia wnia ON ua.ID = wnia.ID OPTION(RECOMPILE);

            -- Message 
            SET @cnt = @@ROWCOUNT;
            SET @infoMessage = '======= PrepareWindowNodes ======= Number of userActivities where InactivitySet updated: ' + CAST(@cnt AS VARCHAR(10));
            RAISERROR(@infoMessage, 10, 0) WITH NOWAIT;
            --!Message

        END;

/*ვანიჭებთ აქტივობის და ინაქტივობის დროს ვინდოუს და მოვნიშნავთ InactivitySet = 1 რომ მეორედ აღარ მოვუბრუნდეთ
		 ვინდოუებს ვირჩევთ ისეთს რომლებსაც აქვთ იგივე აიდი რაც */

        EXEC ShowMessage 
             'Updated WindowNode''s inactivity';
        IF OBJECT_ID('tempdb..#wnia') IS NOT NULL
            DROP TABLE #wnia;
        IF OBJECT_ID('tempdb..#OutdatedUPDD') IS NOT NULL
            DROP TABLE #OutdatedUPDD;

        --------------------------------------------------ADDED by PETRE on 2018-11-22
        EXEC ShowMessage 
             'ADDED by PETRE on 2018-11-22 - correcting ProductivityBase for CHROME, OPERA, FIREFOX';
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

        -- only new UserActivity records will have to be added and thus no need to evaluate those that already have UPDD set
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
              AND UserProductivityDailyDetail IS NULL
              AND ua.ActiveDuration > 0
              AND LTRIM(RTRIM(ISNULL(ua.Description, ''))) != '' OPTION(RECOMPILE);

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
                 HAVING SUM(activeduration) > 30),
             resourcesToInsertInProductivityBase
             AS (SELECT cte.NewResourceName
                 FROM cte
                      LEFT JOIN ProductivityBase pb ON pb.ResourceName = cte.NewResourceName
                                                       AND pb.ExpiredOn IS NULL
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

        --ADDED by PETRE on 2018-11-22

        DROP TABLE #UserActivities2Clarify;
    END;