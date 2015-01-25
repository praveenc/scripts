PRINT 'Processing OwSysModule insert'
INSERT INTO [dbo].[OwSysModule]([ModuleName],[InstalledFlag],[VersionNo],[ObjectType],[UpdateDate]) VALUES ('CORE',1,'2.0.0.109','CombinePackage',GETDATE())
