declare @from datetime = '1jan2016'
declare @until datetime = '1jan2020'
declare @currentuser uniqueidentifier


set @From = IIF(@From < '1jan2016', DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1), @From)
set @Until = IIF(@Until > '1jan2020', DATEFROMPARTS(YEAR(DATEADD(MONTH,1, GETDATE())),MONTH(DATEADD(MONTH,1, GETDATE())),1), @Until)


declare @CurrentUserEvaluated nvarchar(100);
if @CurrentUser is null begin set @CurrentUserEvaluated = 'ccfe8ae6-26eb-4bce-a529-10c56e43663a' end
else begin set @CurrentUserEvaluated =  @CurrentUser end 
IF(OBJECT_ID('tempdb..#tempForUsrCte') Is Not Null)
Begin
    Drop Table #tempForUsrCte
END
create table #tempForUsrCte(UsOid uniqueidentifier);
--შევამოწმოთ თუ აქვს აპლიკაციის მიმდინარე იუზერს განსაზღვრული იუზერების ჯგუფი რომელსაც უნდა ხედავდეს
IF EXISTS (SELECT * FROM systemuser2filteringgroup sysUserToGroup 
                  
                JOIN systemuseractivitiesfilteringgroup filteringGroup 
                  ON filteringGroup.id = 
                     sysUserToGroup.systemuseractivitiesfilteringgroup 
                JOIN applicatiouser2systemuserfiltergroup appUserToGroup 
                  ON appUserToGroup.systemuseractivitiesfilteringgroup = 
                     filteringGroup.id 
         --!  
         WHERE 
          --Filtering User  
          filteringGroup.userinclusiontypeenum = 0 
          AND filteringGroup.expiredon IS NULL 
          AND appUserToGroup.expiredon IS NULL 
          AND sysUserToGroup.expiredon IS NULL 
          AND appUserToGroup.securitysystemuserexbase like @CurrentUserEvaluated
          )
--Convert(uniqueidentifier, @CurrentUserEvaluated)
begin 
INSERT INTO #tempForUsrCte ( UsOid )
(
--ვარიანტი როცა ფილტრი ჩართულია 
SELECT su.Oid 
         FROM   dbo.systemuser su 
                JOIN systemuser2filteringgroup sysUserToGroup 
                  ON sysUserToGroup.systemuser = oid 
                JOIN systemuseractivitiesfilteringgroup filteringGroup 
                  ON filteringGroup.id = 
                     sysUserToGroup.systemuseractivitiesfilteringgroup 
                JOIN applicatiouser2systemuserfiltergroup appUserToGroup 
                  ON appUserToGroup.systemuseractivitiesfilteringgroup = 
                     filteringGroup.id 
         --!  
         WHERE 
          --Filtering User  
          filteringGroup.userinclusiontypeenum = 0 
          AND filteringGroup.expiredon IS NULL 
          AND appUserToGroup.expiredon IS NULL 
          AND sysUserToGroup.expiredon IS NULL 
          AND appUserToGroup.securitysystemuserexbase = 
              CONVERT(UNIQUEIDENTIFIER, @CurrentUser) 
          AND su.expiredon IS NULL 
        --AND su.Name NOT LIKE '%abagent%'
		) 
end
ELSE  
begin

INSERT INTO #tempForUsrCte ( UsOid )

--ვარიანტი როცა ფილტრი გამორთულია
(SELECT su.Oid 
FROM   dbo.systemuser su
WHERE  su.ExpiredOn IS  NULL)

end;

with cte as (
select d.Name DepartmentName, su.Name Username, Su.Comment Position, pb.ResourceName,
Case when updd.AdjustedProductivityType = 0 then 'Undefined'
	 when updd.AdjustedProductivityType = 1 then 'Productive'
	 when updd.AdjustedProductivityType = 2 then 'Distracting'
	 when updd.AdjustedProductivityType = 3 then 'Neutral'
end AdjustedProductivityType,
iif(updd.AdjustedProductivityType = 0, updd.DailyDuration, 0) Undefined,
iif(updd.AdjustedProductivityType = 1, updd.DailyDuration, 0) Productive,
iif(updd.AdjustedProductivityType = 2, updd.DailyDuration, 0) Distracting,
iif(updd.AdjustedProductivityType = 3, updd.DailyDuration, 0) Neutral,
updd.DailyDuration DDailyDuration
from UserProductivityDailyDetail updd
join userproductivitydaily upd on updd.UserProductivityDaily = upd.Oid
join systemuser su on updd.SystemUser = su.Oid 
and su.Oid in (select usoid from #tempForUsrCte)
join Department d on d.oid = su.workingdepartment
join ProductivityBase pb on pb.ID = updd.ProductivityBase
where upd.Date between @From and @Until
)
select cte.DepartmentName, cte.Username, cte.Position, cte.ResourceName, cte.AdjustedProductivityType ,
sum(cte.undefined) SumUndefined, sum(cte.Productive) SumProductive, sum(cte.Distracting) SumDistracting, sum(cte.Neutral) SumNeutral, sum(DDailyDuration) SumDaily
From cte
group by cte.DepartmentName, cte.Username, cte.Position, cte.ResourceName, cte.AdjustedProductivityType