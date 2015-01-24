$ErrorActionPreference="SilentlyContinue"

#Add PowerShell TeamFoundation Snapin - Required for Some Functions
if ((Get-PSSnapin -Name Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue) -eq $null ){

    Add-PSSnapin Microsoft.TeamFoundation.PowerShell

}

#SQLFarmCombine Package Variables
$FarmCombineExePath = "C:\Program Files\JNetDirect\Combine"
$FarmCombineBuildExe = "$FarmCombineExePath\cpabuild.exe"
$FarmCombineExe = "$FarmCombineExePath\cpaexec.exe"

#Process parameters for FarmCombine Build
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "$FarmCombineBuildExe"
$pinfo.RedirectStandardError = $true
$pinfo.RedirectStandardOutput = $true
$pinfo.UseShellExecute = $false

#Process parameters for FarmCombine Exec
$pexecinfo = New-Object System.Diagnostics.ProcessStartInfo
$pexecinfo.FileName = "$FarmCombineExe"
$pexecinfo.RedirectStandardError = $true
$pexecinfo.RedirectStandardOutput = $true
$pexecinfo.UseShellExecute = $false

#Email Parameters
$FromAddress ="TFS@Oceanwide.com"
$CMEmailAddress = "ConfigurationManagement@myserver.com"
$SmtpServer = "prexch1.myserver.com"

#Create Object for UTF8 No BOM Encoding
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($true)

#INCOMPLETE
function Get-OWServiceStatus
{
    <#
    .Synopsis
       Gets Status of all installed services on the server
    .DESCRIPTION
       Gets Status of all installed services on the server
    .EXAMPLE
       Example of how to use this cmdlet
    .EXAMPLE
       Another example of how to use this cmdlet
    #>

    [CmdletBinding()]
    Param
    (
        #Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Param1,

        # Param2 help description
        [int]
        $Param2
    )

    Begin
    {
    }
    Process
    {
    }
    End
    {
    }
}

function Get-OWBuildInfo
{
    <#
    .Synopsis
       Gets Build Info from Build Info.txt
    .DESCRIPTION
       Gets Build Info from Build Info.txt
    .EXAMPLE
       Get-OWBuildInfo -Product Genoa
    .EXAMPLE
       Get-OWBuildInfo -Product Bridge -Licensee OWBridge
    .NOTES
        Author: Praveen Chamarthi
        Date: 17 Apr 2013
    #>

    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        #Product
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet("Bridge","Genoa")]
        [String]$Product,

        #ComputerName
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidateNotNullOrEmpty()]
        [String]$ComputerName,

        #Licensee
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [String]$Licensee="OWBridge"
        
    )
    Begin{
        
        If($Product.Equals('Bridge')){
            
            $SiteRoot = "E:\Bridge_WEBSITE_Live\$Licensee"

        }elseif($Product.Equals('Genoa')){
            
            $SiteRoot = "E:\Genoa_WEBSITE_Live\Build"
        
        }

    }
    Process{
        
       Get-Content "$SiteRoot\BuildInfo.txt" | Where {$_ -match "\d\.\d{2}\.\d(.*)"} -Verbose

    }
    End{}
}

#INCOMPLETE
function RollOver-OWLogFiles
{
    <#
    .Synopsis
       Rolls Over LogFiles to Network location
    .DESCRIPTION
       Long description
    .EXAMPLE
       RollOver-OWLogFiles -Product Bridge -Licensee OWBridge
    .EXAMPLE
       RollOver-OWLogFiles -Product Bridge -Licensee OWBridge -FileSize 5MB
    .NOTES
        Author: Praveen Chamarthi
        Date: 17 Apr 2013
    #>

    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        #Product
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet("Bridge","Genoa")]
        [String]$Product,

        #Licensee
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        
        [String]$Licensee,

        #FileSize
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [ValidateSet(5MB,7MB,10MB)]
        [System.Int32]$FileSize=5MB
    )

    Begin
    {
        $BridgeLogRepository = "\\192.168.0.99\General\Bridge Group\Bridge Builds-Deployment Logs\"
        

        If($Product -eq 'Bridge'){

            $SiteRoot = 'E:\Bridge_WebSite_LIVE'    
            $logfiles = @("BridgeTrace.txt","BridgeLog.txt","BridgeErrorLog.txt")

        }
    }
    Process
    {
        
        If($logfiles.Length -gt 0){
            
            foreach($log in $logfiles){
                
                $filprefix = $log.ToString().Split('.')[0]
                $timestamp = (Get-Date).ToString('yyyy-MM-dd_hh:mm:ss')

                Get-Content -Path "$SiteRoot\$Licensee\$log" | 
                    Where {$_.Length -gt $FileSize} | 
                    Select FullName |
                    Set-Content

            
            }
        
        }


    }
    End
    {
    }
}

