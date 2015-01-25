@echo off

rem ---------------------------------------------------------------------------
rem Package MIDS to E:\Builds\SFBridge
rem ---------------------------------------------------------------------------

setlocal
set path=%path%;%CD%

set Build=%1
set FwVersion=%2
set Release=%Build:~0,3%
set FWMajorVersion=%FwVersion:~0,3%

set SOURCE_DIR=%CD%\..\Application
set MIDS_DIR=%CD%\..\..\..\Binaries\MIDS\
set MIDSINITDB_DIR=%CD%\..\..\..\Binaries\MIDSDataModelTest
set FW_DIR=\\192.168.0.33\Builds\SharedFrameworks\%FWMajorVersion%\%FWVersion%
set WCFSERVICE_DIR=%FW_DIR%\WCF_Service
set JOBQUEUE_DIR=%FW_DIR%\Release

set TARGET_DIR=E:\Builds\SFBridge\%Release%\%Build%
set BUILDINFO_DIR=%TARGET_DIR%
set APP_DIR=%TARGET_DIR%\app
set LOG_DIR=%TARGET_DIR%\log
set LOG_FILE=%LOG_DIR%\%Build%.OWBridge.copyapp.log

if not exist %TARGET_DIR% mkdir %TARGET_DIR%
if not exist %LOG_DIR% mkdir %LOG_DIR%

echo %date:~4% %time%: Packaging from %SOURCE_DIR% to %TARGET_DIR% >> %LOG_FILE%
rem ----------------------------------------
rem Copying Web_Clientside
echo %date:~4% %time%: Copying MIDSWeb
echo %date:~4% %time%: Copying MIDSWeb >> %LOG_FILE%
robocopy %MIDS_DIR%\_PublishedWebsites\MIDSWeb %APP_DIR%\MIDSWeb /E /XF *.pdb web.config *.pssym /XD "bin" /LOG+:%LOG_FILE% /NP /NJS
robocopy %MIDS_DIR% %APP_DIR%\MIDSWeb\bin /E /XF *.pdb *.config *.pssym /XD "_PublishedWebsites" /LOG+:%LOG_FILE% /NP /NJS
robocopy %MIDS_DIR%\_PublishedWebsites\BridgeWebServices %APP_DIR%\MIDSWeb\BridgeWebServices /E /XF *.pdb *.config /LOG+:%LOG_FILE% /NP /NJS
robocopy %SOURCE_DIR%\MIDSResource %APP_DIR%\MIDSWeb\App_Data\StandardResources *.resx /LOG+:%LOG_FILE% /NP /NJS

REM -------------------
REM COPY LIC files to MIDSWeb\Bin
echo %date:~4% %time%: Copying lic files to MIDSWeb
echo %APP_DIR%
for /R D:\Lib %%f in (*.lic) do copy %%f %APP_DIR%\MIDSWeb\bin

REM -------------------
REM COPY LIC files to MIDSWeb\BridgeWebServices\Bin
echo %date:~4% %time%: Copying lic files to BridgeWebServices
for /R D:\Lib %%f in (*.lic) do copy %%f %APP_DIR%\MIDSWeb\BridgeWebServices\bin

rem -- required empty folders
mkdir %APP_DIR%\MIDSWeb\BrandingContent
mkdir %APP_DIR%\MIDSWeb\CustomFiles
mkdir %APP_DIR%\MIDSWeb\CustomResources
mkdir %APP_DIR%\MIDSWeb\Documents
mkdir %APP_DIR%\MIDSWeb\Portals\Default
mkdir %APP_DIR%\MIDSWeb\Preview\App_LocalResources

rem ----------------------------------------
rem Copying Framework Controls Content
echo %date:~4% %time%: Copying Framework Controls Content
echo %date:~4% %time%: Copying Framework Controls Content >> %LOG_FILE%
robocopy %FW_DIR%\Contents %APP_DIR%\MIDSWeb\Contents /E /LOG+:%LOG_FILE% /NP /NJS

rem ----------------------------------------
rem Compliance Service
echo %date:~4% %time%: Copying ComplianceService DLLS
set SOURCE_DIR=%CD%\..\Application
robocopy %SOURCE_DIR%\MIDSPresenters\obj\Release %APP_DIR%\MIDSWeb\bin Oceanwide.ComplianceServiceClient.dll Oceanwide.ComplianceServiceClient.pdb /LOG+:%LOG_FILE% /NP /NJS

rem ------------------------------------------
rem WCF Services
echo %date:~4% %time%: Copying WCF_Service files
echo %date:~4% %time%: Copying WCF_Service >> %LOG_FILE%
robocopy %WCFSERVICE_DIR% %APP_DIR%\WCF_Service /MIR /LOG+:%LOG_FILE% /NP /NJS


rem ------------------------------------------
rem JobQueue DLLs and exe
echo %date:~4% %time%: Copying JobQueue DLLs
set TARGET_DIR=E:\Builds\SFBridge\%Release%\%Build%\JobQueue
robocopy %JOBQUEUE_DIR% %TARGET_DIR% Oceanwide.JobQueueCore.dll Oceanwide.LoggingFramework.dll PostSharp.dll OwJobServices.exe /LOG+:%LOG_FILE% /NP /NJS

attrib -r *.* /s
popd

REM ---- BuildInfo.txt----
echo %date:~4% %time%: Copying BuildInfo
(echo Build:%Build% && echo Date:%date:~4% %time%) >> %BUILDINFO_DIR%\BuildInfo.txt

REM -- END COPYAPP.BAT -- 