Param(
    <#
    .Synopsis
       Customize an Existing Farms Combine package for a specific Environment
    .DESCRIPTION
       This script is used to modify a FarmCombine Package and copy to DBSetup-Working folder
    .PARAMETER Build
        Base Build Number i.e. 2.2.2.09
    .PARAMETER LicenseeName
        Name of the New Licensee e.g. CPAM
    .PARAMETER Environment
        Bridge Target Env Name e.g. DEV, QA, STAGING, UAT, PRODUCTION
    .PARAMETER Platform
        Bridge Target Platform Name e.g. ALPHA, BETA, SUPPORT, PRODUCTION
    .EXAMPLE
       Create-BridgeDBPackage -Build 2.2.2.09 -LicenseeName CPAM -Environment UAT -Platform SUPPORT
    .NOTES
        Author: Praveen Chamarthi
        Date: 10 Sep 2013
    #>

    [CmdletBinding()]
    [Parameter(Mandatory=$true,
               Position=0,
               HelpMessage="Build Number")]
    [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{2,3}")]
    [String]$BuildNumber,

    [Parameter(Mandatory=$true,
               Position=1,
               HelpMessage="LicenseeName e.g. ACE")]
    [ValidateNotNullOrEmpty()]
    [String]$LicenseeName,

    [Parameter(Mandatory=$true,
               Position=2,
               HelpMessage="Environment Name e.g. QA, UAT, PRODUCTION")]
    [ValidateSet("DEV","QA","STAGING","UAT","PRODUCTION")]
    [String]$Environment,

    [Parameter(Mandatory=$true,
               Position=3,
               HelpMessage="Platform Name e.g. ALPHA, BETA, SUPPORT, PRODUCTION")]
    [ValidateSet("ALPHA","BETA","SUPPORT","PRODUCTION")]
    [String]$Platform,

    [Parameter(Mandatory=$false,
               Position=4,
               HelpMessage="Log Directory")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [String]$LogDirectory="E:\Builds\OWBridge"

)

    #Generate Short Build Number & Release Number
    If($BuildNumber -match "(\d\.\d{1,2})(\.\d{1,2})\.\d{2,3}"){

        $releasenumber = $Matches[1]
        $buildnumber_short = "$releasenumber" + $Matches[2]

    }

    $PackageSourceDir = "E:\Builds\OWBridge\$releasenumber\DatabaseSetup"
    $PackageTargetDir = "E:\Builds\OWBridge\$releasenumber\DBSetup-Working"
    $TargetFolderName = $LicenseeName+"_"+$Platform+"_"+$Environment
    $TargetDir = "$PackageTargetDir\$TargetFolderName"
    $dbserverscsv = "\\192.168.0.55\scripts\Bridge_DatabaseServers.csv"

    #Log File definition here
    $LogDir = "$LogDirectory\$releasenumber\DBSetup-Working\log"
    $TimeStamp = Get-Date -format yyyy_d_M_HH_m
    $LogFile = "$LogDir\$BuildNumber.Customize-BridgeNewDBPackage.log"


    #Find Database Path from Environment refer BridgeEnvironments.csv
    Write "---- Validating Environment ..." | Tee-Object $LogFile -Append
    
    $BridgeEnvs = Import-CSV -Path "$dbserverscsv"
    foreach($env in $BridgeEnvs){ 

        if(($env."ENV_NAME" -eq "$Environment") -and ($env."PLATFORM" -eq "$Platform")) { 
            $DBPath = $env.DB_PHYSICALPATHMOD
            $DBServer = $env.DB_SERVER
            break
        } 

    }

    #Copy Files from DatabaseSetup to DBSetup-Working
    If(-Not(Test-Path "$PackageSourceDir\$LicenseeName" -PathType Container)){

        Write "---- DatabaseSetup not found - run Create-BridgeDBPackage.ps1 for $LicenseeName first" | 
                        Tee-Object $LogFile -Append    
        return
    }

    Write "---- Copying DatabaseSetup ..." | Tee-Object $LogFile -Append
    robocopy "$PackageSourceDir\$LicenseeName" "$TargetDir" /MIR /NP /NJS | Tee-Object $LogFile -Append

    $tgt_files = Get-ChildItem -Path "$TargetDir" -Recurse
    foreach($file in $tgt_files){
        
        #Replace E:\Data with Path as defined in BridgeEnvironments.csv
        if($file -match "Create\sNew\sDB\.sql"){
            
            Write "Replacing E:\Data with $DBPath in Create New DB.sql" | Tee-Object $LogFile -Append

            Set-ItemProperty $file.FullName -Name IsReadOnly $false
            
            (Get-Content $file.FullName) | 
                ForEach-Object { $_ -replace "E:\\Data","$DBPath"} | 
                Set-Content $file.FullName -Encoding Default -Force            

        }

        #Replace Data Source with value from DB_SERVER in BridgeEnvironments.csv
        if($file -match "MIDSInitDB\.exe\.config"){

            Write "Replacing PRBIMES2\DV with $DBServer in MIDSInitDB.exe.config" | Tee-Object $LogFile -Append

            Set-ItemProperty $file.FullName -Name IsReadOnly $false

            (Get-Content $file.FullName) | 
                ForEach-Object { $_ -replace "PRB1MES2\\DV","$DBServer"} | 
                Set-Content $file.FullName -Encoding Default -Force         

        }

    }

    Write "--- Customize-BridgeDBPackage is now Complete ---" | Tee-Object $LogFile -Append