function Set-OWBridgeQTPStateFile
{
    <#
    .Synopsis
       Writes QTP State Records after each build
    .DESCRIPTION
        Writes QTP State Records to file
       \\192.168.0.99\General\QA\QTP\QTPStateQC_Bridge.txt
    .EXAMPLE
       Set-OWBridgeQTPStateFile -Build 2.1.0.20 -Environment QA
    .EXAMPLE
       Set-OWBridgeQTPStateFile -Build 2.1.0.20 -Environment QA -QTPStateFile '\\192.168.0.99\General\QA\QTP\QTPStateQC_Bridge.txt'
    .EXAMPLE
       Set-OWBridgeQTPStateFile -Build 2.1.0.20 -Environment QA -QTPServer PRQAQTP6
    .NOTES
        Author: Praveen Chamarthi
        Date: 17 Apr 2013
    #>
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        #Build Number
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{1,3}")]
        [String]$BuildNumber,

        #Environment for QTP Records
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidateSet("QA","UAT")]
        [String]$Environment,

        #QTPStateFile
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [String]$QTPStateFile="\\192.168.0.99\General\QA\QTP\QTPStateQC_Bridge.txt",

        #QTPServer
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=3)]
        [String]$QTPServer="PRQAQTP6"

    )

    Begin
    {
        #Set QTP RecordState
        $RecordState = "PENDING"
        
        #Branch is sub string of Build Number
        $Branch = $BuildNumber.Substring(0,3)
        
        #Define Types for QA & UAT
        $QATypes = @("Smoke","Submission","Security","Documents","Premium","Portals","Integration")
        $UATTypes = @("Smoke","Miller","Chartis")
    }
    Process
    {
        
        If($Environment -eq 'QA'){
            
            $Types = $QATypes
        
        }elseif($Environment -eq 'UAT'){
            
            $Types = $UATTypes

        }
        
        #Append each line to the QTPStateFile
        
        foreach($type in $Types){
            
            #QA2.1 2.1.0.19 PENDING PRQAQTP6 Premium
            $sEntry = "$Environment$Branch $BuildNumber $RecordState $QTPServer $type"
            $sEntry | Out-File $QTPStateFile -Append

        }

    }
    End
    {
    }
}

function Update-OWInsuranceIndex
{
    <#
    .Synopsis
       Updates Build Number on Insurance Index
    .DESCRIPTION
       Updates Build Number on Insurance Index based on Tag/title Name
       Tag Name implies the value of title attribute in html
    .EXAMPLE
       Update-OWInsuranceIndex -SiteName Bridge -Tag 'BETA STAGING' -BuildNumber '2.1.0.20'
    .NOTES
        Author: Praveen Chamarthi
        Date: 17 Apr 2013
    #>
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        #Index Site Name to Update
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0,
                   HelpMessage="Index Site Name to Update")]
        [ValidateSet("Bridge","Genoa","Integrations","Frameworks")]
        [String]$SiteName,

        #Tag Name to Update
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1,
                   HelpMessage="HTML title attribute of the row containing build number")]
        [ValidateNotNullorEmpty()]
        [String]$Tag,

        #Tag Name to Update
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2,
                   HelpMessage="Build Number to Update")]
        [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{1,3}")]
        [String]$BuildNumber
    )
    Begin{
    
        #InsuranceIndex Server
        $insindex_server = "\\PROPU2\E`$\InsuranceIndex"
        
        #Set Files Names for each Site
        If($SiteName -eq 'Bridge'){

            $index_file = "BridgeSiteIndex.htm"
        
        }elseif($SiteName -eq 'Genoa'){
            
            $index_file = "ViewsonicV1.htm"

        }

    }
    Process{
        
        #Update Insurance Index
        Write-Output "Updating Build Number on Insurance Index"
        $filname = "$insindex_server\$index_file"

        #Save a copy of file before modifying it
        Write-Host "Saving a copy of $filname" 
        Get-Content "$filname" | Set-Content "$filname.tmp"

        #Read each line and if line matches the RegExp Replace with Build Number
        (Get-Content "$filname") | 
        ForEach-Object {
            If($_ -match "<a(.*)($Tag)(.*?)>(.*)</a>"){

                $first_m = $Matches[1]
                $second_m = $Matches[2]
                $third_m = $Matches[3]

                $line = "<a$first_m$second_m$third_m>$BuildNumber</a>"
                #Write-Host "Inside If: $line"
                $_ -replace "<a(.*)(BETA STAGING)(.*?)>(.*)</a>","$line"
            }else{
                $_
            }
        } | Set-Content $filname

    }
    End{}

}

