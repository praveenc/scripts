Param 
(
    <#
    .SYNOPSIS
          Deploys Billing WebApp artifacts to Target Server
    .DESCRIPTION
          Deploys Billing WebApp + WebServices to Target Server
    .EXAMPLE
          Deploy-BillingWebApp -BuildNumber 2.2.2.07 -Licensees OWBridge
          \\192.168.0.55\scripts\Deploy-BillingWebApp.ps1 -BuildNumber 2.2.3.84 -Licensee OWCognos
    .EXAMPLE
          Deploy-BillingWebApp -BuildNumber 2.2.2.07 -Licensees AON,ACE,UKDEMO,SALES
    .EXAMPLE
          Deploy-BillingWebApp -BuildNumber 2.2.2.07 -Licensees "AIG","AIGEUROPE" 
    .INPUTS
          Build - A Valid bridge build number
          Licensees - Comma Separated list of licensees 
                      Licensee name should exist in \\192.168.0.55\scripts\Bridge_LicenseeNames.csv
    .NOTES
          Server Info is maintained in a csv file hosted under \\192.168.0.55\scripts\Bridge_WebServers.csv
    .FUNCTIONALITY
          Stop Billing AppPools, Back up ACL & Web.config, Disable Nagios Alerts
          Robocopy (MIR /IS) WebApp folder from Build directory to Target Dir
          Restore ACL, Enable Nagios Alerts, Start Billing AppPool
          Do Sanity Test, Update Insurance Index
    #>

    [CmdletBinding()]
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Build Number")]
    [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{2,3}")]
    [String]$BuildNumber,

    #Comma seperated Licensees names e.g. - OWBridge,AON,ACE
    [Parameter(Mandatory=$true, Position=1, HelpMessage="Comma Separated Licensees")]
    [ValidateNotNullOrEmpty()]
    [String[]]$Licensees
    
)
    #Step 1: Validations
    #   Validate Server Info & Get ServerName from Bridge_WebServers.csv
    #   Validate LicenseeName from Bridge_LicenseeNames.csv
    #   Validate if Build folder exists in Build Repository
    #   Verify to see if IIS-OWLib.ps1 and OW-CMTools.ps1 exists in Scripts Repository
    #Step 4: If all the above are true then copy files to Target Dir

    #$WorkingDir = (Get-Location -PSProvider FileSystem).ProviderPath
    #[Environment]::CurrentDirectory=$WorkingDir

    $script_server_path = "\\PROPU2\scripts"
    $hostname = [System.Net.Dns]::GetHostName()
    $logged_user = Get-Content env:username
    $web_servers = Import-Csv -Path "$script_server_path\Bridge_WebServers.csv"
    $log_dir = "D:\Logs\scripts"
    $datetime = (Get-Date -Format "yyyyMMdd_HHmmss")

    if(Test-Path -Path "$script_server_path\IIS-OWLib.ps1" -PathType Leaf){
        Write "--- Loading IIS-OWLib.ps1 to current scope ..." -Verbose
        . $script_server_path\IIS-OWLib.ps1
    }else{
        Write "*** ERROR: Cannot find IIS-OWLib.ps1 in $script_server_path ***" -Verbose
        exit
    }

    #Check if Log dir exists
    if(Test-Path $log_dir){

        $OutputLogFile = "$log_dir\Deploy-BillingWebApp-$Build_$datetime.log"

    }else{

        $Error.Clear()
        Write "--- Cannot find $log_dir .. creating one ... " -Verbose
        mkdir $log_dir | Out-Null
        
        if($Error){

            Write "*** ERROR : Creating $log_dir ..." -Verbose
            $Error
            exit
        }

    }

    $release_num = $BuildNumber.SubString(0,3)
    $build_path = "\\PRB1DPA1\Builds\Billing"
    $builddir_root = "$build_path\$release_num\$BuildNumber"
    $build_approot = [IO.Path]::Combine($builddir_root,"WebApp")
    $WebServices_Files = Get-ChildItem -Path "$build_approot\WebServices" -Recurse -Filter "*.svc" -File | Select FullName
    $robocopy_exclude_files = "web*.config"
    
        
    #Step 1: Validate Server Info & Get ServerName from Bridge_WebServers.csv
    Write "-- Validating Server with $script_server_path\Bridge_WebServers.csv @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append

    if(-not ($web_servers -match $hostname)){
        
        Write "*** Cannot find Target Server: Check $script_server_path\Bridge_WebServers.csv" | Tee-Object $OutputLogFile -Append
        exit

    }else{

        foreach($env in $web_servers){ 

            if(($env."BRIDGEWSHOST" -eq "$hostname")) {
                $Environment = $env."ENVIRONMENT"
                $Platform = $env."PLATFORM"
                $destroot_dir = "E:\BRIDGE_WEBSITE_LIVE"
                break
            }

        }

    }
    #Step 2: Validate LicenseeName from BridgeLicensees.txt
    Write "-- Validating Licensees with $script_server_path\Bridge_LicenseeNames.csv @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append

    $valid_licensees = @()
    $licensee_names = Import-Csv -Path "$script_server_path\Bridge_LicenseeNames.csv"

    foreach($licensee in $Licensees){
        
        $is_valid = $false
        foreach($licshort in $licensee_names){
            
            if($licshort.LicenseeShort -contains $licensee){
                $is_valid = $true
                break
            }

        }
        if($is_valid){
            #Write "$licensee is Valid"
            $valid_licensees += $licensee

        }else{

            Write "-xx- $licensee is NOT Valid" | Tee-Object $OutputLogFile -Append

        }

    }

    if($valid_licensees.Count -eq 0){

        Write "*** No Valid Licensees in the list - Check again!" | Tee-Object $OutputLogFile -Append
        exit

    }

    Write "-- Valid Licensees: $valid_licensees" | Tee-Object $OutputLogFile -Append
    Write "-- Deploying BillingWebApp - script trigged by $logged_user on $hostname @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append        
    
    foreach($licensee in $valid_licensees){

        Write "   ######################################################   " | Tee-Object $OutputLogFile -Append
        Write "--- Deploying Billing WebApp for Licensee $licensee @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append
        $target_dir = [IO.Path]::Combine($destroot_dir,$licensee,"Billing")
        $apppool_name = "Bridge_" + $licensee + "_AppPool"

        if(-not (Test-Path $target_dir)){
            Write "*** ERROR: Billing not installed for Licensee: $licensee; No Target Dir found: $target_dir" --Verbose
            exit
        }

        #Backup ACL
        Write "--- Backing up ACL on $target_dir ... @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append
        $billing_acl = Get-Acl -Path $target_dir

        #Backup Web.config
        Write "--- Backing up Billing Web.config ... @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append
        $filname = [IO.Path]::Combine($target_dir,"Web.config")
        $tmp_filename = $filname + "_" + $datetime
        (Get-Content $filname ) | Set-Content "$tmp_filename"

        #Stop AppPools
        Write "--- Stopping AppPool $apppool_name ... @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append
        Stop-WebAppPool -Name $apppool_name -ErrorVariable Err_Stop_AppPool
        if($Err_Stop_AppPool.Count -gt 0){
            Write "### ERROR: Error Occurred while Stopping AppPool: $Err_Stop_AppPool " | Tee-Object $OutputLogFile -Append
        }

        #Mirror WebApp Directory from Build
        Write-Progress -Activity "Deploying Build: $BuildNumber to Licensee: $licensee" `
                  -CurrentOperation "Copying WebApp from $build_approot to $target_dir ... " -Status "This may take a while ..."
        Write "--- Copying WebApp from $build_approot to $target_dir ... @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append
        $robocopy_progress = robocopy $build_approot $target_dir /E /IS /XF $robocopy_exclude_files /XD "WebServices" /NP
        Write "--- Copying WebServices from $build_approot\WebServices ..." | Tee-Object $OutputLogFile -Append
        $robocopy_progress += $WebServices_Files | ForEach-Object { Copy-Item $_.FullName -Destination "$target_dir\WebServices" -Verbose }
        $robocopy_progress | Tee-Object $OutputLogFile -Append

        Write-Progress -Activity "Deploying Build: $BuildNumber to Licensee: $licensee" -Completed -Status "All done."
        #Set ACL back on the folder after Deploying
        Write "--- Applying ACLs back on $target_dir ... @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append
        Set-Acl -Path $target_dir -AclObject $billing_acl

        #Start AppPools
        Write "--- Starting AppPool $apppool_name ... @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append
        Start-WebAppPool -Name $apppool_name -ErrorVariable Err_Start_AppPool
        if($Err_Start_AppPool.Count -gt 0){
            Write "### ERROR: Error Occurred while Starting AppPool: $Err_Start_AppPool " | Tee-Object $OutputLogFile -Append
        }

        #Update Insurance Index
        $Environment = $Environment.Trim()
        $Platform = $Platform.Trim()
        $TagToUpdate ="$Environment $Platform"
        Write-Progress -Activity "Deploying Build: $BuildNumber to Licensee: $licensee" `
                  -CurrentOperation "Updating Insurance Index ... " -Status "Performing final step ..."
        Write "--- Updating Insurance Index for tag: $TagToUpdate ... @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append
        #Update-OWInsuranceIndex -IndexPageName "Bridgesiteindex.htm" -TagToUpdate "$TagToUpdate" -Licensee "$Licensee" -BuildNumber "$BuildNumber" | 
        #    Tee-Object $OutputLogFile -Append

    }

    Write "--- Deployment Complete - End of Script ... @ $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Tee-Object $OutputLogFile -Append
