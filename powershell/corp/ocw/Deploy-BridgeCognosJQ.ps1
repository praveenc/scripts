Param
(
    <#
        .Synopsis
           Deploys Bridge CognosJQ artifacts to Target Server
        .DESCRIPTION
           Deploys Bridge CognosJQ artifacts from JobQueue folder in Bridge Build directory
           All CognosJQ Services will be stopped first.
           DLL's will then be copied to CognosJQDirectory
           Start Services again    
        .EXAMPLE
           Deploy-BridgeCognosJobQueue -Build 2.2.2.04
        .INPUTS
           Build (required) - A valid bridge build number on build server
        .NOTES
           Server Info is maintained in a csv file hosted under \\PROPU2\scripts\Bridge_CognosJQServers.csv
        .FUNCTIONALITY
           Deploys Bridge CognosJQ - dll's (excluding the exe)
        .NOTES
            Author: Praveen Chamarthi
            Modified Date: 22 Jan 2014
    #>   

    [CmdletBinding()]
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Build Number")]
    [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{2,3}")]
    [String]$BuildNumber

)

    $script_server_path = "\\PROPU2\scripts\"
    $cgjq_serverinfo = "$script_server_path\Bridge_CognosJQServers.csv"
    $build_path = "\\PRB1DPA1\Builds\OWBridge"
    $hostname = [System.Net.Dns]::GetHostName()
    $logged_user = Get-Content env:username
    $log_dir = "D:\Logs\scripts"
    if(Test-Path $log_dir){
        
        $datetime = (Get-Date -Format "yyyyMMdd_hhmmss")
        $OutputLogFile = "$log_dir\Deploy-BridgeCognosJobQueue-$Build_$datetime.log"

    }else{
        $Error.Clear()
        Write "--- Cannot find $log_dir .. creating one ... " -Verbose
        mkdir $log_dir | Out-Null
        
        if($Error){

            Write "*** ERROR : Creating $log_dir ..." -Verbose
            $Error
            return
        }

    }

    $cognosJQServices = @("OwJobConcentrator_Cognos_Bridge_",
                          "OwJobMonitor_Cognos_Bridge_",
                          "OwJobScheduler_Cognos_Bridge_")

    $BridgeJQServices = @("OwJobConcentrator_Bridge_",
                          "OwJobMonitor_Bridge_",
                          "OwJobScheduler_Bridge_")

    #Validate Build Number
    if($BuildNumber -match "(\d\.\d{1,2})(\.\d{1,2})\.\d{1,3}" ){
        
        $release_num = $Matches[1]
        $builddir_root = "$build_path\$release_num\$BuildNumber"
        $jqbuilddir = "$builddir_root\JobQueue"
        if(-not (Test-Path $jqbuilddir -PathType Container)){
            Write "*** ERROR: Cannot find $jqbuilddir in $Build" | Tee-Object $OutputLogFile -Append
            exit
        }

    }
    

    #Step 1: Validate Server Info & Get ServerName from Bridge_CognosJQServers.csv
    $cognosJQ_servers = Import-Csv -Path "$cgjq_serverinfo"
    
    Write "-- Validating Server with $cgjq_serverinfo --" | Tee-Object $OutputLogFile -Append
    
    if($cognosJQ_servers -notmatch $hostname){
        
        Write "*** ERROR: Cannot find Target Server: Check $cgjq_serverinfo" | Tee-Object $OutputLogFile -Append
        exit

    }else{

        foreach($env in $cognosJQ_servers){ 

            if(($env."JQ_HOSTNAME" -eq "$hostname")) { 
                $CognosJQDirectory = $env."COGNOSJQ_ROOT"
                $BridgeJQDirectory = $env."BRIDGEJQ_ROOT"
                $jq_suffix = $env."ENVIRONMENT" + "_" + $env."PLATFORM"
                break
            }

        }
        if((-not $CognosJQDirectory) -or (-not $BridgeJQDirectory)){

            Write "*** ERROR: Cannot find Either BridgeJQ OR CognosJQ Destination Dir in $cgjq_serverinfo : $Environment, $Platform" | Tee-Object $OutputLogFile -Append
            exit
        }

    }

    #Stop JQ Services
    Write "--- Stopping CognosJQ Services ---" -Verbose
    foreach($jqservice in $cognosJQServices){
        #Stop each service
        $jqservice_displayname = "$jqservice" + "$jq_suffix"
        Write "--- Stopping service $jqservice_displayname" | Tee-Object $OutputLogFile -Append
        Stop-Service -Name "$jqservice_displayname" -ErrorVariable DeployErr
    }
    if($DeployErr.Count -gt 0){

        Write "### ERROR: occured while Stopping Cognos JQ Services... `r`n $DeployErr " | Tee-Object $OutputLogFile -Append
        exit
    }

    #Stop Bridge JQ Services
    Write "--- Stopping BridgeJQ Services ---" -Verbose
    foreach($jqservice in $BridgeJQServices){
        #Stop each service
        $jqservice_displayname = "$jqservice" + "$jq_suffix" + "_LIVE"
        Write "--- Stopping service $jqservice_displayname" | Tee-Object $OutputLogFile -Append
        Stop-Service -Name "$jqservice_displayname" -ErrorVariable BridgeDeployErr
    }
    if($BridgeDeployErr.Count -gt 0){

        Write "### ERROR: occured while Stopping Bridge JQ Services... `r`n $BridgeDeployErr " | Tee-Object $OutputLogFile -Append
        exit
    }
    #Copy DLL's and RoutingConfig
    Write "--- Deploying latest JobQueue DLL's to $CognosJQDirectory" | Tee-Object $OutputLogFile -Append
    robocopy $jqbuilddir $CognosJQDirectory *.dll /IS /NP /NDL >> $OutputLogFile

    Write "--- Deploying latest RoutingConfig to $CognosJQDirectory" | Tee-Object $OutputLogFile -Append
    robocopy "$jqbuilddir\RoutingConfig\CognosJQ" $CognosJQDirectory *.xml /IS /NP /NDL >> $OutputLogFile

    Write "--- Deploying latest JobQueue DLL's to $BridgeJQDirectory" | Tee-Object $OutputLogFile -Append
    robocopy $jqbuilddir $BridgeJQDirectory *.dll /IS /NP /NDL >> $OutputLogFile

    Write "--- Deploying latest RoutingConfig to $BridgeJQDirectory" | Tee-Object $OutputLogFile -Append
    robocopy "$jqbuilddir\RoutingConfig\BridgeJQ" $BridgeJQDirectory *.xml /IS /NP /NDL >> $OutputLogFile

    #Start Cognos JQ Services
    Write "--- Starting CognosJQ Services ---" -Verbose
    foreach($jqservice in $cognosJQServices){
        #Stop each service
        $jqservice_displayname = "$jqservice" + "$jq_suffix"
        Write "--- Starting service $jqservice_displayname" | Tee-Object $OutputLogFile -Append
        Start-Service -Name "$jqservice_displayname" -ErrorVariable DeployErr

    }
    if($DeployErr.Count -gt 0){

        Write "### ERROR: occured while Starting Services... `r`n $DeployErr " | Tee-Object $OutputLogFile -Append
        exit
    }

    #Start Bridge JQ Services
    Write "--- Starting Bridge JQ Services ---" -Verbose
    foreach($jqservice in $BridgeJQServices){
        #Stop each service
        $jqservice_displayname = "$jqservice" + "$jq_suffix" + "_LIVE"
        Write "--- Starting service $jqservice_displayname" | Tee-Object $OutputLogFile -Append
        Start-Service -Name "$jqservice_displayname" -ErrorVariable BridgeDeployErr

    }
    if($BridgeDeployErr.Count -gt 0){

        Write "### ERROR: occured while Starting Services... `r`n $BridgeDeployErr " | Tee-Object $OutputLogFile -Append
        exit
    }

    if(($BridgeDeployErr.Count -eq 0) -and ($DeployErr.Count -eq 0)){

        Write "--- Deploy of BridgeCognosJQ Complete ---" | Tee-Object $OutputLogFile -Append

    }
    