function Enable-OWNagiosAlerts
{
    <#
    .Synopsis
       Enables Specified Nagios Alerts
    .DESCRIPTION
       Long description
    .EXAMPLE
       Example of how to use this cmdlet
    .EXAMPLE
       Another example of how to use this cmdlet
    #>
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        # Alert Name as set in Nagios
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0,
                   HelpMessage="Alert Name as Set in Nagios")]
        [String]$Name,

        #Curl Exe Path
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1,
                   HelpMessage="Path to Curl.exe on Disk")]
        [String]$CurlExePath="d:\utilities",

        #Nagios URL
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2,
                   HelpMessage="URL to Nagios Command")]
        [String]$NagiosURL="http://itmon.myserver.com/nagios/cgi-bin/cmd.cgi",

        #Nagios UserID
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=3,
                   HelpMessage="UserID to Logon with")]
        [String]$NagiosUID="builduser",

        #Nagios Hash
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=4,
                   HelpMessage="PWD to Logon with")]
        [String]$NagiosPW="pass1word"

    )

    Begin
    {
        $CurlExe = "$CurlExePath\curl.exe"
        If(Test-Path $CurlExe){

            Write-Output "Found Curl on Disk at $CurlExe" -Verbose

        }else{
            
            Write-Output "Can't find Curl on Disk at $CurlExe. Try rerunning with -CurlExePath option" -Verbose
            Exit

        }


    }
    Process
    {
        #Prepare Arguments to pass on to Curl
        $arg1 = "-d"
        $arg2 = "cmd_typ=28&cmd_mod=2&host=$Name&btnSubmit=Commit"
        $arg3 = "$NagiosURL"
        $arg4 = "-u"
        $arg5 = $NagiosUID+':'+$NagiosPW

        try{

            #Call Curl with above arguments
            & $CurlExe $arg1 $arg2 $arg3 $arg4 $arg5
        
        }catch{
            
            Write-Warning "Error Executing: $CurlExe $arg1 $arg2 $arg3 $arg4 $arg5" -Verbose
    
        }
    }
    End
    {
    }
}

function Disable-OWNagiosAlerts
{
    <#
    .Synopsis
       Disables Specified Nagios Alerts
    .DESCRIPTION
       Long description
    .EXAMPLE
       Example of how to use this cmdlet
    .EXAMPLE
       Another example of how to use this cmdlet
    #>
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Param1,

        # Param2 help description
        [int]
        $Param2
    )

    Begin
    {
    }
    Process
    {
    }
    End
    {
    }
}

