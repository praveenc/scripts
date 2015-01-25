@echo off

rem ---------------------------------------------------------------------------
rem Package MIDS to E:\Builds
rem From a command prompt, run the following
rem ---------------------------------------------------------------------------

setlocal
set path=%path%;%CD%

set Build=%1
set Branch=%2
set FwMinorVersion=%3

set Release=%Build:~0,3%
set FwMajorVersion=%FwMinorVersion:~0,3%

set ROBOCOPY_EXCLUDE=*.cd *.sln *.csproj *.cs *.pdb *.user *.vspscc *.scc *.pssym web.config *.suo Thumbs.db
set EXCLUDE_DIR=obj ClassDiagrams DataBinding Helper obj Properties Security URLRouting

set SOURCE_DIR=%CD%\..\Sources\%Branch%\Application
set MIDS_DIR=%SOURCE_DIR%\MIDSWeb
if "%Branch%"=="MAINLINE" (
	set MIDSINITDB_DIR=%SOURCE_DIR%\MIDSInitDB
) else (
	set MIDSINITDB_DIR=%SOURCE_DIR%\MIDSDataModelTest\MIDSInitDB
)
set NEWDB_DIR=%SOURCE_DIR%\..\Database
If not x%branch:feature=%==x%branch% (
	set LIB_DIR=%CD%\..\Sources\Lib
) else (
	set LIB_DIR=%CD%\..\Lib
)
set WCFSERVICE_DIR=D:\Frameworks\mainline\ComplianceScanFramework\ComplianceService
set JOBQUEUE_DIR=%LIB_DIR%\OwFramework\%FwMajorVersion%\%FwMinorVersion%\Release


set TARGET_DIR=E:\Builds\OWBridge\%Release%\%Build%
set BUILDINFO_DIR=%TARGET_DIR%
set APP_DIR=%TARGET_DIR%\app
set DB_DIR=%TARGET_DIR%\Database
set LOG_DIR=%TARGET_DIR%\log
set LOG_FILE=%LOG_DIR%\%Build%.OWBridge.copyapp.log

if not exist %APP_DIR% mkdir %APP_DIR%
if not exist %DB_DIR% mkdir %DB_DIR%
if not exist %LOG_DIR% mkdir %LOG_DIR%

echo %date:~4% %time%: Packaging from %SOURCE_DIR% to %APP_DIR% >> %LOG_FILE%
rem ----------------------------------------
rem Copying Web_Clientside
echo %date:~4% %time%: Copying MIDSWeb
echo %date:~4% %time%: Copying MIDSWeb >> %LOG_FILE%
robocopy %MIDS_DIR% %APP_DIR%\MIDSWeb /S /XF %ROBOCOPY_EXCLUDE% /XD %EXCLUDE_DIR% /LOG+:%LOG_FILE% /NP /NJS
robocopy %SOURCE_DIR%\BridgeWebServices\bin %APP_DIR%\MIDSWeb\BridgeWebServices\bin /MIR /XF %ROBOCOPY_EXCLUDE% /LOG+:%LOG_FILE% /NP /NJS
robocopy %MIDS_DIR%\bin %APP_DIR%\MIDSWeb\BridgeWebServices\bin *.lic /LOG+:%LOG_FILE% /NP /NJS
robocopy %SOURCE_DIR%\BridgeWebServices %APP_DIR%\MIDSWeb\BridgeWebServices *.svc /XD "obj" /LOG+:%LOG_FILE% /NP /NJS

rem ----------------------------------------
rem Required empty folders
echo %date:~4% %time%: Creating required folders
mkdir %APP_DIR%\MIDSWeb\BrandingContent
mkdir %APP_DIR%\MIDSWeb\CustomFiles
mkdir %APP_DIR%\MIDSWeb\CustomResources
mkdir %APP_DIR%\MIDSWeb\Documents
mkdir %APP_DIR%\MIDSWeb\Portals\Default
mkdir %APP_DIR%\MIDSWeb\Preview\App_LocalResources

rem ----------------------------------------
rem Compliance Service
echo %date:~4% %time%: Copying ComplianceService DLLS
echo %date:~4% %time%: Copying ComplianceService >> %LOG_FILE%
robocopy %SOURCE_DIR%\MIDSPresenters\bin\Release %APP_DIR%\MIDSWeb\bin Oceanwide.ComplianceServiceClient.dll /LOG+:%LOG_FILE% /NP /NJS

rem ------------------------------------------
rem WCF Services
echo %date:~4% %time%: Copying WCF_Service files
echo %date:~4% %time%: Copying WCF_Service >> %LOG_FILE%
robocopy %WCFSERVICE_DIR% %APP_DIR%\WCF_Service\ComplianceService /E /XF %ROBOCOPY_EXCLUDE% *.config /LOG+:%LOG_FILE% /NP /NJS

attrib -r %APP_DIR%\WCF_Service\ComplianceService\*.*

rem ----------------------------------------
rem Database Scripts
echo %date:~4% %time%: Copying MIDSInitDB Files
robocopy %MIDSINITDB_DIR%\bin\Release %DB_DIR%\MIDSInitDB /MIR /XF %ROBOCOPY_EXCLUDE% /LOG+:%LOG_FILE% /NP /NJS
robocopy %MIDSINITDB_DIR% %DB_DIR%\MIDSInitDB countries.txt states.txt BridgeDBConfig.xml /LOG+:%LOG_FILE% /NP /NJS

echo %date:~4% %time%: Copying MIDSInitDB Files to DBSetup-Working\OwBridge_BETA_Staging
robocopy %DB_DIR%\MIDSInitDB E:\Builds\OWBridge\%Release%\DBSetup-Working\OwBridge_BETA_Staging\MIDSInitDB /MIR /LOG+:%LOG_FILE% /NP /NJS

rem ----------------------------------------
rem Copying MIDSDataModel Files
echo %date:~4% %time%: Copying MIDSDataModel Files
robocopy %SOURCE_DIR%\MIDSDataModel\bin\Release %DB_DIR%\MIDSInitDB MIDSDataModel.dll.config /LOG+:%LOG_FILE% /NP /NJS
robocopy %SOURCE_DIR%\MIDSDataModel %DB_DIR%\MIDSDataModel *.sql /LOG+:%LOG_FILE% /NP /NJS

rem ----------------------------------------
rem Copying NewDB Files
echo %date:~4% %time%: Copying NewDB Files
set SOURCE_DIR=%CD%\..\Database
robocopy %NEWDB_DIR%\NewDB %DB_DIR%\NewDB *.sql /LOG+:%LOG_FILE% /NP /NJS


rem ------------------------------------------
rem JobQueue DLLs and exe
echo %date:~4% %time%: Copying JobQueue DLLs
set TARGET_DIR=E:\Builds\OWBridge\%Release%\%Build%\JobQueue
pushd %TARGET_DIR%
robocopy %JOBQUEUE_DIR% %TARGET_DIR% Oceanwide.JobQueueCore.dll Oceanwide.LoggingFramework.dll PostSharp.dll OwJobServices.exe /LOG+:%LOG_FILE% /NP /NJS
attrib -r *.* /s
popd

REM ------------------------------------------
REM BuildInfo.txt
(echo Build:%Build% && echo Date:%date:~4% %time%) >> %BUILDINFO_DIR%\BuildInfo.txt

REM -- END COPYAPP.BAT -- 