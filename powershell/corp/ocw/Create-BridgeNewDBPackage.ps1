Param(
    <#
    .Synopsis
       Create a SQL Farms Combine package for a specific licensee
    .DESCRIPTION
       This script is used to create the FarmCombine Package that is required
       to setup a new Licensee
    .PARAMETER Build
        Base Build Number i.e. 2.2.2.09
    .PARAMETER LicenseeName
        Name of the New Licensee e.g. CPAM
    .EXAMPLE
       Create-BridgeDBPackage -Build 2.2.2.09 -LicenseeName CPAM
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
               HelpMessage="New LicenseeName e.g. CPAM")]
    [ValidateNotNullOrEmpty()]
    [String]$LicenseeName,

    [Parameter(Mandatory=$false,
               Position=2,
               HelpMessage="Log Directory")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [String]$LogDirectory="E:\Builds\OWBridge"


)

    #Set Working Directory to Current Directory
    [Environment]::CurrentDirectory=(Get-Location -PSProvider FileSystem).ProviderPath
    
    #Include Common Functions, Scrub-OWScripts, Create-OWCombinePackage
    . .\OW-CMTools.ps1
    

    #Generate Short Build Number & Release Number
    If($BuildNumber -match "(\d\.\d{1,2})(\.\d{1,2})\.\d{2,3}"){

        $releasenumber = $Matches[1]
        $buildnumber_short = "$releasenumber" + $Matches[2]

    }

    $BridgeBuildRepositoryPath = "E:\Builds\OWBridge\$releasenumber\$BuildNumber"
    $MIDSInitDBPath = "$BridgeBuildRepositoryPath\BridgeNewDB\MIDSInitDB"
    $BridgeNewDBPath="$BridgeBuildRepositoryPath\BridgeNewDB\SQL"
    
    $TargetRoot="E:\Builds\OWBridge\$releasenumber\DatabaseSetup\$LicenseeName"
    $TargetSQLDir = "$TargetRoot\SQL"
    $TargetMIDSInitDBDir = "$TargetRoot\MIDSInitDB"
    $OWSysModulePath = [IO.Directory]::GetCurrentDirectory() + "\Create_OWSYSMODULE.sql"
    $CombinePackageName = $LicenseeName

    #Exit Script if Folders not found
    if(-Not(Test-Path $MIDSInitDBPath -PathType Container)){

        Write "---- Cannot Find MIDSInitDB - $MIDSInitDBPath .. Exiting" | Tee-Object $LogFile -Append        
        throw "---- Cannot Find MIDSInitDB folder $MIDSInitDBPath"
        return

    }
    if(-Not(Test-Path $BridgeNewDBPath -PathType Container)){

        Write "---- Cannot Find BridgeNewDB - $BridgeNewDBPath .. Exiting" | Tee-Object $LogFile -Append        
        throw "---- Cannot Find BridgeNewDB folder $BridgeNewDBPath"
        return

    }
    
    
    #Log File definition here
    $LogDir = "$LogDirectory\$releasenumber\DatabaseSetup\log"
    if(-Not (Test-Path $LogDir -PathType Container)){
        mkdir $LogDir | Out-Null
    }
    if(-Not (Test-Path $TargetRoot -PathType Container)){
        mkdir $TargetRoot | Out-Null
    }

    $TimeStamp = Get-Date -format yyyy_d_M_HH_m
    $LogFile = "$LogDir\$BuildNumber.Create-BridgeNewDBPackage.log"

    #Remove any files that exist before
    Write "---- Cleaning $TargetRoot folder.. " | Tee-Object $LogFile -Append
    Remove-Item -Path "$TargetRoot\**" -Recurse -Force

    #Copy all the required scripts to Target Folder

    Write "---- Copying DB Scripts.." | Tee-Object $LogFile -Append
    robocopy $BridgeNewDBPath $TargetSQLDir /MIR /NP /NJS | Tee-Object $LogFile -Append

    #Remove ReadOnly Attributes on Files and Replace DB Name to New LicenseeName
    $tgt_files = Get-ChildItem $TargetSQLDir -Recurse
    foreach($file in $tgt_files){

        $file_fullname = $file.FullName
        $file_name = $file.Name

        If(Test-Path $file_fullname -PathType Leaf){
        
            Set-ItemProperty $file_fullname -Name IsReadOnly $false
            
            Write "---- Replacing Bridge_Demo with Bridge_$LicenseeName in $file_name "  | Tee-Object $LogFile -Append

            #Replace Bridge_Demo with Bridge_LicenseeName
            (Get-Content $file_fullname) | 
                ForEach-Object { $_ -replace "Bridge_Demo","Bridge_$LicenseeName"} | 
                Set-Content $file_fullname -Encoding Default -Force

            if($file_fullname -match "Create DB Objects"){
                Set-ItemProperty $file_fullname -Name IsReadOnly $false                
                $filetomodify = $file_fullname
                $lines = Get-Content $filetomodify

                $sp_prefix_statements= "SET QUOTED_IDENTIFIER OFF;`r`n"
                $sp_prefix_statements+= "GO`r`n"
                $sp_prefix_statements+= "USE [Bridge_$LicenseeName];`r`n"
                $sp_prefix_statements+= "GO`r`n"
                $sp_prefix_statements+= "`r`n`r`n"
                $sp_prefix_statements+= "SET ANSI_NULLS ON;`r`n"
                $sp_prefix_statements+= "GO`r`n"
                $sp_prefix_statements+= "SET QUOTED_IDENTIFIER ON;`r`n"
                $sp_prefix_statements+= "GO`r`n"
                $sp_prefix_statements+= "`r`n`r`n"

                $modifiedlines = $sp_prefix_statements
                foreach($line in $lines){

                    $modifiedlines += $line + "`r"
                }
                Set-Content -Path "$filetomodify" -Value "$modifiedlines"
                Scrub-OWScripts -FiletoScrub $filetomodify

            }
        }

    }

    #Copy OWSYSMODULESCRIPT and Replace Defaults
    (Get-Content "$OWSysModulePath") |
        ForEach-Object { $_ -replace "BRIDGE_YOURLICENSEEHERE","Bridge_$LicenseeName" } | 
        Set-Content "$TargetSQLDir\Create_OWSYSMODULE.sql" -Encoding Default -Force

    (Get-Content "$TargetSQLDir\Create_OWSYSMODULE.sql") |
        ForEach-Object { $_ -replace "x\.x\.x\.yy","$BuildNumber" } | 
        Set-Content "$TargetSQLDir\Create_OWSYSMODULE.sql" -Encoding Default -Force


    Write "---- Creating combine package for Licensee $LicenseeName" | Tee-Object $LogFile -Append
    #Create Combine Package with LicenseeName
    Create-OWCombinePackage -PackageName $CombinePackageName -ScriptsFolder $TargetSQLDir -Container "Bridge_BETA_Staging_Incremental"

    #Finally Copy MIDSInitDB to Target
    Write "---- Copying MIDSInitDB ..." -Verbose
    robocopy $MIDSInitDBPath $TargetMIDSInitDBDir /MIR /NP /NJS | Tee-Object $LogFile -Append

    Write "---- Replacing defaults in MIDSInitDB.exe.config with $LicenseeName" | Tee-Object $LogFile -Append

    #Replace MIDSInitDB.exe.config with LicenseeName and Trusted_Connection
    (Get-Content "$TargetMIDSInitDBDir/MIDSInitDB.exe.config") | 
        ForEach-Object {$_ -replace "BRIDGE_YOURLICENSEEHERE","Bridge_$LicenseeName" } |
        Set-Content "$TargetMIDSInitDBDir/MIDSInitDB.exe.config" -Encoding Default -Force

    (Get-Content "$TargetMIDSInitDBDir/MIDSInitDB.exe.config") | 
        ForEach-Object {$_ -replace "User\sID(.*?);Password(.*?);","Trusted_Connection=True;" } |
        Set-Content "$TargetMIDSInitDBDir/MIDSInitDB.exe.config" -Encoding Default -Force

    
    Write "--- Create-BridgeDBPackage is now Complete ---" | Tee-Object $LogFile -Append