function Scrub-OWScripts
{
    <#
    .Synopsis
       Scrubs SQL Scripts to add IF EXIST .. then DROP
    .DESCRIPTION
       Scrubs SQL Scripts to add IF EXIST .. then DROP for PROCEDURES & FUNCTIONS
    .EXAMPLE
       Scrub-OWScripts -FileToScrub E:\Builds\3.12\3.12.39.01\db-Combine\3.12.39.01\DBScripts\abcd.sql
    .NOTES
        Author: Praveen Chamarthi
        Date: 23 Apr 2013
    #>
    
    Param(
        # File Path to Scrub
        [CmdletBinding()]
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0,
                   HelpMessage="Complete Path to File that needs Scrubbing")]
        [ValidateNotNullorEmpty()]
        [String]$FileToScrub
    
    )

    Begin{

        $filetomodify = $FileToScrub

        $lines = Get-Content $filetomodify

        $filename = Split-Path $filetomodify -Leaf
        Write "----- Scrubbing file: $filename" -Verbose
        
    }
    Process{
        
        $modifiedlines = ""
        foreach($line in $lines){

            #Find lines that is either a PROCEDURE, FUNCTION, TABLE or VIEW
            if($line -match "(ALTER|CREATE)\s+(PROCEDURE|FUNCTION|VIEW|TABLE)\s+(\S+)(.*)$"){

                $sqlType = $Matches[2]
                $sqlName = $Matches[3] -replace "\[|\]",""
                $is_temptable = $false
                $schemaName = $sqlName.Split(".")[0]
                if($sqlName -match "#" -or $schemaName -match "#"){
                    $is_temptable = $true
                }
                $sqlName = $sqlName.Split(".")[1]
                $AfterSqlName = $Matches[4]

                #Write Lines to DROP Objects accordingly
                if($sqlType -eq "PROCEDURE"){

                    $line = "IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_NAME = N'$sqlName' AND ROUTINE_TYPE = 'PROCEDURE' AND SPECIFIC_SCHEMA='$schemaName')`r`n"
                    $line += "DROP PROCEDURE [$schemaName].[$sqlName]`r`n"
                    $line += "`r`n"
                    $line += "GO`r`n"
                    if([System.String]::IsNullOrEmpty($AfterSqlName)){
                        $line += "CREATE PROCEDURE [$schemaName].[$sqlName]"    
                    }else {
                        $line += "CREATE PROCEDURE [$schemaName].[$sqlName] $AfterSqlName"    
                    }

                }
                if($sqlType -eq "FUNCTION"){

                    $line = "IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_NAME = N'$sqlName' AND ROUTINE_SCHEMA = '$schemaName' AND ROUTINE_TYPE = 'FUNCTION')`r`n"
                    $line += "DROP FUNCTION [$schemaName].[$sqlName]`r`n"
                    $line += "`r`n"
                    $line += "GO`r`n"
                    if([System.String]::IsNullOrEmpty($AfterSqlName)){
                        $line += "CREATE FUNCTION [$schemaName].[$sqlName]"
                    }else{
                        $line += "CREATE FUNCTION [$schemaName].[$sqlName] $AfterSqlName"
                    }
                    
                }
                if($sqlType -eq "TABLE" -and $is_temptable -eq $false){

                    $sqlName = $sqlName -replace "\(",""
                    $line = "IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'$sqlName' AND TABLE_SCHEMA = '$schemaName' AND TABLE_TYPE = 'BASE TABLE')`r`n"
                    $line += "DROP TABLE [$schemaName].[$sqlName]`r`n"
                    $line += "`r`n"
                    $line += "GO`r`n"
                    $line += "CREATE TABLE [$schemaName].[$sqlName]("
                   
                }
                if($sqlType -eq "VIEW"){

                    $line = "IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'$sqlName' AND TABLE_SCHEMA = '$schemaName' AND TABLE_TYPE = 'VIEW')`r`n"
                    $line += "DROP VIEW [$schemaName].[$sqlName]`r`n"
                    $line += "`r`n"
                    $line += "GO`r`n"
                    if([System.String]::IsNullOrEmpty($AfterSqlName)){
                        $line += "CREATE VIEW [$schemaName].[$sqlName]"
                    }else{
                        $line += "CREATE VIEW [$schemaName].[$sqlName] $AfterSqlName"
                    }

                }

            }

            $modifiedlines += $line + "`r"
       
       }#end of for-each 
    }
    End{

        Set-Content -Path "$filetomodify" -Value "$modifiedlines"
        $NonUTFFile = Get-Content "$filetomodify"
        [System.IO.File]::WriteAllLines($filetomodify, $NonUTFFile, $Utf8NoBomEncoding)
        Write "----- Done scrubbing $filename" -Verbose
    }
}

