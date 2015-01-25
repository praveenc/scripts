<#
.Synopsis
   Reads MIDSInitDB.exe.config and modifies "ConnectionString"
.DESCRIPTION
   Modify Connection String Data Source to PRB1MES2\ST and Initial Catalog to Bridge_OWBridge in MIDSInitDB.exe.config
.EXAMPLE
   .\Set-MIDSInitDBConfig.ps1 -FilePath 'E:\Builds\OWBridge\2.1\MIDSInitDB\MIDSInitDB.exe.config'
#>
Param(
    
    [CmdletBinding()]
    [Parameter(Mandatory=$true,
                  ValueFromPipelineByPropertyName=$true,
                   Position=0)]
    [String]$FilePath

)

$OutputLogFile = "E:\Builds\OWBridge\2.1\DBSetup-Working\log\MIDSInitDB.config.log"
[String]$datasource = 'PRB1MES2\ST'
[String]$initial_catalog = 'Bridge_OWBridge'
[String]$db_user = 'BridgeInitSQL'
[String]$db_hash = 'E4B25624'

Write-Output "-- Modifying $FilePath..."

(Get-Content $FilePath) |
ForEach-Object {$_ -replace "Data Source=(.*?);", "Data Source=$datasource;"} |
ForEach-Object {$_ -replace "Initial Catalog=(.*?);", "Initial Catalog=$initial_catalog;"} |
ForEach-Object {$_ -replace "User ID=(.*?);", "User ID=$db_user;"} |
ForEach-Object {$_ -replace "Password=(.*?);", "Password=$db_hash;"} |
Set-Content $FilePath

Write-Output "-- $FilePath modified successfully! --"