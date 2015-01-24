<#
    .SYNOPSIS
        Utility Functions for IIS
    .DESCRIPTION
        Commonly used IIS functions for Deploying Web Applications if WebServer is IIS6.0 or below
        For IIS 7.0 and above use Powershell WebAdministration Module for IIS functions
    .EXAMPLE
        . .\IIS-OWLib.ps1
        Stop-IISAppPool -AppPoolName "Bridge_OWBridge_AppPool"
        Disable-NagiosAlert -AlertName "HTTP_Check_Bridge_Beta_UAT"
    .NOTES
        Author: Praveen Chamarthi
        Create Date: 03 Feb 2014
#>

#Find OS Architecture
$os_arch = (Get-WMIObject -Class Win32_OperatingSystem).OSArchitecture

#Set appcmd Path based on Architecture
if($os_arch -match "64"){
    
    $appcmdexepath = $env:windir + "\System32\inetsrv\appcmd.exe"

}elseif ($os_arch -match "32") {
    
    $appcmdexepath = $env:windir + "\SysWOW64\inetsrv\appcmd.exe"

}

#Nagios Variables
$CurlExePath = "D:\utilities\curl.exe"
$NagiosURL="http://itmon.myserver.com/nagios/cgi-bin/cmd.cgi"
$NagiosStatusURL="http://itmon.myserver.com/nagios/cgi-bin/status.cgi"
$NagiosUserID="builduser"
$NagiosPW="pass1word"

#Add WebAdministration Snapin - Required for Some Functions
if ((Get-PSSnapin -Name WebAdministration -ErrorAction SilentlyContinue) -eq $null ){
    Write-Output "### Loading WebAdministration PS Snapin.." -Verbose
    Add-PSSnapin WebAdministration

}


function Stop-OWIISAppPool
{
    <#
    .Synopsis
       Stops IIS AppPool
    .DESCRIPTION
       Stops requested IIS AppPools name
    .EXAMPLE
       Stop-IISAppPool -AppPoolName "Bridge_OWBridge_AppPool"
    .NOTES
        Author: Praveen Chamarthi
        Create Date: 03 Feb 2014
    #>
    [CmdletBinding()]
    Param
    (
        #Param1 help description
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [String]$AppPoolName

    )
    Process{

        if (Test-Path $appcmdexepath) {
            
            $arg1 = "Stop"
            $arg2 = "apppool"
            $arg3 = "/apppool.name:$AppPoolName"

            Write-Output "--- Stopping App Pool: $AppPoolName" -Verbose
            $status = & $appcmdexepath $arg1 $arg2 $arg3

            Write-Output "--- Waiting 2s ..." -Verbose
            Start-Sleep -Seconds 2
            
            Write-Output "--- Status: $status" -Verbose

        }   
        else {

            Write-Output "*** ERROR: Stop-IISAppPool: $appcmdexepath NOT FOUND" -Verbose
            return

        }
    }

}

function Start-OWIISAppPool
{
    <#
    .Synopsis
       Stops IIS AppPool
    .DESCRIPTION
       Stops requested IIS AppPools name
    .EXAMPLE
       Start-IISAppPool -AppPoolName "Bridge_OWBridge_AppPool"
    .NOTES
        Author: Praveen Chamarthi
        Create Date: 03 Feb 2014

    #>
    [CmdletBinding()]
    Param
    (
        #Param1 help description
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [String]$AppPoolName

    )
    Process{

        if (Test-Path $appcmdexepath) {
            
            $arg1 = "Start"
            $arg2 = "apppool"
            $arg3 = "/apppool.name:$AppPoolName"

            Write-Output "--- Starting App Pool: $AppPoolName" -Verbose
            $status = & $appcmdexepath $arg1 $arg2 $arg3

            Write-Output "--- Waiting 3s ..." -Verbose
            Start-Sleep -Seconds 3
            
            Write-Output "--- Status: $status" -Verbose

        }   
        else {

            Write-Output "*** ERROR: Start-IISAppPool: $appcmdexepath NOT FOUND" -Verbose
            return

        }
    }

}

function Disable-OWNagiosAlert
{

    <#
    .Synopsis
        Disables a Nagios Alert for monitoring
    .DESCRIPTION
        Before an UAT Deployments - Nagios Alerts for that Licensee has to be disabled so that it wouldn't page ops team.
    .EXAMPLE
        Disable-NagiosAlert -AlertName "HTTP_Check_Bridge_Beta_UAT"
    .NOTES
        Author: Praveen Chamarthi
        Create Date: 03 Feb 2014

    #>
    [CmdletBinding()]
    Param
    (
        #Param1 help description
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [String]$AlertName

    )
    Begin{

        if(-not (Test-Path $CurlExePath))
        {
            Write-Output "*** ERROR: Cannot find curl.exe here $CurlExePath " -Verbose
            return
        }
        #Set Nagios Arguments
        $arg1 = "-d"
        $arg2 = "cmd_typ=29&cmd_mod=2&host=$AlertName&btnSubmit=Commit"
        $arg3 =  $NagiosURL
        $arg4 = "-u" 
        $arg5 = $NagiosUserID + ":" + $NagiosPW
    }
    Process{
        
        Write-Output "--- Disabling Nagios Alerts for $AlertName" -Verbose
        
        & $CurlExePath $arg1 $arg2 $arg3 $arg4 $arg5
        Write-Output "--- Waiting 20s..." -Verbose
        Start-Sleep -s 20

        Write-Output "--- Nagios Alert: $AlertName disabled" -Verbose

        #$arg2 = "host=$alertname"
        #$arg3 = $NagiosStatusURL

        #Write-Output "--- Querying Nagios Alerts Status" -Verbose
        #& $CurlExePath $arg1 $arg2 $arg3 $arg4 $arg5
    }

}