function Create-OWCombinePackage
{
    <#
    .Synopsis
       Creates Combine Package for a given db-Combine folder
    .DESCRIPTION
       Creates combine package by recursivley adding files, folders to
       Package. First Creates Package then adds folders and files recursively.
       This script is Product agnostic. Will create package as long as FarmCombineBuild is available.
    .EXAMPLE
       Create-OWCombinePackage -PackageName 2.1.0.1 -ScriptsFolder E:\Builds\OWBridge\2.1\2.1.0.1\db-Combine\2.1.0.1
    .NOTES
        Author: Praveen Chamarthi
        Date: 23 Apr 2013
    #>
    [CmdletBinding()]
    Param
    (

        # PackageName to Create
        [Parameter(Mandatory=$true,
                   Position=0,
                   HelpMessage="Name of Package - do not include extension .cpa")]
        [ValidateNotNullorEmpty()]
        [String]$PackageName,

        # Path to DBScripts Folder Root
        [Parameter(Mandatory=$true,
                   Position=1,
                   HelpMessage="Path to the folder (root) containing scripts")]
        [ValidateNotNullorEmpty()]
        [String]$ScriptsFolder,

        # Container Name to be set for package
        [Parameter(Mandatory=$true,
                   Position=2,
                   HelpMessage="Container Name to be set for package")]
        [ValidateNotNullorEmpty()]
        [String]$Container
        
    )

    Begin
    {

        #Verify if Farm Combine Exists on Disk
        If(Test-Path $FarmCombineBuildExe){

            Write "--- Found executable $FarmCombineBuildExe" -Verbose

        }else{

            throw "Error: Can't find executable $FarmCombineBuildExe"
            Exit
        }

    }
    Process
    {
        
        If( (Get-ChildItem -Recurse $ScriptsFolder).Count -gt 0){
        
            
            #Fetch all Folder Names
            $db_fldrs = Get-ChildItem -Path $ScriptsFolder -Directory -Recurse | Select-Object Name
            #Fetch all Files Under Folders
            $db_files = Get-ChildItem -Path $ScriptsFolder -File -Recurse | Select-Object Directory,Name

            #Create Process Object to Execute
            $p = New-Object System.Diagnostics.Process

            #Create Package with Package Name
            $cp_args = "/Create /p:""$ScriptsFolder\$PackageName"" /t:Unwrapped /overwrite /v"
            
            Write "----- Creating FarmCombine Package $PackageName" -Verbose

            try{
                
                $pinfo.Arguments = $cp_args
                $p.StartInfo = $pinfo
                $p.Start() | Out-Null
                $p.WaitForExit()
                
            }catch{

                Write "Error creating package $PackageName" -Verbose
                Write $_.Exception.Message -Verbose
            
            }

            #Add Each Folder to the Package
            foreach($dir in $db_fldrs){

                $foldername = $dir.Name
                Write "----- Adding folder $foldername to $PackageName" -Verbose

                $cp_args = "/AddFolder /p:""$ScriptsFolder\$PackageName"" /n:""$foldername"" /v"
                try{
                    
                    $pinfo.Arguments = $cp_args
                    $p.StartInfo = $pinfo
                    $p.Start() | Out-Null
                    $p.WaitForExit()

                    #Start-Process $FarmCombineBuildExe -ArgumentList $cp_args -WorkingDirectory $ScriptsFolder -Wait -WindowStyle Hidden
                
                }catch{
                    
                    Write "Error Adding Folder $foldername to $PackageName" -Verbose
                    Write $_.Exception.Message

                }

            }
            
            #Add each file to the Combine Package
            foreach($file in $db_files){
            
                $foldername = $file.Directory.Name
                $scriptnameandpath = $file.Directory.FullName +"\" + $file.Name
                $sqlfilename = $file.Name
                Write "----- Adding file $sqlfilename to $PackageName" 
                
                If($file.Directory.FullName -eq $ScriptsFolder){

                    $cp_args = "/AddScript /p:""$ScriptsFolder\$PackageName"" /l:""$scriptnameandpath"" /r:"""" /v"

                }else{
                    
                    $cp_args = "/AddScript /p:""$ScriptsFolder\$PackageName"" /l:""$scriptnameandpath"" /r:""$foldername"" /v"

                }

                try{

                    $pinfo.Arguments = $cp_args
                    $p.StartInfo = $pinfo
                    $p.Start() | Out-Null
                    $p.WaitForExit()
                    #Start-Process $FarmCombineBuildExe -ArgumentList $cp_args -WorkingDirectory $ScriptsFolder -Wait -WindowStyle Hidden

                }catch{
                    
                    Write "Error Adding script $scriptnameandpath to $PackageName" -Verbose
                    Write $_.Exception.Message

                }


            }

        }

    }
    End
    {

        #Set Container to Package
        $PackagePath =  "$ScriptsFolder\$PackageName"
        $cp_args = "/UpdatePackage /p:""$PackagePath"" /s:Container=""$Container"""
        
        try{

            $pinfo.Arguments = $cp_args
            $p.StartInfo = $pinfo
            $p.Start() | Out-Null
            $p.WaitForExit()
            #Start-Process $FarmCombineBuildExe -ArgumentList $cp_args -WorkingDirectory $ScriptsFolder -Wait -WindowStyle Hidden

        }catch{
            
            Write "Error Updating Container for $PackageName" -Verbose
            Write $_.Exception.Message

        }

        Write "Combine Package Created for Package: $PackageName" -Verbose

    }
}

function Execute-OWCombinePackage
{
    <#
    .Synopsis
       Executes Combine Package on a given Environment
    .DESCRIPTION
       Executes combine package on the given environment existing on the local machine.
       Environments are set-up on BridgeBuild machine. Open FarmCombine to find Env names.
       Save the .cre file in the same folder as db-Combine.
       Sends results by email
    .EXAMPLE
       Execute-OWCombinePackage -PackageName 2.2.0.22 -Environment "BRIDGE_QA"
    .NOTES
        Author: Praveen Chamarthi
        Date: 13 May 2013
    #>
    [CmdletBinding()]
    Param
    (

        # Combine Folder Root
        [Parameter(Mandatory=$true,
                   Position=0,
                   HelpMessage="Full file path to Package")]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]$PackagePath,

        # Container Name on local machine
        [Parameter(Mandatory=$true,
                   Position=1,
                   HelpMessage="FarmCombine Container Name setup on local machine")]
        [ValidateNotNullorEmpty()]
        [String]$Container,

        # Environment name
        [Parameter(Mandatory=$false,
                   Position=2,
                   HelpMessage="Environment Name under  - setup on local machine")]
        [ValidateNotNullorEmpty()]
        [String]$Environment="Bridge_AutoDeploy"
        
    )

    Begin
    {

        #Verify if Farm Combine Exists on Disk
        If( -Not (Test-Path $FarmCombineExe)){

            Write "Error: Can't find executable $FarmCombineExe" -Verbose
            Exit

        }
        If ( -Not (Test-Path $PackagePath)){

            Write "$PackagePath not found " -Verbose

        }


        #Create Process Object to Execute
        $p = New-Object System.Diagnostics.Process

        $PackageName = (Split-Path $PackagePath -Leaf).ToString()
        $cre_folder = (Split-Path $PackagePath).ToString()
        $cre_filepath = "$cre_folder\$PackageName.AutoDeploy.RESULTS.cre"
        

    }
    Process
    {

        #Set Container to Package
        $cp_args = "/UpdatePackage /p:""$PackagePath"" /s:Container=""$Container"""
        
        try{

            $pinfo.Arguments = $cp_args
            $p.StartInfo = $pinfo
            $p.Start() | Out-Null
            $p.WaitForExit()

        }catch{

            Write "Error Updating package $PackageName with Container=$Environment : " $_.Exception.Message -Verbose

        }
        
        
        #Create Package with Package Name
        $cp_args = "/p:""$PackagePath"" /o:""$cre_filepath"" /e:""$Environment"" /r:StopAll /t:On /v /w"

        #Write " CRE Path: $cre_filepath" -Verbose
        Write "----- Executing $PackagePath on $Environment with args $cp_args" -Verbose

        try{
            
            $pexecinfo.Arguments = $cp_args
            $p.StartInfo = $pexecinfo
            $p.Start() | Out-Null
            $p.WaitForExit()
            
        }catch{

            Write "Error Executing package $PackagePath : " $_.Exception.Message -Verbose
        
        }

    }
    End
    {
        
        Write "Combine Package $PackagePath Executed on Environment $Environment" -Verbose

    }

}

function Set-OWMIDSInitDBConfig
{
    <#
    .Synopsis
       Reads MIDSInitDB.exe.config and modifies "ConnectionString" to point to PRB1MES2\ST
    .DESCRIPTION
       Modify Connection String Data Source to PRB1MES2\ST and Initial Catalog to Bridge_OWBridge in MIDSInitDB.exe.config
    .EXAMPLE
       .\Set-MIDSInitDBConfig.ps1 -FilePath 'E:\Builds\OWBridge\2.1\MIDSInitDB\MIDSInitDB.exe.config'
    #>
    Param(
    
        [CmdletBinding()]
        [Parameter(Mandatory=$true,
                      ValueFromPipelineByPropertyName=$true,
                       Position=0,
                       HelpMessage="File Path to MIDSInitDB.exe.config")]
        [ValidateNotNullorEmpty()]
        [String]$FilePath,

        [Parameter(Mandatory=$true,
                      ValueFromPipelineByPropertyName=$true,
                       Position=1,
                       HelpMessage="File Path to MIDSInitDB.exe.config")]
        [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{1,3}")]
        [String]$BuildNumber

    )

    $ReleaseNumber = $BuildNumber.SubString(0,3)
    $OutputLogFile = "E:\Builds\OWBridge\$ReleaseNumber\DBSetup-Working\log\MIDSInitDB.config.log"
    [String]$datasource = 'PRB1MES2\ST'
    [String]$initial_catalog = 'Bridge_OWBridge'
    [String]$db_user = 'BridgeInitSQL'
    [String]$db_hash = 'E4B25624'

    Write-Output "-- Modifying $FilePath..." -Verbose

    #Read Each Line and Replace accordingly
    (Get-Content $FilePath) |
    ForEach-Object {$_ -replace "Data Source=(.*?);", "Data Source=$datasource;"} |
    ForEach-Object {$_ -replace "Initial Catalog=(.*?);", "Initial Catalog=$initial_catalog;"} |
    ForEach-Object {$_ -replace "User ID=(.*?);", "User ID=$db_user;"} |
    ForEach-Object {$_ -replace "Password=(.*?);", "Password=$db_hash;"} |
    Set-Content $FilePath

    Write-Output "-- $FilePath modified successfully! --" -Verbose

}

function Get-OWTfSVersionControlInstance
{
    <#
    .Synopsis
       Gets an Instance of TFS Version Control Server
    .DESCRIPTION
       Gets an Instance of TFS Version Control Server. Outputs Object of Type
       [Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer]
       This object can be used to download files from TFS
    .EXAMPLE
       Get-OWTfsVersionControlInstance -TFServerURL http://prg2tfa1:8080/tfs
    .Notes
       Author: Praveen Chamarthi
       Date: 24 Apr 2013
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer])]
    Param
    (

        # TFS URL
        [Parameter(Mandatory=$true,
                   Position=0,
                   HelpMessage="url to TFSServer e.g. http://prg2tfa1:8080/tfs")]
        [ValidateNotNullorEmpty()]
        [String]$TFServerURL
        
    )

    #Add PowerShell TeamFoundation Snapin
    if ((Get-PSSnapin -Name Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue) -eq $null ){

        Add-PSSnapin Microsoft.TeamFoundation.PowerShell
    }

    (Get-TfsServer -Name $TFServerURL).GetService('Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer')
    
}

