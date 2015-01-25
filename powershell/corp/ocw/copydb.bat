@echo off

setlocal
set path=%path%;%CD%;E:\Builds

set Build=%1
set Timestamp=%2
set Branch=%3
set Container=%4

set Release=%Build:~0,3%
set TARGET_DIR=E:\Builds\OWBridge\%Release%\%Build%
set LOG_DIR=%TARGET_DIR%\log
SET LOG_FILE=%LOG_DIR%\%Build%.OWBridge.copydb.log

if "%Branch%"=="MAINLINE" (
	
	echo %date:~4% %time%: Executing MIDSInitDB on Staging Server
	
	rem ---------------------------------------------------
	REM Create MIDSInitDB Combine Package
	echo %date:~4% %time%: Calling CreateBridgeDBPackage.vbs
	cscript /nologo \\192.168.0.55\scripts\CreateBridgeDBPackage.vbs /build %Build% /LicenseeName OwBridge /Force >> %LOG_FILE%
	echo *************************************************** >> %LOG_FILE%
	rem ---------------------------------------------------
	REM Customize MIDSInitDB Package for LicenseeName
	echo %date:~4% %time%: Calling CustomizeBridgeDBPackage.vbs
	cscript /nologo \\192.168.0.55\scripts\CustomizeBridgeDBPackage.vbs /Env Staging /Build %Build% /BETA /LicenseeName OwBridge >> %LOG_FILE%
	echo *************************************************** >> %LOG_FILE%

	rem ---------------------------------------------------
	REM Execute MIDSInitDB.exe on Database
	echo %date:~4% %time%: Calling RefreshBridgeDB.vbs
	cscript /nologo \\192.168.0.55\scripts\RefreshBridgeDB.vbs /Branch %Release% >> %LOG_FILE%
	echo *************************************************** >> %LOG_FILE%

) else (
	
	echo %date:~4% %time%: Ignoring Creation of MIDSInitDB Package
	
)

rem ---------------------------------------------------
REM Get incremental DBScripts or Deployment instructions

REM SET Timestamp=%Timestamp:~0,10% %Timestamp:~11,16%:00
echo "Calling Get-OWIncDBScripts.ps1 -BranchName $/Bridge/%Branch% -Build %Build% -LastBuildDate %Timestamp% -LogDirectory %LOG_DIR% -Container %Container%"
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe "& '%CD%\Get-OWIncDBScripts.ps1' -BranchName '$/Bridge/%Branch%' -BuildNumber '%Build%' -LastBuildDate '%Timestamp%' -LogDirectory '%LOG_DIR%' -Container %Container%"
