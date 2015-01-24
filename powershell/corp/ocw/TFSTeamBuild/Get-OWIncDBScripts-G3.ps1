Param(
    <#
    .Synopsis
       Creates Combine Package for a given db-Combine folder
    .DESCRIPTION
       Creates combine package by recursivley adding files, folders to
       Package. First Creates Package then adds folders and files recursively.
       This script is Product agnostic. Will create package as long as FarmCombineBuild is available.
    .PARAMETER TFSPath
        TFS Path to the Code e.g. $/Geno3/mainline
    .PARAMETER BuildNumber
        Build Number e.g. 3.14.14.10
    .PARAMETER LastBuildDate
        Last Successful Build Date in SCMDB e.g. '2013-05-03 12:13'
    .PARAMETER LogDirectory
        Log File Directory e.g E:\Builds\3.14\3.14.14.09\log
    .PARAMETER Container
        JNet Direct Combine Container Name as configured on PRG2TFA1: e.g. G3_BETAQA
    .EXAMPLE
       Get-OWIncDBScripts.ps1 -TFSPath $/Genoa3/mainline -BuildNumber '3.12.14.05' -LastBuildDate '2013-05-03 12:13:00' -LogDirectory 'E:\Builds\3.12\3.12.14.05\log'
    .NOTES
        Author: Praveen Chamarthi
        Date: 17 Jun 2013
    #>

    
    [CmdletBinding()]
    [Parameter(Mandatory=$true,
               Position=0,
               HelpMessage="TFS path e.g. $/Genoa3/mainline")]
    [ValidatePattern("\$\/(.*?)\/(.*)")]
    [String]$TFSPath,

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
    [String]$Container="G3_BETAQA",
    
    [Parameter(Mandatory=$false,
               Position=5,
               HelpMessage="Build Output Dir Root e.g. E:\Builds")]
    [String]$BuildOutputDirectory="E:\Builds"


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
    $ProductName = $TFSPath.Split("/")[1]
    $SubBranch = $TFSPath.Split("/")[2]
     
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
    
    $DBObjectsDir = "$TFSPath/DATABASE"

    #Write "--- Build Number: $buildnumber, Build Date: $lastbuilddate"
    Write "=== $ProductName : Starting Get Incremental Scripts =====" | Tee-Object $OutputLogFile -Append
    Write "--- Destination: $DestinationFolder" | Tee-Object $OutputLogFile -Append
    Write "--- DB ScriptsDir: $DBScriptsDir" | Tee-Object $OutputLogFile -Append
    Write "--- Deployment Dir: $DeployDir" | Tee-Object $OutputLogFile -Append
    Write "--- DBObjects Dir: $DBObjectsDir" | Tee-Object $OutputLogFile -Append


    #Set all flags to false
    $is_dbscripts = $false
    $is_dbobjects = $false
    $is_deployins = $false

    #Find Deploy Instructions If any
    try{

        [Array]$insresult = Get-TfsChildItem $DeployDir -Server (Get-TfsServer -Name $tfserver) | 
                    Where {$_.checkindate -ge $LastBuildDate} | 
                    Select ServerItem -ErrorAction Stop

        [int]$inscnt = $insresult.Count - 1
        Write "--- Deploy Instructions Items found (including folders): " ($inscnt+1) | Tee-Object $OutputLogFile -Append

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
        Write "--- DBScripts Items Found (including folders): " ($dbcnt+1) | Tee-Object $OutputLogFile -Append

    }catch{

        Write-Warning "Error getting..$DBScriptsDir"
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

    #Download Deploy Instructions
    if ($inscnt -ge 0)
    {

        #Traverse through the items and download if any
        foreach($item in $insresult){
           
            [String]$serveritem = $item.ServerItem
            [String]$filename = Split-Path $serveritem -Leaf

            #Download only if its a file           
            If($filename -match '.txt'){
				
				#Create Deployment Folder If not Exists
				If((Test-Path $DeployFilesFolder) -eq $false){
					mkdir $DeployFilesFolder | Out-Null
				}
                
                $is_deployins = $true

                [String]$DestinationFile = "$DeployFilesFolder\$filename"
                Write "--- Downloading $filename" | Tee-Object $OutputLogFile -Append
                $tfvcs.DownloadFile($serveritem, $DestinationFile)
            }
        }

    }
    else{
        
        $is_deployins = $false
        Write "--- No Deploy Instructions" | Tee-Object $OutputLogFile -Append

    }


    #Download DBScripts
    if ($dbcnt -ge 0)
    {
        
        Write "--- Found DBScripts" | Tee-Object $OutputLogFile -Append

        #Download latest version from source control to disk
        foreach($item in $dbresult){
           
            [String]$serveritem = $item.ServerItem
            [String]$filename = Split-Path $serveritem -Leaf

            #Download only if its a file
            If($filename -match '.sql'){
				
				#Create db-Combine Folder If not Exists
				If((Test-Path $DestinationFolder -PathType Container) -eq $false){
					mkdir $DestinationFolder | Out-Null
				}

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

    }
    else{
    
       $is_dbscripts = $false
       Write "--- No DBSCripts" | Tee-Object $OutputLogFile -Append
    }

    #Download DBObjects: Stored Procs, Functions If any
    if ($dbobjcnt -ge 0)
    {
        
        Write "--- Found DB Objects" | Tee-Object $OutputLogFile -Append
        
        foreach($item in $dbobjectsresult){
            
            [String]$serveritem = $item.ServerItem
            [String]$filename = Split-Path $serveritem -Leaf
            
            #Download only if its a file           
            If($filename -match '.sql'){
                
                $is_dbobjects = $true

				#Create db-Combine Folder If not Exists
				If((Test-Path $DestinationFolder -PathType Container) -eq $false){
					mkdir $DestinationFolder | Out-Null
				}

                #Split path to Gather Dir name    
                [String]$parentstring = Split-Path $serveritem -Parent
                If($parentstring -match 'procedures'){
                    [String]$dirname = "Stored Procedures"
                }else{

                    [Array]$dirarr = $parentstring.Split("\")
                    [String]$dirname = $dirarr[($dirarr.Count)-1]
                    
                }
                If($dirname -eq 'udf'){
                    $dirname = "Functions"
                }

                [String]$DestinationFile = "$DestinationFolder\$dirname\$filename"

                Write "--- Downloading $filename" | Tee-Object $OutputLogFile -Append
                $tfvcs.DownloadFile($serveritem, $DestinationFile)
            
                #ScrubScripts after Download
                Scrub-OWScripts -FileToScrub "$DestinationFile" | Tee-Object $OutputLogFile -Append

           }
          
        }
     
    }
    else{
  
        $is_dbobjects = $false
        Write "--- No DB Objects" | Tee-Object $OutputLogFile -Append
    }

    #Call Combine Package If Scripts are present
    if($is_dbscripts -eq $true -or $is_dbobjects -eq $true )
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
		Set-Content -Path $owsysmodule_scriptpath "PRINT 'Processing OwSysModule insert'`rINSERT INTO [dbo].[OwSysModule]([ModuleName],[InstalledFlag],[VersionNo],[ObjectType],[UpdateDate]) VALUES ('CORE',1,'$BuildNumber','CombinePackage',GETDATE())`r"
    
		Write "--- Update OWSysModule Script : $owsysmodule_scriptpath written successfully!" | Tee-Object $OutputLogFile -Append

        #Copy OWSysModule and GrantPermissions to Destination Folder
        Copy-Item -Path $grantpermission_scriptpath -Destination $DestinationFolder
        Copy-Item -Path $owsysmodule_scriptpath -Destination $DestinationFolder

        Create-OWCombinePackage -PackageName $PackageName -ScriptsFolder $DestinationFolder -Container $Container | 
            Tee-Object $OutputLogFile -Append
		
		#Set Read-Only Attributes on the Files if any
		Set-ItemProperty $owsysmodule_scriptpath -Name IsReadOnly $true
		Set-ItemProperty $grantpermission_scriptpath -Name IsReadOnly $true

        Write "==== Packaging $ProductName Complete =====" | Tee-Object $OutputLogFile -Append

   }else{
        
        Write "==== No Incremental Scripts found: Combine Package Ignored ===" | Tee-Object $OutputLogFile -Append

   }