function Get-OWLastBuildDate
{
    <#
    .Synopsis
       Get Last Successful Build DateTime
    .DESCRIPTION
       Get Last Successful Build DateTime from SCMDB
    .EXAMPLE
       Get-OWLastBuildDate -Product Genoa -Branch MAINLINE
    .EXAMPLE
       Get-OWLastBuildDate -Product OWBridge -Branch 2.0
    .NOTES
        Author: Praveen Chamarthi
        Date: 24 Apr 2013
    #>
    [CmdletBinding()]
    [OutputType([DateTime])]
    Param
    (
        # Product Number
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0,
                   HelpMessage="Name of Product as entered in SCMDB e.g. GENOA4SF")]
        [ValidateNotNullorEmpty()]
        [String]$Product,

        # Branch Name
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1,
                   HelpMessage="Name of Branch as entered in SCMDB e.g CHARTIS")]
        [ValidateNotNullorEmpty()]
        [String]$BranchName
        
    )

    Begin
    {
        $SqlServer = "192.168.0.34"
        $SqlCatalog = "SCMDB"
        $SqlQuery = "SELECT TOP 1 [DATETIME] FROM BUILDS WHERE PRODUCT = '$Product' AND BRANCH = '$Branch' AND STATUS = 'SUCCESS' ORDER BY DATETIME DESC"
    }
    Process
    {
        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $SqlConnection.ConnectionString = "Server=$SqlServer; Database=$SqlCatalog; Integrated Security = True"
        
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.CommandText = $SqlQuery
        $SqlCmd.Connection = $SqlConnection

        $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $SqlAdapter.SelectCommand = $SqlCmd
        
        $DataSet = New-Object System.Data.DataSet
        $SqlAdapter.Fill($DataSet) | Out-Null
        $SqlConnection.Close()
        #Clear
        $DataSet.Tables[0].DATETIME.ToString("yyyy-MM-dd hh:mm")
    }
    End
    {
    }
}

