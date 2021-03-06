USE [Coshkee]
GO
/****** Object:  StoredProcedure [dbo].[AV_3_InsertAndUpdateRecords]    Script Date: 11/22/2018 2:30:08 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[AV_3_InsertAndUpdateRecords]
    @SplitAtHour0 BIT = NULL ,
    @SplitAtHour1 BIT = NULL ,
    @SplitAtHour2 BIT = NULL ,
    @SplitAtHour3 BIT = NULL ,
    @SplitAtHour4 BIT = NULL ,
    @SplitAtHour5 BIT = NULL ,
    @SplitAtHour6 BIT = NULL ,
    @SplitAtHour7 BIT = NULL ,
    @SplitAtHour8 BIT = NULL ,
    @SplitAtHour9 BIT = NULL ,
    @SplitAtHour10 BIT = NULL ,
    @SplitAtHour11 BIT = NULL ,
    @SplitAtHour12 BIT = NULL ,
    @SplitAtHour13 BIT = NULL ,
    @SplitAtHour14 BIT = NULL ,
    @SplitAtHour15 BIT = NULL ,
    @SplitAtHour16 BIT = NULL ,
    @SplitAtHour17 BIT = NULL ,
    @SplitAtHour18 BIT = NULL ,
    @SplitAtHour19 BIT = NULL ,
    @SplitAtHour20 BIT = NULL ,
    @SplitAtHour21 BIT = NULL ,
    @SplitAtHour22 BIT = NULL ,
    @SplitAtHour23 BIT = NULL
AS
    BEGIN
        SET NOCOUNT ON


		DECLARE @count INT = 0
DECLARE @infoMessage VARCHAR(1000) = ''

        EXEC ShowMessage 'Executing AggregateValues_3_InsertAndUpdateRecords';

        EXEC ShowMessage '--Generating temp table for UPDD';


		
IF(OBJECT_ID('tempdb..#HourGroups') Is Not Null)
Begin
    Drop Table #HourGroups
END
        SELECT  *
        INTO    #HourGroups
        FROM    AggregateValues_GetHourGroups(@SplitAtHour0, @SplitAtHour1, @SplitAtHour2, @SplitAtHour3, @SplitAtHour4, @SplitAtHour5, @SplitAtHour6,
                                              @SplitAtHour7, @SplitAtHour8, @SplitAtHour9, @SplitAtHour10, @SplitAtHour11, @SplitAtHour12, @SplitAtHour13,
                                              @SplitAtHour14, @SplitAtHour15, @SplitAtHour16, @SplitAtHour17, @SplitAtHour18, @SplitAtHour19, @SplitAtHour20,
                                              @SplitAtHour21, @SplitAtHour22, @SplitAtHour23)


				-- Message 
				SET @count = (SELECT COUNT(*) FROM dbo.UserActivity)
SET @infoMessage = 'Number of elements in useractivities: ' + CAST(@count AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT;
--!Message

				-- Message 
				SET @count = (SELECT COUNT(*) FROM dbo.UserSession)
SET @infoMessage = 'Number of elements in usersessions: ' + CAST(@count AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT;
--!Message


				-- Message 
				DECLARE @usid INT = 0
				SET @usid = (SELECT TOP 1 id FROM dbo.UserSession)
				DECLARE @uausid INT = 0
				SET @uausid = (SELECT TOP 1 ua.UserSession FROM dbo.UserActivity ua)
SET @infoMessage = 'UserSessionId: ' + CAST(@usid AS VARCHAR(10)) +' ---- uaUserSession: ' + CAST(@uausid AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT;
--!Message


--select count(*) from UserActivity wn
--where wn.ObjectType = 8-- Only WindowNodes (applications and websites)
--                AND wn.UserProductivityDailyDetail IS NULL
--                AND wn.ProductivityBase IS NOT NULL
--                AND wn.InactivitySet = 1
--                AND wn.FirstCapturedOn < '11/27/2017 6:10:13 PM'
--                AND wn.ActiveDuration > 0  

IF(OBJECT_ID('tempdb..#uaIds') Is Not Null)
Begin
    Drop Table #uaIds
END
select top (50000) ID 
into #uaIds
from UserActivity wn
where wn.ObjectType = 8-- Only WindowNodes (applications and websites)
                AND wn.UserProductivityDailyDetail IS NULL
                AND wn.ProductivityBase IS NOT NULL
                AND wn.InactivitySet = 1
                AND wn.ActiveDuration > 0  

  --select * from #uaIds
  IF(OBJECT_ID('tempdb..#GroupedWindows4Updd') Is Not Null)
Begin
    Drop Table #GroupedWindows4Updd
END
		-- ავირჩიეთ ვინდოუები იუზერით და დროით (თარიღით და საათით) დაჯგუფებული ისეთები რომლებიც ჯერ არ არის UserProductivityDailyDetail ში 
        SELECT TOP 50000
		NEWID() Oid ,
                us.SystemUser ,
                wn.ProductivityBase ProductivityBase ,
                wn.FirstCapturedOnDate Date ,
                MIN(wn.MaxFirstCapturedOn) ActivityStart ,
                MAX(wn.MinLastCapturedOn) ActivityEnd ,
                ISNULL(SUM(wn.ActiveDuration), 0) AS Duration ,
                wn.FirstCapturedOnHour
        INTO    #GroupedWindows4Updd
        FROM    UserActivity wn
                JOIN dbo.UserSession us 
				ON us.ID = wn.UserSession
        WHERE   wn.ID in (select Id from #uaIds)
        GROUP BY us.SystemUser ,
                wn.FirstCapturedOnDate ,
                wn.ProductivityBase ,
                wn.FirstCapturedOnHour

						-- Message 
				SET @count = (SELECT COUNT(*) FROM #GroupedWindows4Updd)
SET @infoMessage = 'Number of elements in #GroupedWindows4Updd: ' + CAST(@count AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT;
--!Message



        EXEC ShowMessage '++Generated temp table for UPDD';

        CREATE INDEX i#GroupedWindows4Updd ON #GroupedWindows4Updd (SystemUser, Date, FirstCapturedOnHour, ProductivityBase)

        EXEC ShowMessage '--Updating UPD';
      
	  
	  -- ზემოთ დაჯგუფებული აქთივითიების დროს (იმ დღეებში და საათებში როცა ეს დაჯგუფებული აქთივითიები შეიქმნა) თუ არის უკვე არსებული UserProductivityDailyDetail ები
	  -- ვუშლით UserProductivityDaily ს (ჩავხსნით მისგან) რომ განვაახლოთ და ახალი მივანიჭოთ
        UPDATE  updd
        SET     updd.UserProductivityDaily = NULL
        FROM    dbo.UserProductivityDailyDetail updd
                JOIN #GroupedWindows4Updd gwhd ON updd.SystemUser = gwhd.SystemUser
                                                  AND updd.HourFrom = gwhd.FirstCapturedOnHour
                                                  --AND updd.HourUntil = gwhd.HrUntil
                                                  AND updd.Date = gwhd.Date
                                                  AND updd.ProductivityBase = gwhd.ProductivityBase
        OPTION  ( RECOMPILE )

        EXEC ShowMessage '++Updated UPD';

	
															-- Message 
				SET @count = (SELECT COUNT(*) FROM dbo.UserProductivityDailyDetail WHERE DailyDuration >0)
SET @infoMessage = 'Number of updd where DailyDuration > 0 before updd: ' + CAST(@count AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT;
--!Message

        EXEC ShowMessage '--Inserting into UPDD';



		-- ვქმნით ახალ UserProductivityDailyDetail ებს 
        INSERT  INTO dbo.UserProductivityDailyDetail
                ( Oid ,
                  SystemUser ,
                  ActivityStart ,
                  ActivityEnd ,
                  ProductivityBase ,
                  DailyDuration ,
                  HourFrom ,
                  Date ,
                  CreatedOn
				 )
                SELECT  gwhd.Oid ,
                        gwhd.SystemUser ,
                        gwhd.ActivityStart ,
                        gwhd.ActivityEnd ,
                        gwhd.ProductivityBase ,
                        gwhd.Duration ,
                        gwhd.FirstCapturedOnHour , --.HrFrom ,
                        gwhd.Date ,
                        GETDATE()
                FROM    #GroupedWindows4Updd gwhd
                        LEFT JOIN UserProductivityDailyDetail updd ON updd.SystemUser = gwhd.SystemUser
                                                                      AND updd.HourFrom = gwhd.FirstCapturedOnHour
                                                                      AND updd.Date = gwhd.Date
                                                                      AND updd.ProductivityBase = gwhd.ProductivityBase
                WHERE   updd.Oid IS NULL

													-- Message 
				SET @count = (SELECT COUNT(*) FROM dbo.UserProductivityDailyDetail WHERE DailyDuration >0)
SET @infoMessage = 'Number of updd where DailyDuration > 0 after createion: ' + CAST(@count AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT;
--!Message
        EXEC ShowMessage '++Inserted into UPDD';
        EXEC ShowMessage 'INSERTED UserProductivityDaily';
		
        EXEC ShowMessage '--UPDATING WindowNode.UserProductivityDailyDetail';
		
		--მივანიჭოთ ახლიდან ახლად შექმნილი UserProductivityDailyDetail ები აქთივითიებს
        select 1
        WHILE ( @@ROWCOUNT > 0 )
            BEGIN
                EXEC ShowMessage '--UPDATING WindowNode.UserProductivityDailyDetail - Internal';
                UPDATE TOP ( 10000 )
                        wn
                SET     wn.UserProductivityDailyDetail = updd.Oid
                FROM    UserActivity wn WITH ( INDEX ( [iAV2_ObjectTypeEq8_UPDDIsNull_ProductivityBaseIsNotNull] ) ) 
                        ,dbo.UserProductivityDailyDetail updd 
                WHERE   wn.ObjectType = 8
                        AND wn.UserProductivityDailyDetail IS NULL
                        AND wn.ProductivityBase IS NOT NULL
                        AND wn.FirstCapturedOn IS NOT NULL	--Used to match index:iAV2
                        AND wn.ActiveDuration > 0
                        AND updd.SystemUser = wn.SystemUser
                        AND updd.ProductivityBase = wn.ProductivityBase
                        AND updd.Date = wn.FirstCapturedOnDate
                        AND updd.HourFrom = wn.FirstCapturedOnHour
						        and   wn.ID in (select Id from #uaIds)

                OPTION  ( RECOMPILE )
            END 

        EXEC ShowMessage '++UPDATING WindowNode.UserProductivityDailyDetail';
	
		--ისეთი UserProductivityDailyDetail ებს რომლებსაც დეილი არ აქვთ მინიჭებული #1 
		-- #2 მივანიჭოთ  DailyDuration = SUM(ua.ActiveDuration) და
		--ActivityStart = MIN(ua.MaxFirstCapturedOn)
		--ActivityEnd = MAX(ua.MinLastCapturedOn)
		-- სადაც ua არის UserProductivityDailyDetail ში გაერთიანებული იუზერაქთივითიები
		
        WITH    UpddToUpdate --#1
                  AS ( SELECT   ua.UserProductivityDailyDetail ,
                                MIN(ua.MaxFirstCapturedOn) MaxFirstCapturedOn ,
                                MAX(ua.MinLastCapturedOn) MinLastCapturedOn ,
                                SUM(ua.ActiveDuration) DailyDuration
                       FROM     dbo.UserActivity ua
                                JOIN dbo.UserProductivityDailyDetail updd ON updd.Oid = ua.UserProductivityDailyDetail
                       WHERE    updd.UserProductivityDaily IS NULL -- updd.ActivityStart IS NULL AND ua.MaxFirstCapturedOn IS NOT NULL
                       GROUP BY ua.UserProductivityDailyDetail
                     )
            UPDATE  updd --#2
            SET     updd.ActivityStart = UpddToUpdate.MaxFirstCapturedOn ,
                    updd.ActivityEnd = UpddToUpdate.MinLastCapturedOn ,
                    updd.DailyDuration = UpddToUpdate.DailyDuration
            FROM    dbo.UserProductivityDailyDetail updd
                    JOIN UpddToUpdate ON UpddToUpdate.UserProductivityDailyDetail = updd.Oid;
		
        EXEC ShowMessage '--Generating #flatProductivityException';
		  IF(OBJECT_ID('tempdb..#flatProductivityException') Is Not Null)
Begin
    Drop Table #flatProductivityException
END
		--	#flatProductivityException დროებით თეიბლში ვირჩევთ ისეთ ProductivityException ებს რომლებსაც 
		-- აქვთ მიმდინარე (pe2pb.ExpiredOn IS NULL) ბმა არსებულ (JOIN dbo.ProductivityBase) ProductivityBase თან და SystemUser თან  
        SELECT  pe2pb.ProductivityBase ,
                pe2su.SystemUser ,
                pe.ProductivityType ,
				--If pe changes its ProductivityType AFTER it gets created, or any of the two collection members gets added
                MAX(dbo.Maxi(dbo.Maxi(pe.LastModifiedOn, dbo.Maxi(pe2pb.CreatedOn, pe2su.CreatedOn)), pb.LastModifiedOn)) CREATEdOn ,
                COUNT(*) cnt
        INTO    #flatProductivityException
        FROM    dbo.ProductivityException pe
                JOIN dbo.ProductivityException2ProductivityBase pe2pb ON pe2pb.ExpiredOn IS NULL
                                                                         AND pe2pb.ProductivityException = pe.ID
                JOIN dbo.ProductivityException2SystemUser pe2su ON pe2su.ExpiredOn IS NULL
                                                                   AND pe2su.ProductivityException = pe.ID
                JOIN dbo.ProductivityBase pb ON pb.ID = pe2pb.ProductivityBase
        GROUP BY pe2pb.ProductivityBase ,
                pe2su.SystemUser ,
                pe.ProductivityType;

        EXEC ShowMessage '++Generated #flatProductivityException';

        IF EXISTS ( SELECT  1
                    FROM    #flatProductivityException
                    WHERE   cnt > 1 )
            SELECT  *
            FROM    #flatProductivityException;

			-- განვაახლოთ UserProductivityDailyDetail ის AdjustedProductivityType რომლლის მნიშვნელობასაც ავიღებთ flatProductivityException 
			-- დან თუ არის შესაბამისი ProductivityException (ანუ გამონაკლისებში არის ჩამატებული ამ იუზერისთვის აქტივობის ეს ტიპი. მაგალითად შეიძლება ფეისბუკი ზიგადად მომცდენია მაფრამ 
			-- მარკეტინგისთვის ან ფეისბუკ გვერდის ადმინისთვის პროდუქტიული შეიძლება იყოს) თუ არა და ProductivityBase იდან (ვთქვათ იგივე ფეისბუკის) შესაბამისი მნიშვნელობა (ვთქვათ მომცდენი)
        UPDATE  updd
        SET     updd.AdjustedProductivityType = ISNULL(pe.ProductivityType, pb.ProductivityType) ,
                UserProductivityDaily = NULL
        FROM    dbo.UserProductivityDailyDetail updd
                JOIN dbo.ProductivityBase pb ON pb.ID = updd.ProductivityBase
                LEFT JOIN #flatProductivityException pe ON pe.SystemUser = updd.SystemUser
                                                           AND pe.ProductivityBase = updd.ProductivityBase
        WHERE   updd.AdjustedProductivityType IS NULL
                OR updd.AdjustedProductivityType != ISNULL(pe.ProductivityType, pb.ProductivityType)
		--CREATE INDEX iAV_3_10_updd_AdjustedProductivityTypeIsNull on userproductivitydailydetail (adjustedproductivitytype) where adjustedproductivitytype is null

        EXEC ShowMessage '++Updated UPDD with #flatPE';
		-- Message 
				SET @count = (SELECT COUNT(*) FROM dbo.UserProductivityDailyDetail)
SET @infoMessage = 'Number of elements in UserProductivityDailyDetail: ' + CAST(@count AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT;
--!Message

  IF(OBJECT_ID('tempdb..#GroupedUpddForUpd') Is Not Null)
Begin
    Drop Table #GroupedUpddForUpd
END	;
		-- ისეთი UserProductivityDailyDetail ები რომლებსაც დეილი არ აქვთ დავაჯგუფოთ იუზერით, დღით, დაწყების და დასრულების დროით
        WITH    UpddWithEmptyUpd
                  AS ( SELECT   DISTINCT
                                updd.Date ,
                                hg.HrFrom ,
                                updd.SystemUser
                       FROM     dbo.UserProductivityDailyDetail updd
                                JOIN #HourGroups hg ON hg.Hr = updd.HourFrom
                       WHERE    updd.UserProductivityDaily IS NULL
                                AND updd.[Date] IS NOT NULL
                     )
            SELECT  NEWID() Oid ,
                    updd.SystemUser ,
                    updd.[Date] ,
                    hr.HrFrom HourFrom ,
                    hr.HrUntil HourUntil ,
                    MIN(updd.ActivityStart) ActivityStart ,
                    MAX(updd.ActivityEnd) ActivityEnd ,
                    SUM(updd.DailyDuration) Active ,
                    DATEDIFF(SECOND, MIN(updd.ActivityStart), MAX(updd.ActivityEnd)) - SUM(updd.DailyDuration) Inactive ,
                    SUM(CASE WHEN updd.AdjustedProductivityType = 1 THEN updd.DailyDuration
                             ELSE 0
                        END) AS Productive ,
                    SUM(CASE WHEN updd.AdjustedProductivityType = 2 THEN updd.DailyDuration
                             ELSE 0
                        END) AS Distracting ,
                    SUM(CASE WHEN updd.AdjustedProductivityType = 3 THEN updd.DailyDuration
                             ELSE 0
                        END) AS Neutral ,
                    SUM(CASE WHEN ISNULL(updd.AdjustedProductivityType,0) = 0 THEN updd.DailyDuration
                             ELSE 0
                        END) AS Undefined
            INTO    #GroupedUpddForUpd
            FROM    UserProductivityDailyDetail updd
                    JOIN #HourGroups hr ON hr.Hr = updd.HourFrom
                    JOIN ProductivityBase pb ON updd.ProductivityBase = pb.ID
                    JOIN UpddWithEmptyUpd uw ON uw.Date = updd.Date
                                                AND uw.HrFrom = hr.HrFrom
                                                --AND uw.HrUntil = updd.HourUntil
                                                AND uw.SystemUser = updd.SystemUser
					--Not Anymore as UPDD has it already-- This is needed for ProductivityException
            GROUP BY updd.SystemUser ,
                    updd.[Date] ,
                    hr.HrFrom ,
                    hr.HrUntil
        OPTION  ( RECOMPILE )

        EXEC ShowMessage '++Generated temp for UPD';
        EXEC ShowMessage '--Updating UPD';

        CREATE INDEX i#GroupedUpddForUpd ON #GroupedUpddForUpd (SystemUser, Date)
		CREATE INDEX i#GroupedUpddForUpd2 ON #GroupedUpddForUpd (SystemUser, Date, HourFrom, HourUntil)

-- Message 

				SET @count = (SELECT COUNT(*) FROM dbo.ProductivityBase)
SET @infoMessage = 'Number of elements in ProductivityBase: ' + CAST(@count AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT
--!Message

				SET @count = (SELECT COUNT(*) FROM dbo.UserActivity)
SET @infoMessage = 'Number of elements in UserActivity: ' + CAST(@count AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT
		

		SET @count = (SELECT COUNT(*) FROM #GroupedUpddForUpd)
SET @infoMessage = 'Number of elements in #GroupedUpddForUpd: ' + CAST(@count AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT



		
		
		-- და ზემოთ დაჯგუფებული UserProductivityDailyDetail (#GroupedUpddForUpd ში) ების მიხედვით განვაახლოთ UserProductivityDaily ები
        UPDATE  upd
        SET     upd.ActivityStart = u.ActivityStart ,
                upd.ActivityEnd = u.ActivityEnd ,
                upd.Active = ISNULL(u.Active, 0) ,
                upd.Inactive = ISNULL(u.Inactive, 0) ,
                upd.Productive = ISNULL(u.Productive, 0) ,
                upd.Distracting = ISNULL(u.Distracting, 0) ,
				upd.Undefined = ISNULL(u.Undefined, 0) ,
                upd.Neutral = ISNULL(u.Neutral, 0) ,
                upd.CreatedOn = GETDATE()
        FROM    UserProductivityDaily upd
                INNER JOIN #GroupedUpddForUpd u ON --upd.Oid = u.UserProductivityDaily
													   upd.SystemUser = u.SystemUser
                                                   AND upd.Date = u.Date
                                                   AND upd.HourFrom = u.HourFrom
                                                   AND upd.HourUntil = u.HourUntil
                                                   --AND upd.GCRecord IS NULL
		SET @count = @@ROWCOUNT
SET @infoMessage = 'Number of rows affected at updating upds' + CAST(@count AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT
			
        EXEC ShowMessage '++Updated UPD';
        EXEC ShowMessage '--Inserting UPD';

		-- და შევქმნათ ახლები რომლებისთვისაც არ არსებობს 
        INSERT  INTO dbo.UserProductivityDaily
                ( Oid ,
                  SystemUser ,
                  [Date] ,
                  HourFrom ,
                  HourUntil ,
                  ActivityStart ,
                  ActivityEnd ,
                  Active ,
                  Inactive ,
                  Productive ,
                  Distracting ,
                  Neutral ,
                  Undefined ,
                  CreatedOn
                )
                SELECT	DISTINCT
                        u.Oid ,
                        u.SystemUser ,
                        u.[Date] ,
                        u.HourFrom ,
                        u.HourUntil ,
                        u.ActivityStart ,
                        u.ActivityEnd ,
                        u.Active ,
                        ISNULL(u.Inactive,0) ,
                        u.Productive ,
                        u.Distracting ,
                        u.Neutral ,
                        u.Undefined ,
                        GETDATE()
                FROM    #GroupedUpddForUpd u
                        LEFT JOIN UserProductivityDaily upd ON u.SystemUser = upd.SystemUser
                                                               AND u.Date = upd.Date
                                                               AND u.HourFrom = upd.HourFrom
                                                               --AND u.HourUntil = upd.HourUntil
                WHERE   --u.Inactive is not null and
				upd.Oid IS NULL
                        AND upd.GCRecord IS NULL
		SET @count = @@ROWCOUNT
SET @infoMessage = 'Number of rows affected at creating upds' + CAST(@count AS VARCHAR(10))
RAISERROR(@infoMessage, 10, 0) WITH NOWAIT
       
	    EXEC ShowMessage '++Inserted UPD';
			    
        EXEC ShowMessage '--Updating UPDD with UPD';
		        
        UPDATE  updd
        SET     updd.UserProductivityDaily = upd.Oid
        FROM    dbo.UserProductivityDailyDetail updd
                JOIN #HourGroups hr ON hr.Hr = updd.HourFrom
                JOIN dbo.UserProductivityDaily upd ON upd.SystemUser = updd.SystemUser
                                                      AND upd.Date = updd.Date
                                                      AND upd.HourFrom = hr.HrFrom
                                                      AND upd.HourUntil = hr.HrUntil
        WHERE   updd.UserProductivityDaily IS NULL
        OPTION  ( RECOMPILE )
		
        EXEC ShowMessage '++Updated UPDD with UPD';
	
    END