function Enable-OWNagiosAlert
{

    <#
    .Synopsis
        Enables Nagios Alert for monitoring
    .DESCRIPTION
        Before an UAT Deployments - Nagios Alerts for that Licensee has to be disabled so that it wouldn't page ops team.
        This function will turn back on the Disabled Alert
    .EXAMPLE
        Enable-NagiosAlert -AlertName "HTTP_Check_Bridge_Beta_UAT"
    .NOTES
        Author: Praveen Chamarthi
        Create Date: 03 Feb 2014

    #>
    [CmdletBinding()]
    Param
    (

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [String]$AlertName

    )
    Begin{

        if(-not (Test-Path $CurlExePath))
        {
            Write-Output "*** ERROR: Cannot find curl.exe here $CurlExePath " -Verbose
            return
        }
        #Set Nagios Arguments
        $arg1 = "-d"
        $arg2 = "cmd_typ=28&cmd_mod=2&host=$AlertName&btnSubmit=Commit"
        $arg3 =  $NagiosURL
        $arg4 = "-u" 
        $arg5 = $NagiosUserID + ":" + $NagiosPW
    }
    Process{
        
        Write-Output "--- Enabling Nagios Alerts for $AlertName" -Verbose
        
        & $CurlExePath $arg1 $arg2 $arg3 $arg4 $arg5
        Write-Output "--- Waiting 20s..." -Verbose
        Start-Sleep -s 20

        Write-Output "--- Nagios Alert: $AlertName enabled" -Verbose

        #$arg2 = "host=$alertname"
        #$arg3 = $NagiosStatusURL

        #Write-Output "--- Querying Nagios Alerts Status" -Verbose
        #& $CurlExePath $arg1 $arg2 $arg3 $arg4 $arg5
    }

}

function Update-OWInsuranceIndex
{
    <#
    .SYNOPSIS
        Updates InsuranceIndex Page with BuildNumber
    .DESCRIPTION
        Scans through each line and matches the regular expression and replaces Old Build Number with the new one.
    .EXAMPLE
        Update-OWInsuranceIndex -IndexPageName "Bridgesiteindex.htm" -TagToUpdate "ALPHA QA" -Licensee "OWBilling" -BuildNumber 2.3.0.291
    .NOTES
        Author: Praveen Chamarthi
        Create Date: 03 Feb 2014
    #>
    [CmdletBinding()]
    Param(

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [ValidateNotNullorEmpty()]
        [String]$IndexPageName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=1)]
        [ValidateNotNullorEmpty()]
        [String]$TagToUpdate,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=2)]
        [ValidateNotNullorEmpty()]
        [String]$Licensee,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=3)]
        [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{1,3}")]
        [String]$BuildNumber

    )
    Begin{

        $datetime = (Get-Date -Format "yyyyMMdd_HHmmss")
        $index_wwwroot = "\\PROPU2\InsuranceIndex"
        $filname = [IO.Path]::Combine("$index_wwwroot","$IndexPageName")
        $tmp_filename =  "$filname_tmp_$datetime"
        $Licensee = $Licensee.ToUpper()

    }
    Process{

        #Backup Existing file before modifying
        (Get-Content $filname) | Set-Content $tmp_filename

        $regexp_pattern = "<td(.*?)$Licensee(.*?)$TagToUpdate(.*?)(\d\.\d{1,2}\.\d\.\d{2,3})(.*?)$"

        #Read each line and if line matches the RegExp Replace with Build Number
        (Get-Content $filname) | 
                ForEach-Object 
                {
                    If($_ -match "$regexp_pattern"){

                        $first_m = $Matches[1]
                        $second_m = $Matches[2]
                        $third_m = $Matches[3]
                        $fifth_m = $Matches[5] #Match 4 is the BuildNumber

                        $line = "<td$first_m$Licensee$second_m$third_m$BuildNumber$fifth_m"
                        Write-Output "--- Replacing BuildNumber with $BuildNumber..." -Verbose
                        $_ -replace "$regexp_pattern","$line"

                    }else{
                        
                        $_
                    }
                } | Set-Content $filname
    }
    End { 
        Write-Output "--- $IndexPageName updated for Licensee: $Licensee with BuildNumber: $BuildNumber" -Verbose
    }

}

function Query-OWBridgeSite{
    <#
    .SYNOPSIS
        Does WebRequest and Get's back HTTP Response code
    .DESCRIPTION
        Makes and HTTP Request to any bridge site; Logs in using default creds and gets a response back
    .EXAMPLE
        Query-OWBridgeSite -SiteUrl "https://owbridge.beta.live.qa.myserverbridge.com/"
    .NOTES
        Author: Praveen Chamarthi
        Create Date: 04 Feb 2014
    #>
    [CmdletBinding()]
    Param(

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [String]$SiteUrl
    )
    
    $base_uri = $SiteUrl
    Write "--- Querying Site : $base_uri" -Verbose
    $r = Invoke-WebRequest $base_uri -SessionVariable fmk
    if($fmk.Cookies.Count -gt 0){
        $form = $r.Forms[0]
        $form.Fields["ctl00_ctl00_ScreenContentPlaceHolder_rootCPH_Username_Dynamic_NestedControl_TextBox"] = "bridge@myserver.com"
        $form.Fields["ctl00_ctl00_ScreenContentPlaceHolder_rootCPH_Password_Dynamic_NestedControl_TextBox"] = "p455w3rd"
        Write "--- Logging in with default Bridge Creds" -Verbose
        $r = Invoke-WebRequest -Uri ("$base_uri" + $form.Action) -WebSession $fmk -Method POST -Body $form.Fields
        
        Write "HTML Response Code: " $r.StatusCode -Verbose
        Write "Description: " $r.StatusDescription -Verbose

    }

}
