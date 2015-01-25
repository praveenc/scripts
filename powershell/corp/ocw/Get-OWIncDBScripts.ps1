Param(
    <#
    .Synopsis
       Creates Combine Package for a given db-Combine folder
    .DESCRIPTION
       Creates combine package by recursivley adding files, folders to
       Package. First Creates Package then adds folders and files recursively.
       This script is Product agnostic. Will create package as long as FarmCombineBuild is available.
    .PARAMETER BranchName
        Name of the Branch e.g. $/Geno3/mainline, $/Bridge/mainline, $/Bridge/2.0
    .PARAMETER BuildNumber
        Build Number e.g. 3.12.14.05
    .PARAMETER LastBuildDate
        Last Successfull Build Date as logged in SCMDB in String e.g. '2013-05-03 12:13:00'
    .PARAMETER LogDirectory
        Log Directory
    .EXAMPLE
       Get-OWIncDBScripts -BranchName $/Bridge/mainline -BuildNumber '2.2.0.75' -LastBuildDate '2013-05-03 12:13' -LogDirectory 'E:\Builds\OWBridge\2.2\2.2.0.75\log' -Container Bridge_BETAQA
    .NOTES
        Author: Praveen Chamarthi
        Date: 23 Apr 2013
    #>

    
    [CmdletBinding()]
    [Parameter(Mandatory=$true,
               Position=0,
               HelpMessage="TFS Branch name e.g. $/Bridge/mainline")]
    [ValidatePattern("\$\/(.*?)\/(.*)")]
    [String]$BranchName,

    [Parameter(Mandatory=$true,
               Position=1,
               HelpMessage="Build Number")]
    [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{1,3}")]
    [String]$BuildNumber,

    [Parameter(Mandatory=$true,
               Position=2,
               HelpMessage="Last Successful Build date in format yyyy-MM-dd hh:ss")]
    [String]$LastBuildDate,

    [Parameter(Mandatory=$true,
               Position=3,
               HelpMessage="Log Dir Path")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [String]$LogDirectory,
    
    [Parameter(Mandatory=$true,
               Position=4,
               HelpMessage="Container Name to be set for the Package")]
    [ValidateNotNullorEmpty()]
    [String]$Container,

    [Parameter(Mandatory=$false,
               Position=5,
               HelpMessage="Build Output Dir Root e.g. E:\Builds")]
    [String]$BuildOutputDirectory="E:\Builds\OWBridge"


)

    #Include Common Functions, Scrub-OWScripts, Create-OWCombinePackage
    . .\OW-CMTools.ps1

    #Set Working Directory to Current Directory
    [Environment]::CurrentDirectory=(Get-Location -PSProvider FileSystem).ProviderPath

     #Generate Short Build Number & Release Number
     $numbersplit = [Array]$BuildNumber.split(".")
     $buildnumber_short = ""
     for($i = 0; $i -lt $numbersplit.Length-1; $i++){
         $buildnumber_short += [String]$numbersplit[$i]+"."
     }
     $buildnumber_short = $buildnumber_short.Substring(0, $buildnumber_short.Length-1)
    
     $releasenumber = ""
     for($i = 0; $i -lt $numbersplit.Length-2; $i++){
        $releasenumber += [String]$numbersplit[$i]+"."
     }
     $releasenumber = $buildnumber_short.Substring(0,$releasenumber.Length-1)
     
     #Convert LastBuildDate to DateTime
     $LastBuildDate = [System.DateTime]$LastBuildDate

     #Extract Product Name
     $ProductName = $BranchName.Split("/")[1]
     $SubBranch = $BranchName.Split("/")[2]
     
     $DBCombine_Suffix = "$releasenumber\$BuildNumber\db-Combine\$BuildNumber"
     $Deployment_Suffix = "$releasenumber\$BuildNumber\app\Deployment"
     $OutputLogFile = "$LogDirectory\$BuildNumber.Get-IncDBScripts-$ProductName.log"

     $DestinationFolder = "$BuildOutputDirectory\$DBCombine_Suffix"
     $DeployFilesFolder = "$BuildOutputDirectory\$Deployment_Suffix"
     
    #Create Log Folder
    If((Test-Path $OutputLogFile) -eq $false){

        mkdir (Split-Path $OutputLogFile) | Out-Null

    }
    #Load TF Services - VersionControl service to Download File
    $tfserver = "http://prg2tfa1:8080/tfs"
    $tfvcs = (Get-TfsServer -Name $tfserver).GetService('Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer')
    
    
    #Set TF Server Paths for Code
    If($SubBranch -eq 'feature'){
    
        $DBScriptsDir = "$/$ProductName/$SubBranch/$buildnumber_short/DBScripts"
        $DeployDir = "$/$ProductName/$SubBranch/$buildnumber_short/Deployment"

    }else{

        $DBScriptsDir = "$/$ProductName/$buildnumber_short/DBScripts"
        $DeployDir = "$/$ProductName/$buildnumber_short/Deployment"    
    }
    
    $DBObjectsDir = "$BranchName/DATABASE"
    $DWSourceDir = "$BranchName/Datawarehouse/Source"
    $DWDestDir = "$BranchName/Datawarehouse/Destination"


    #Write "--- Build Number: $buildnumber, Build Date: $lastbuilddate"
    Write "=== $ProductName : Starting Get Incremental Scripts =====" | Tee-Object $OutputLogFile -Append
    Write "--- Destination: $DestinationFolder" | Tee-Object $OutputLogFile -Append
    Write "--- DB ScriptsDir: $DBScriptsDir" | Tee-Object $OutputLogFile -Append
    Write "--- Deployment Dir: $DeployDir" | Tee-Object $OutputLogFile -Append
    Write "--- DBObjects Dir: $DBObjectsDir" | Tee-Object $OutputLogFile -Append
    Write "--- DWSourceDir: $DWSourceDir" | Tee-Object $OutputLogFile -Append
    Write "--- DWDestDir: $DWDestDir" | Tee-Object $OutputLogFile -Append

    #Set all flags to false
    $is_dbscripts = $false
    $is_dbobjects = $false
    $is_deployins = $false
    $is_dwsource = $false
    $is_dwdest = $false

    #Find Deploy Instructions If any
    try{

        [Array]$insresult = Get-TfsChildItem $DeployDir -Server (Get-TfsServer -Name $tfserver) | 
                    Where {$_.checkindate -ge $LastBuildDate} | 
                    Select ServerItem -ErrorAction Stop

        [int]$inscnt = $insresult.Count - 1
        Write "--- Deploy Instructions Items found: " ($inscnt+1) | Tee-Object $OutputLogFile -Append

    }catch{
        
        Write-Warning "Error getting..$DeployDir"
        Write "Error getting..$DeployDir" | Tee-Object $OutputLogFile -Append

    }

    #Find Incremental DBScripts If any
    try{
        
        [Array]$dbresult = Get-TfsChildItem $DBScriptsDir -Server (Get-TfsServer -Name $tfserver) | 
                    Where {$_.checkindate -ge $LastBuildDate} | 
                    Select ServerItem -ErrorAction Stop
        
        [int]$dbcnt = $dbresult.Count - 1
        Write "--- DBScripts Items Found: " ($dbcnt+1) | Tee-Object $OutputLogFile -Append

    }catch{

        Write-Warning "Error getting.. $DBScriptsDir"
        Write "Error getting..$DBScriptsDir" | Tee-Object $OutputLogFile -Append
    }                
    
    #Find DBObjects - Stored Procs, Functions etc If any
    try{
        
        [Array]$dbobjectsresult = Get-TfsChildItem $DBObjectsDir -Recurse -Server (Get-TfsServer -Name $tfserver) | 
                    Where {$_.checkindate -ge $lastbuilddate} | Select ServerItem -ErrorAction Stop

        [int]$dbobjcnt = $dbobjectsresult.Count - 1            
        Write "--- DB Objects Items Found (including folders): "($dbobjcnt+1) | Tee-Object $OutputLogFile -Append


    }catch{
        
        Write-Warning "Error getting.. $DBObjectsDir " -Verbose
        Write "Error getting.. $DBObjectsDir" | Tee-Object $OutputLogFile -Append

    }

    #Find DWSource Scripts if any
    try{
        
        [Array]$dwsourceresult = Get-TfsChildItem $DWSourceDir -Recurse -Server (Get-TfsServer -Name $tfserver) | 
                    Where {$_.checkindate -ge $lastbuilddate} | Select ServerItem -ErrorAction Stop

        [int]$dwsourceobjcnt = $dwsourceresult.Count - 1            
        Write "--- DWSource Items Found (including folders): "($dwsource_objcnt+1) | Tee-Object $OutputLogFile -Append


    }catch{
        
        Write-Warning "Error getting.. $DWSourceDir " -Verbose
        Write "Error getting.. $DWSourceDir" | Tee-Object $OutputLogFile -Append

    }

    #Find DW Destination Scripts if any
    try{
        
        [Array]$dwdestresult = Get-TfsChildItem $DWDestDir -Recurse -Server (Get-TfsServer -Name $tfserver) | 
                    Where {$_.checkindate -ge $lastbuilddate} | Select ServerItem -ErrorAction Stop

        [int]$dwdestobjcnt = $dwdestresult.Count - 1            
        Write "--- DW Destination Items Found (including folders): "($dwdest_objcnt+1) | Tee-Object $OutputLogFile -Append


    }catch{
        
        Write-Warning "Error getting.. $DWDestDir " -Verbose
        Write "Error getting.. $DWDestDir" | Tee-Object $OutputLogFile -Append

    }    

    #Download Deploy Instructions
    if ($inscnt -ge 0)
    {
        #Create Deployment Folder If not Exists
        If((Test-Path $DeployFilesFolder) -eq $false){
            mkdir $DeployFilesFolder | Out-Null
        }
        #Traverse through the items and download if any
        foreach($item in $insresult){
           
            [String]$serveritem = $item.ServerItem
            [String]$filename = Split-Path $serveritem -Leaf

            #Download only if its a file           
            If($filename -match '.txt'){
                
                $is_deployins = $true

                [String]$DestinationFile = "$DeployFilesFolder\$filename"
                Write "--- Downloading $filename" | Tee-Object $OutputLogFile -Append
                $tfvcs.DownloadFile($serveritem, $DestinationFile)
            }

        }

    }else{

        $is_deployins = $false
        Write "--- No Deploy Instructions" | Tee-Object $OutputLogFile -Append
    }

    #Download DBScripts
    if ($dbcnt -ge 0)
    {
        
        Write "--- Found DBScripts" | Tee-Object $OutputLogFile -Append

        #Create db-Combine Folder If not Exists
        If((Test-Path $DestinationFolder -PathType Container) -eq $false){
            mkdir $DestinationFolder | Out-Null
        }

        #Download latest version from source control to disk
        foreach($item in $dbresult){
           
            [String]$serveritem = $item.ServerItem
            [String]$filename = Split-Path $serveritem -Leaf

            #Download only if its a file
            If($filename -match '.sql'){

                $is_dbscripts = $true

                #Split path to Gather Dir name    
                [String]$parentstring = Split-Path $serveritem -Parent
                [Array]$dirarr = $parentstring.Split("\")
                [String]$dirname = $dirarr[($dirarr.Count)-1]

                [String]$DestinationFile = "$DestinationFolder\$dirname\$filename"
                Write "--- Downloading $filename" | Tee-Object $OutputLogFile -Append
                $tfvcs.DownloadFile($serveritem, $DestinationFile)

            }
           
        }

    }else{

       $is_dbscripts = $false
       Write "--- No DBSCripts" | Tee-Object $OutputLogFile -Append 
    }

    #Download DBObjects & Scrub : Stored Procs, Functions If any
    if ($dbobjcnt -ge 0)
    {

        #Create db-Combine Folder If not Exists
        If((Test-Path $DestinationFolder -PathType Container) -eq $false){
            mkdir $DestinationFolder | Out-Null
        }

        foreach($item in $dbobjectsresult){
            
            [String]$serveritem = $item.ServerItem
            [String]$filename = Split-Path $serveritem -Leaf
            
            #Download only if its a file           
            If($filename -match '.sql'){
                
                $is_dbobjects = $true

                #Split path to Gather Dir name    
                [String]$parentstring = Split-Path $serveritem -Parent
                [Array]$dirarr = $parentstring.Split("\")
                [String]$dirname = $dirarr[($dirarr.Count)-1]    

                if($dirname -eq "udf") {
                    $dirname = "Functions"
                }
                [String]$DestinationFile = "$DestinationFolder\$dirname\$filename"

                Write "--- Downloading $filename" | Tee-Object $OutputLogFile -Append
                $tfvcs.DownloadFile($serveritem, $DestinationFile)
            
                #ScrubScripts after Download
                Scrub-OWScripts -FileToScrub "$DestinationFile" | Tee-Object $OutputLogFile -Append
           }
          
        }
     
    }else{

        $is_dbobjects = $false
        Write "--- No DB Objects" | Tee-Object $OutputLogFile -Append
    }
    
    #Download DW Source Objects If Any & Scrub : Tables, Views etc
    if ($dwsourceobjcnt -ge 0)
    {

        #Create db-Combine Folder If not Exists
        If((Test-Path $DestinationFolder -PathType Container) -eq $false){
            mkdir $DestinationFolder | Out-Null
        }

        foreach($item in $dwsourceresult){
            
            [String]$serveritem = $item.ServerItem
            [String]$filename = Split-Path $serveritem -Leaf
            
            #Download only if its a file           
            If($filename -match '.sql'){
                
                $is_dwsource = $true

                #Split path to Gather Dir name    
                [String]$parentstring = Split-Path $serveritem -Parent
                [Array]$dirarr = $parentstring.Split("\")
                [String]$dirname = $dirarr[($dirarr.Count)-1]    

                [String]$DestinationFile = "$DestinationFolder\$dirname\$filename"

                Write "--- Downloading $filename" | Tee-Object $OutputLogFile -Append
                $tfvcs.DownloadFile($serveritem, $DestinationFile)
            
                #ScrubScripts after Download
                Scrub-OWScripts -FileToScrub "$DestinationFile" | Tee-Object $OutputLogFile -Append
           }
          
        }
     
    }else{

        $is_dwsource = $false
        Write "--- No DW Source Objects" | Tee-Object $OutputLogFile -Append
    }

    #If DW Destination files are Present; Set Flag to True
    if ($dwdestobjcnt -ge 0){
        
         foreach($item in $dwdestresult){
            
            [String]$serveritem = $item.ServerItem
            [String]$filename = Split-Path $serveritem -Leaf
            
            #Download only if its a file           
            If($filename -match '.sql'){

                $is_dwdest = $true

                #Create Text File  If Present    
                Write "==== Writing Text File to Indicate Changes in Destination =====" | Tee-Object $OutputLogFile -Append

                $DWDestination_TextFile = "$BuildOutputDirectory\$releasenumber\$BuildNumber\Database\Datawarehouse\$BuildNumber.DW-DEST.Changes.txt"
                
                $DWDestFolder = Split-Path $DWDestination_TextFile -Parent
                #Create Destination folder if not exist
                If((Test-Path $DWDestFolder -PathType Container) -eq $false){
                    mkdir $DWDestFolder | Out-Null
                }
                #Write File to it    
                Set-Content -Path $DWDestination_TextFile "Changes Identified in DW Destination scripts since $LastBuildDate `r`n Build: $BuildNumber `r`n"

                Write "==== Text File Written to $DWDestination_TextFile  =====" | Tee-Object $OutputLogFile -Append

           }
          
        }
    }else{

        $is_dwdest = $false
        Write "--- No DW Destination Objects" | Tee-Object $OutputLogFile -Append

    }

    #Create Combine Package for Bridge Incremental & DW Source Scripts
    if($is_dbscripts -eq $true -or $is_dbobjects -eq $true -or $is_dwsource -eq $true)
    {
        
        Write "==== Packaging $ProductName Combine Package =====" | Tee-Object $OutputLogFile -Append

        $PackageName = "$BuildNumber.cpa"

        #Set working directory to current directory
        $grantpermission_scriptpath = [IO.Directory]::GetCurrentDirectory() + "\GrantPermissions.sql"
        $owsysmodule_scriptpath = [IO.Directory]::GetCurrentDirectory() + "\Update_OWSYSMODULE.sql"

        #Remove Read-Only Attributes on the Files if any
        Set-ItemProperty $owsysmodule_scriptpath -Name IsReadOnly $false
        Set-ItemProperty $grantpermission_scriptpath -Name IsReadOnly $false

        Write "--- GrantPermission Path: $grantpermission_scriptpath" | Tee-Object $OutputLogFile -Append

        #Write Update_OWSysModule.SQL with Current Build Number
        Set-Content -Path $owsysmodule_scriptpath "PRINT 'Processing OwSysModule insert'`rINSERT INTO [dbo].[OwSysModule]([ModuleName],[InstalledFlag],[VersionNo],[ObjectType],[UpdateDate]) VALUES ('BridgeCore',1,'$BuildNumber','CombinePackage',GETDATE())`r"
        
        Write "--- Update OWSysModule Script : $owsysmodule_scriptpath written successfully!" | Tee-Object $OutputLogFile -Append
    
        #Copy OWSysModule and GrantPermissions to Destination Folder
        Copy-Item -Path $grantpermission_scriptpath -Destination $DestinationFolder
        Copy-Item -Path $owsysmodule_scriptpath -Destination $DestinationFolder

        Create-OWCombinePackage -PackageName $PackageName -ScriptsFolder $DestinationFolder -Container $Container | 
            Tee-Object $OutputLogFile -Append

        #Revoke Read-Only Attributes on the Files if any
        Set-ItemProperty $owsysmodule_scriptpath -Name IsReadOnly $true
        Set-ItemProperty $grantpermission_scriptpath -Name IsReadOnly $true

        Write "==== Packaging $ProductName Complete =====" | Tee-Object $OutputLogFile -Append

    }else{
        
        Write "==== No Incremental Scripts found: Combine Package Ignored ===" | 
            Tee-Object $OutputLogFile -Append
    }
