#
#    .Synopsis
#       Deploys Bridge CognosAutomation artifacts to Target Server
#    .DESCRIPTION
#       Deploys Bridge CognosAutomation artifacts from folder E:\Builds\BusinessIntelligence\1.0 on Bridge Build Machine
#       DLL's will then be copied to CognosAutomation
#       Exclude *.pdb and *.config
#    .EXAMPLE
#       Deploy-BridgeCognosAutomation -Build 1.0.0.03
#    .INPUTS
#       Build (required) - A valid bridge build number on build server
#    .NOTES
#       Server Info is maintained in a csv file hosted under \\PROPU2\scripts\Bridge_CognosAutomationServers.csv
#       Scripts validates the server with this file
#    .FUNCTIONALITY
#       Deploys Bridge CognosAutomation - dll's (excluding the exe)
#   
Param
(
    #BIServices BuildNumber - e.g. 2.2.1.27
    [String]$Build = $(throw "Must provide an Build number")

)

    $script_server_path = "\\PROPU2\scripts\"
    $ca_serverconfig = "$script_server_path\Bridge_CognosAutomationServers.csv"
    $build_path = "\\PRB1DPA1\Builds\BusinessIntelligence"
    $hostname = [System.Net.Dns]::GetHostName()
    $log_dir = "D:\Logs\scripts"
    $datetime = (Get-Date -Format "yyyyMMdd_hhmmss")
    $OutputLogFile = "$log_dir\Deploy-BridgeCognosAutomation-$Build_$datetime.log"

    #Validate Build Number
    if($Build -match "(\d\.\d{1,2})(\.\d{1,2})\.\d{1,3}" ){
        
        $release_num = $Matches[1]
        $builddir_root = "$build_path\$release_num\$Build"
        $ca_builddir = "$builddir_root\app"
        if(-not (Test-Path $ca_builddir -PathType Container)){
            Write "*** Cannot find $ca_builddir in $Build"
            return
        }

    }

    #Step 1: Validate Server Info & Get ServerName from Bridge_CognosJQServers.csv
    $CA_servers = Import-Csv -Path "$ca_serverconfig"

    Write "-- Validating Server with $ca_serverconfig --" | Tee-Object $OutputLogFile -Append

    if(-not ($CA_servers -match $hostname)){
        
        Write "*** Cannot find Target Server: Check $ca_serverconfig" | Tee-Object $OutputLogFile -Append
        return

    }else{

        foreach($env in $CA_servers){ 

            if(($env."CA_HOST" -eq "$hostname")) { 
                $destroot_dir = $env."CA_ROOT"
                break
            }

        }
        if(-not $destroot_dir){

            Write "*** Cannot find Destination CA Root Dir in $ca_serverconfig : $Environment, $Platform" | Tee-Object $OutputLogFile -Append
            return
        }

    }
    
    #Copy DLL's
    Write "--- Deploying latest CognosAutomation DLL's from $destroot_dir" | Tee-Object $OutputLogFile -Append
    robocopy $ca_builddir $destroot_dir /XF *.pdb *.config /E /NP >> $OutputLogFile

 
    Write "--- Deploy of BridgeCognosJQ Complete ---" | Tee-Object $OutputLogFile -Append
