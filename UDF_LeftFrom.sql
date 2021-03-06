USE [Coshkee];
GO

/****** Object:  UserDefinedFunction [dbo].[Sec2TimeD]    Script Date: 11/22/2018 2:02:21 PM ******/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
ALTER FUNCTION [dbo].LeftFrom(@leftOfText NVARCHAR(10), 
                              @fromText   NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
     BEGIN
         DECLARE @charIndex INT;
         SET @charIndex = CHARINDEX(@leftOfText, @fromText);
         --SET @test = 'Foreign Tax Credit - 1997'

         RETURN CASE
                  WHEN @charIndex = 0 THEN @fromText
                  ELSE LEFT(@fromText, @charIndex - 1 + LEN(@leftOfText))
                END;
     END;

         --select dbo.LeftFrom('aspx','stop-c.moh.gov.ge/Pages/User/FormDataView.?%5bparams%5d=TW9kZT1FZGl0JkZvcm1JRD00Nzk3NDI3Ni00MTBiLTQwNzEtYmJjOC03Y2JlNjMzMmIxNjAmT3duZXJJRD00Nzk3NDI3Ni00MTBiLTQwNzEtYmJjOC03Y2JlNjMzMmIxNjAmUmVjb3JkSUQ9JlBhcmVudElEPSZSZXR1cm5Vcmw9YUhSMGNEb3ZMM04wYjNBdFl5NXRiMmd1WjI5MkxtZGxMMUJoWjJWekwxVnpaWEl2Um05')