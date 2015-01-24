#
#    .Synopsis
#       Deploys Bridge APP (MIDSWeb & ComplianceScan) artifacts to Target Server
#    .DESCRIPTION
#       Deploys Bridge Core App artifacts (MIDSWeb & ComplianceScan) to Target Server
#    .EXAMPLE
#       Deploy-BridgeApp -Build 2.2.2.07 -Licensee OWBridge
#    .EXAMPLE
#       Deploy-BridgeApp -Build 2.2.2.07 -Licensee AON,ACE,UKDEMO,SALES
#    .EXAMPLE
#       Deploy-BridgeApp -Build 2.2.2.07 -Licensee "AIG","AIGEUROPE"
#    .INPUTS
#       Build - A Valid bridge build number
#       Licensees - Comma Separated list of licensees 
#                   Licensee name should exist in \\192.168.0.55\scripts\BridgeLicenseeNames.txt
#    .NOTES
#       Server Info is maintained in a csv file hosted under \\192.168.0.55\scripts\BridgeWebServers.csv
#    .FUNCTIONALITY
#       Deploys Bridge App - MIDSWeb, WCF_SERVICE to Target
#    
Param
    (
        #BridgeBuildNumber - e.g. 2.2.1.27
        [String]$Build,
        #Comma seperated Licensees names e.g. - OWBridge,AON,ACE
        [String[]]$Licensees
    )
    
    #Step 1: Get HostName and Validate Server Info from BridgeWebServers.csv
    #Step 2: Validate LicenseeName from BridgeLicensees.txt
    #Step 3: Validate Build Number from Repository
    #Step 4: If all the above are true then stop AppPool and copy files to 
        # a. E:\Bridge_WEBSITE_LIVE\<Licensee>\
        # b. E:\WCF_SERVICE
    . \\192.168.0.55\scripts\Deploy-OWFunctions.ps1
    if(-not $Build -or -not $Licensees){
        Write "*** Build Number & licensees are required parameters to this script ***"
        return
    }

    $LogFile = "D:\Logs\Scripts\Deploy-Bridge-$Build.log"
    $hostname = [System.Net.Dns]::GetHostName()
    $script_server_path = "\\192.168.0.55\scripts\"
    $build_repository = "\\192.168.0.31\Builds\OWBridge"
    $Bridge_WebRoot = "E:\Bridge_WEBSITE_LIVE\"
    $is_nagios = $false

    #Step 1: Get HostName and Validate Server Info from BridgeWebServers.csv
    $webservers = Import-csv \\192.168.0.55\scripts\BridgeWebServers.csv
    If($webservers -match "$host_name"){

            Write "-- Deploying to: Bridge " $server.Platform $server.Environment -Verbose
            if($server.Platform -eq "UAT"){
                $is_nagios = $true
            }
            $platform = $server.Platform
            $Environment = $server.Environment

    }else{
        
        Write "*** Cannot find Target Server: Check $script_server_path\BridgeWebServers.csv" -Verbose
        return
    }
    
    #Step 2: Validate Build Number from Repository & LicenseeName from BridgeLicensees.txt
    Write " -- Validating Licensees with $script_server_path\BridgeLicenseeNames.txt --" -Verbose

    $valid_licensees = @()
    foreach($licensee in $Licensees){
        
        $is_valid = $false
        foreach($licshort in $licensee_names){
            
            if($licshort.LicenseeShort -contains $licensee){
                $is_valid = $true
                break
            }

        }
        if($is_valid){

            $valid_licensees += $licensee

        }else{

            Write "-xx- $licensee is NOT Valid" -Verbose

        }

    }
    if($valid_licensees.Count -eq 0){

        Write "No Valid Licensees in the list - Check again!" -Verbose
        return
    }

    Write "Valid Licensees: $valid_licensees" -Verbose
    
    #Step3: Validate build number & paths
    if($Build -match "(\d\.\d{1,2})(\.\d{1,2})\.\d{2,3}" ){
        
        $release_num = $Matches[1]
        $Build_DirRoot = "$build_path\$release_num\$Build"
        $MIDSWeb_DirRoot = "$Build_DirRoot\app\MIDSWeb"
        $WCF_DirRoot = "$build_path\$release_num\$Build\app\WCF_Service"

        if(-not (Test-Path $MIDSWeb_DirRoot -PathType Container)){
            Write "*** $MIDSWeb_DirRoot Not found in $build_repository  ***" -Verbose
            return
        }
        if(-not (Test-Path $WCF_DirRoot -PathType Container)){
            Write "*** $WCF_DirRoot Not found in $build_repository  ***" -Verbose
            return
        }

    }

    #Step4: Stop AppPool, Disable Nagios & Deploy (copy files)
    foreach($lic in $valid_licensees){

        $BridgeAppPool = "Bridge_$lic_AppPool"

        Stop-AppPool "$BridgeAppPool"

        if($is_nagios){

            $NagiosAlertName = "HTTP_Check_Bridge_$Platform_$Environment"
            Write "** Disabling Nagios Alert $NagiosAlertName" -Verbose
            Disable-OWNagiosAlerts -Name $NagiosAlertName

        }

        #Clean Bin first
        Write "Deleting $Bridge_WebRoot\$lic\bin dir contents.."
        Remove-Item -Path "$Bridge_WebRoot\$lic\bin\**" -Recurse
        #Copy files from build_repository
        robocopy $MIDSWeb_DirRoot "$Bridge_WebRoot\$lic" /E /LOG+:$LogFile /NP /NJS
        robocopy $Build_DirRoot "$Bridge_WebRoot\$lic" BuildInfo.txt /LOG+:$LogFile /NP /NJS

        Start-AppPool "$BridgeAppPool"

        if($is_nagios){
            
            Write "** Enabling Nagios Alert $NagiosAlertName" -Verbose
            Enable-OWNagiosAlerts -Name $NagiosAlertName

        }

    }

    #Step5: Deploy WCF_Service
