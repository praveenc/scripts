Param 
(
    <#
    .SYNOPSIS
          Deploys Bridge Cognos artifacts to Target Server
    .DESCRIPTION
          Deploys Bridge Cognos artifacts - Core Model, Core Reports to Target Server
    .EXAMPLE
          Deploy-BridgeCognos -Build 2.2.2.07 -Licensee OWBridge
          \\192.168.0.55\scripts\Deploy-BridgeCognos.ps1 -Build 2.2.3.84 -Licensee OWCognos
    .EXAMPLE
          Deploy-BridgeCognos -Build 2.2.2.07 -Licensee AON,ACE,UKDEMO,SALES
    .EXAMPLE
          Deploy-BridgeCognos -Build 2.2.2.07 -Licensee "AIG","AIGEUROPE" 
    .INPUTS
          Build - A Valid bridge build number
          Licensees - Comma Separated list of licensees 
                      Licensee name should exist in \\192.168.0.55\scripts\BridgeLicenseeNames.txt
    .NOTES
          Server Info is maintained in a csv file hosted under \\192.168.0.55\scripts\BridgeCognosServers.txt
    .FUNCTIONALITY
          Deploys Bridge Cognos - Core Model/Reports & DW Destination Scripts to a specified env.
          for CoreModel - RoboCopies xml files to E:\CognosWebService\CognosAutomation\Licensees\<Licensee>\CoreModel
          for CoreReports - RoboCopies xml files to E:\CognosWebService\CognosAutomation\Licensees\<Licensee>\Reports
          DW Scripts to E:\CognosWebService\CognosAutomation\Licensees\<Licensee>\DWSchema
    #>

    [CmdletBinding()]
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Build Number")]
    [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{2,3}")]
    [String]$BuildNumber,

    #Comma seperated Licensees names e.g. - OWBridge,AON,ACE
    [Parameter(Mandatory=$true, Position=1, HelpMessage="Comma Separated Licensees")]
    [ValidateNotNullOrEmpty()]
    [String[]]$Licensees,

    [Parameter(Mandatory=$false, Position=2, ValueFromPipelineByPropertyName=$true)]
    [Switch]$DeployFullPackage
    
)
    #Step 1: Validate Server Info & Get ServerName from BridgeCognosServers.txt
    #Step 2: Validate LicenseeName from BridgeLicensees.txt
    #Step 3: Validate Build Number and see if Cognos Artifacts exists in that Build
    #Step 4: If all the above are true then copy files to AppServer
        # a. E:\CognosWebService\CognosAutomation\Licensees\<Licensee>\CoreModel
        # b. E:\CognosWebService\CognosAutomation\Licensees\<Licensee>\Reports

    $script_server_path = "\\PROPU2\scripts"
    $build_path = "\\PRB1DPA1\Builds\OWBridge"
    $hostname = [System.Net.Dns]::GetHostName()
    $logged_user = Get-Content env:username
    $cognos_servers = Import-Csv -Path "$script_server_path\Bridge_CognosAutomationServers.csv"
    $log_dir = "D:\Logs\scripts"
    if(Test-Path $log_dir){
        
        $datetime = (Get-Date -Format "yyyyMMdd_hhmmss")
        $OutputLogFile = "$log_dir\Deploy-BridgeCognos-$Build_$datetime.log"

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
        
    #Step 1: Validate Server Info & Get ServerName from BridgeCognosServers.txt
    Write "-- Validating Server with $script_server_path\Bridge_CognosAutomationServers.csv --" | Tee-Object $OutputLogFile -Append

    if(-not ($cognos_servers -match $hostname)){
        
        Write "*** Cannot find Target Server: Check $script_server_path\Bridge_CognosAutomationServers.csv" | Tee-Object $OutputLogFile -Append
        return

    }else{

        foreach($env in $cognos_servers){ 

            if(($env."CA_HOST" -eq "$hostname")) {
                $Environment = $env."ENVIRONMENT"
                $Platform = $env."PLATFORM"
                $destroot_dir = $env.CA_ROOT
                break
            }

        }
        if(-not $destroot_dir){

            Write "*** Cannot find Destination CA Root Dir in Bridge_CognosAutomationServers.csv for $Environment, $Platform" | Tee-Object $OutputLogFile -Append
            return
        }

    }
    #Check if Log Dir exists - if not, create one
    if(-not (Test-Path -Path $log_dir -PathType Container)){
        Write "-- Log Dir $log_dir doesn't exist on disk. Creating one.." | Tee-Object $OutputLogFile -Append
        mkdir $log_dir | Out-Null
    }

    Write "-- Deploy BridgeCognosAutomation trigged by $logged_user on $hostname ..." | Tee-Object $OutputLogFile -Append

    #Step 2: Validate LicenseeName from BridgeLicensees.txt
    Write "-- Validating Licensees with $script_server_path\Bridge_LicenseeNames.csv --" | Tee-Object $OutputLogFile -Append

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
        return
    }

    Write "-- Valid Licensees: $valid_licensees" | Tee-Object $OutputLogFile -Append
        
    $destroot_dir = [IO.Path]::Combine($destroot_dir,"Licensees")
    #Step 3: Validate Build Number and see if Cognos Artifacts exists in that Build
    if($BuildNumber -match "(\d\.\d{1,2})(\.\d{1,2})\.\d{1,3}" ){
        
        $release_num = $Matches[1]
        $builddir_root = "$build_path\$release_num\$BuildNumber"
        if($DeployFullPackage)
        {
            Write "--- Deploying Cognos Full Package ... " | Tee-Object $OutputLogFile -Append
            $cognosbuild = "$builddir_root\Cognos"
            $dwdest_root = "$cognosbuild\Destination\$BuildNumber"
            Write "--- Source Folders: $cognosbuild and $dwdest_root ... " | Tee-Object $OutputLogFile -Append

            #If Full Package then also copy BridgeCoreBIMetadata.xml
            $src_path="$builddir_root\CognosAutomation\app\App_Data\Configuration"
            if(Test-Path $src_path -PathType Container){

                Write "   ... Deploying BridgeCoreBIMetadata.xml to $licensee" | Tee-Object $OutputLogFile -Append
                $dest_path = "$destroot_dir\$licensee"
                
                robocopy $src_path $dest_path *.xml /NP | Tee-Object $OutputLogFile -Append
                
                $files = Get-ChildItem -Path $dest_path -File -Recurse
                $files | % {Set-ItemProperty -Path $_.FullName -Name IsReadOnly $false}

            }else{
                Write "   ... No BridgeCoreBIMetadata.xml to Deploy" | Tee-Object $OutputLogFile -Append
            }    
        }else{

            Write "--- Deploying Cognos Incremental Package ... " | Tee-Object $OutputLogFile -Append
            $cognosbuild = "$builddir_root\Incremental\Cognos"
            $dwdest_root = "$cognosbuild\Destination"
            Write "--- Source Folders: $cognosbuild and $dwdest_root ... " | Tee-Object $OutputLogFile -Append
        }
        
        

        if(Test-Path $cognosbuild -PathType Container){

            Write "--- CoreModel/Reports found ... " | Tee-Object $OutputLogFile -Append

        }else{
            
            Write "--- No CoreModel/Reports found ... " | Tee-Object $OutputLogFile -Append

        }

        if(Test-Path $dwdest_root -PathType Container){
            
            Write "--- DWSQL Scripts found ... " | Tee-Object $OutputLogFile -Append

        }else{

            Write "--- No DW Scripts found ... " | Tee-Object $OutputLogFile -Append

        }

    }

    #Step 4: If all the above are true then copy files to 
        # a. E:\CognosWebService\CognosAutomation\Licensees\<Licensee>\CoreModel
        # b. E:\CognosWebService\CognosAutomation\Licensees\<Licensee>\Reports
    
    foreach($licensee in $valid_licensees){
        
        Write "-- Deploying Core Model for Licensee $licensee" | Tee-Object $OutputLogFile -Append
        $src_path = "$cognosbuild\Core\Model"
        # If Model exists then Deploy
        if(Test-Path $src_path -PathType Container){

            Write "   ... Deploying CoreModel to $licensee" | Tee-Object $OutputLogFile -Append
            $dest_path = "$destroot_dir\$licensee\CoreModel"
            robocopy $src_path $dest_path *.xml *.cpf /NP | Tee-Object $OutputLogFile -Append
            
            #Remove Read-Only attributes from all files
            Write "   ... Removing Read-Only attributes on Files" | Tee-Object $OutputLogFile -Append
            $files = Get-ChildItem -Path $dest_path -File -Recurse
            $files | % {Set-ItemProperty -Path $_.FullName -Name IsReadOnly $false}

        }else{
            Write "   ... No Model Changes to Deploy" | Tee-Object $OutputLogFile -Append    
        }
        
        Write "-- Deploying Core Reports for Licensee $licensee" | Tee-Object $OutputLogFile -Append
        $src_path = "$cognosbuild\Core\Reports"
        # If Reports exists then Deploy
        if(Test-Path $src_path -PathType Container){

            Write "   ... Deploying Core Reports to $licensee" | Tee-Object $OutputLogFile -Append
            $dest_path = "$destroot_dir\$licensee\Reports"
            robocopy $src_path $dest_path /S *.xml *.cpf /NP | Tee-Object $OutputLogFile -Append

            #Remove Read-Only attributes from all files
            Write "   ... Removing Read-Only attributes on Files" | Tee-Object $OutputLogFile -Append
            $files = Get-ChildItem -Path $dest_path -File -Recurse
            $files | % {Set-ItemProperty -Path $_.FullName -Name IsReadOnly $false}

        }else{
            
            Write "   ... No Report Changes to Deploy" | Tee-Object $OutputLogFile -Append    
        }
        
        #If DW Destination SQLs exists then copy them over to
        $src_path = "$dwdest_root"
        if(Test-Path $src_path -PathType Container){

            Write "   ... Deploying DWSQL Scripts to $licensee" | Tee-Object $OutputLogFile -Append
            $dest_path = "$destroot_dir\$licensee\DWSchema"
            
            robocopy $src_path $dest_path /S *.sql /NP | Tee-Object $OutputLogFile -Append
            
            $files = Get-ChildItem -Path $dest_path -File -Recurse
            $files | % {Set-ItemProperty -Path $_.FullName -Name IsReadOnly $false}

        }else{

            Write "   ... No DW Destination Scripts to Deploy" | Tee-Object $OutputLogFile -Append

        }


        
    }

    Write "-- Deploy of Bridge Cognos $build to $Platform $Environment COMPLETE --" | Tee-Object $OutputLogFile -Append
