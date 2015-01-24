@echo OFF
set psexe=C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe

SET buildnumber=%BUILD_NUMBER%
SET archive_ws=%WORKSPACE%\svn
SET platform_ws=%WORKSPACE%\netmail_platform

echo Writing Build Revision to lastrev.txt

pushd %archive_ws%

svn info . > lastrev.txt

popd

pushd %platform_ws%

svn info . > lastrev.txt

popd

%psexe% -Command "{Set-ExecutionPolicy Unrestricted -scope CurrentUser}"
%psexe% -Command "& {.\tag-build.ps1 -buildnumber '%BUILD_NUMBER%' -workspaces '%archive_ws%','%platform_ws%'}"