function Send-OWEmail
{
    <#
    .Synopsis
       Sends Email using Send-MailMessage CmdLet
    .DESCRIPTION
       Sends Email using Send-MailMessage CmdLet
    .EXAMPLE
       Send-OWEmail -FromAddress "TFS@Oceanwide.com" -ToAddress "ConfigurationManagement@myserver.com" -Subject "Testing cod mail" -Body "cod mail"
    #>
    [CmdletBinding()]
    Param
    (
        # FromAddress
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidatePattern("(.*?)\@(.*?)\.com")]
        [ValidateNotNullOrEmpty()]
        [String]$FromAddress,

        # ToAddress 
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidatePattern("(.*?)\@(.*?)\.com")]
        [ValidateNotNullOrEmpty()]
        [String]$ToAddress,

        # Subject 
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [ValidateNotNullOrEmpty()]
        [String]$Subject,
        
        # Body 
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=3)]
        [ValidateNotNullOrEmpty()]
        [String]$Body,

        #File to Attach (Full Path)
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=4)]
        [String]$FileToAttach


    )

    Begin
    {
        $strSMTP = "prexch1.myserver.com"
        $strFrom = "$FromAddress"
        $strTo = "$ToAddress"
        $strSub = "$Subject"
        $strBody = $Body
    }
    Process
    {
        

        $objEmail = New-Object -ComObject "CDO.Message"
        $objEmail.From = $strFrom
        $objEmail.To = $strTo
        $objEmail.Subject = $strSub
        $objEmail.HTMLbody = $strBody
        If(-Not [System.String]::IsNullOrEmpty($FileToAttach)){
            $objEmail.AddAttachment("$FileToAttach")
        }
        $objEmail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/sendusing") = 2
        $objEmail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpserver") = $strSMTP
        $objEmail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpserverport") = 25
        $objEmail.Configuration.Fields.Update()
        $objEmail.Send()

    }
    End
    {   
    }
}

function Find-OWBuildErrors
{
    <#
    .Synopsis
       Looks for any Errors in Logs
    .DESCRIPTION
       Searches all Log Files in given folders for any Errors
    .EXAMPLE
       Find-OWBuildErrors -LogDirectory E:\Builds\3.14\3.14.13.04\log -SendTo ConfigurationManagement@myserver.com
    #>
    [CmdletBinding()]
    Param
    (
        # Log Directory Path
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0,
                   HelpMessage="Path to Log Directory")]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [String]$LogDirectory,

        # SendTo Email address
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1,
                   HelpMessage="Full email address of Recepient(s). Pass as String Array if many")]
        [String]$SendTo="$CMEmailAddress"
    )

    Begin
    {
        
        #Find BuildNumber
        #$PathArray = (Split-Path $LogDirectory).Split("\")
        If($LogDirectory -match "\d\.\d\.\d\.\d{3}"){

            $BuildNumber = $Matches[0]

        }
        #Get all log files 
        $files = Get-ChildItem $LogDirectory -File    
        
    }
    Process
    {

        If($files.Count -gt 0){

            foreach($file in $files){

                #Read each log file and look for errors
                $errors = Get-Content $file.FullName | ? { $_ -match '(Error\s|skipping|failed)' -or $_ -match '(returned\sone\sor\smore\serrors|Invalid\scolumn)' }
                
                If($errors -match 'The command NET USE'){

                    $errors = ""
                }

                If(-Not [String]::IsNullOrEmpty($errors)){
                    Write "Scanning..." $file.FullName -Verbose
                    $strBody += @" 
                            
                            <div class="page-header">
                                <h3>File Name : <em> $file </em> </h3>
                            </div>
                            <p class="red">
                                "$errors"
                            </p> 
"@
                }
                
            }

        }else{
            
            Write-Warning "Find-OWBuildErrors: No Files in Output Directory $LogDirectory"
            Exit
        }

    }
    End
    {  
        If(-Not [String]::IsNullOrEmpty($strBody)){
            #Send Email with Errors
            $Subject = "$BuildNumber : Errors found in Build"
            $EmailBody = @"
                        <head>
                          <style type="text\css">
                            body {
                              margin: 0;
                              font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
                              font-size: 14px;
                              line-height: 20px;
                              color: #333333;
                              background-color: #ffffff;
                            }
                            p {
                              margin: 0 0 10px;
                            }
                            .page-header {
                              padding-bottom: 9px;
                              margin: 20px 0 30px;
                              border-bottom: 1px solid #eeeeee;
                            }
                            .red {
                                color: red;
                            }
                          </style>
                        </head>
                        <body>
                            <div class="page-header">
                                <h2>$BuildNumber : Errors in Build</h2>
                                <h3>Log Directory: <em>$LogDirectory</em></h3>
                            </div>
                            $strBody
                        </body>
"@
            Send-OWEmail -FromAddress "$FromAddress" -ToAddress "$SendTo" -Subject "$Subject" -Body "$EmailBody"
        }

    }
}

function Find-OWCombineErrors
{
    <#
    .Synopsis
       Scan CombineResults File for Errors
    .DESCRIPTION
       Scan CombineResults File passed in for Errors
    .EXAMPLE
       Find-OWCombineErrors -CREFilePath E:\Builds\OWBridge\2.2\2.2.0.52\db-Combine\2.2.0.52\2.2.0.52.AutoDeploy.RESULTS.cre
    .NOTES
        Author: Praveen Chamarthi
        Date: 06 June 2013
    #>
    [CmdletBinding()]
    [OutputType([DateTime])]
    Param
    (
        # Product Number
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0,
                   HelpMessage="Full Path to cre File to Scan")]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]$CREFilePath
        
    )

    $Errors = Get-Content $CREFilePath

    If($Errors -match 'HasErrors'){

        $Errors = "DBScripts Execution failed with Errors"

    }else{

        $Errors = ""
    }

    $Errors
}
