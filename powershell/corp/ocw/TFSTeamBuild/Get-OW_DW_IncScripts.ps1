Param(
    <#
    .Synopsis
       Scan provided DW Source folder for Incremental DBscripts and package them to CombinePackage
    .DESCRIPTION
       This script will scan Datawarehouse source folder for any Incremental Scripts
       Creates combine package by recursivley adding files, folders to
       Package. First Creates Package then adds folders and files recursively.
    .PARAMETER BranchName
        Name of the Branch e.g. $/Bridge/mainline/Datawarehouse
    .PARAMETER BuildNumber
        Build Number e.g. 2.2.0.71
    .PARAMETER LogDirectory
        Log Directory e.g E:\Builds\OWBridge\2.2\2.2.0.71\log
    .EXAMPLE
       Get-OW_DW_IncDBScripts -BranchName $/Bridge/mainline/Datawarehouse -BuildNumber '2.2.0.71' -LogDirectory 'E:\Builds\OWBridge\2.2\2.2.0.71\log'
    .NOTES
        Author: Praveen Chamarthi
        Date: 07 June 2013
    #>

    
    [CmdletBinding()]
    [Parameter(Mandatory=$true,
               Position=0,
               HelpMessage="TFS Branch name e.g. $/Bridge/mainline/Datawarehouse")]
    [ValidatePattern("\$\/(.*?)\/(.*)")]
    [String]$BranchName,

    [Parameter(Mandatory=$true,
               Position=1,
               HelpMessage="Build Number")]
    [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{1,3}")]
    [String]$BuildNumber,

    [Parameter(Mandatory=$true,
               Position=2,
               HelpMessage="Log Dir Path")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [String]$LogDirectory,

    [Parameter(Mandatory=$false,
               Position=3,
               HelpMessage="Container Name to be set for the Package")]
    [ValidateNotNullorEmpty()]
    [String]$Container="Bridge_BETAQA",

    [Parameter(Mandatory=$false,
               Position=4,
               HelpMessage="Build Output Dir Root e.g. E:\Builds")]
    [String]$BuildOutputDirectory="E:\Builds\OWBridge"


)

    #Load Common Functions from Library - Scrub-OWScripts, Create-OWCombinePackage
    . .\OW-CMTools.ps1

    #Set Working Directory to Current Directory
    [Environment]::CurrentDirectory=(Get-Location -PSProvider FileSystem).ProviderPath

    #Set path to GrantPermissions and Update_OWSYSMODULE
    $grantpermission_scriptpath = [IO.Directory]::GetCurrentDirectory() + "\GrantPermissions.sql"
    $owsysmodule_scriptpath = [IO.Directory]::GetCurrentDirectory() + "\Update_OWSYSMODULE.sql"

    #Remove Read-Only Attributes on the Files if any
    Set-ItemProperty $owsysmodule_scriptpath -Name IsReadOnly $false
    Set-ItemProperty $grantpermission_scriptpath -Name IsReadOnly $false


     #Generate Short Build Number & Release Number
     [Array]$numbersplit = $BuildNumber.split(".")
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
     
    #Extract Product Name
    $ProductName = $BranchName.Split("/")[1]
     
    If($BranchName -match 'Source'){
        $fldrName = 'Source'
    }elseif ($BranchName -match 'Destination') {
        $fldrName = 'Destination'
    }
    
    $OutputLogFile = "$LogDirectory\$BuildNumber.Datawarehouse.Package.Get-OW_DW_IncDBScripts.log"
    
    #Create Log Folder if doesn't exist
    If((Test-Path $OutputLogFile -PathType Leaf) -eq $false){

        mkdir (Split-Path $OutputLogFile) | Out-Null

    }
    
    #Load TF Services - VersionControl service to Download File
    $tfserver = "http://prg2tfa1:8080/tfs"
    $tfvcs = (Get-TfsServer -Name $tfserver).GetService('Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer')
    
    #Name of Farm Combine Package
    $PackageName = "$BuildNumber.cpa"

    #Write "--- Build Number: $buildnumber, Build Date: $lastbuilddate"
    Write "=== Datawarehouse : Get Source Scripts =====" | Tee-Object $OutputLogFile -Append
    $DWTFSPath = "$BranchName/Source"
    $DestinationFolder = "$BuildOutputDirectory\$releasenumber\$BuildNumber\Database\Datawarehouse\Source\$BuildNumber"
    $Container = "Bridge_BETAQA"
    

    #Dowload & Package DWSource Objects
    try{
        
        [Array]$dwresult = Get-TfsChildItem $DWTFSPath -Recurse -Server (Get-TfsServer -Name $tfserver) | 
                    Select ServerItem

        foreach($item in $dwresult){
            
            [String]$serveritem = $item.ServerItem
            [String]$filename = Split-Path $serveritem -Leaf

            #Download only if its a file           
            If($filename -match '.sql'){
                
                #Split path to Gather Dir name    
                [String]$parentstring = Split-Path $serveritem -Parent
                [Array]$dirarr = $parentstring.Split("\")
                [String]$dirname = $dirarr[($dirarr.Count)-1]

                #Construct Destination Path for the file to dowload
                [String]$DestinationFile = "$DestinationFolder\$dirname\$filename"

                Write "--- Downloading $filename" | Tee-Object $OutputLogFile -Append
                $tfvcs.DownloadFile($serveritem, $DestinationFile)
            
                #ScrubScripts after Download
                Scrub-OWScripts -FileToScrub "$DestinationFile" | Tee-Object $OutputLogFile -Append
           }
          
        }

        #Write Update_OWSysModule.SQL with Current Build Number
        Set-Content -Path $owsysmodule_scriptpath "PRINT 'Processing OwSysModule insert'`rINSERT INTO [dbo].[OwSysModule]([ModuleName],[InstalledFlag],[VersionNo],[ObjectType],[UpdateDate]) VALUES ('BridgeDWSource',1,'$BuildNumber','CombinePackage',GETDATE())`r"
        
        Write "--- Update OWSysModule Script : $owsysmodule_scriptpath written successfully!" | Tee-Object $OutputLogFile -Append

        #Copy OWSysModule and GrantPermissions to Destination Folder
        Copy-Item -Path $grantpermission_scriptpath -Destination $DestinationFolder
        Copy-Item -Path $owsysmodule_scriptpath -Destination $DestinationFolder

        #Create Combine Package 
        Create-OWCombinePackage -PackageName $PackageName -ScriptsFolder $DestinationFolder -Container $Container | 
                Tee-Object $OutputLogFile -Append

        Write "==== Datawarehouse Source Package Created =====" | Tee-Object $OutputLogFile -Append

    }catch{
        
        Write-Warning "Error getting $DWTFSPath : " + $_.Exception.Message -Verbose
        Write "Error getting $DWTFSPath" | Tee-Object $OutputLogFile -Append

    }

    #Dowload & Package DW Destination Objects
    Write "=== Datawarehouse : Get Destination Scripts =====" | Tee-Object $OutputLogFile -Append
    $DWTFSPathDest = "$BranchName/Destination"
    $DestinationFolder = "$BuildOutputDirectory\$releasenumber\$BuildNumber\Database\Datawarehouse\Destination\$BuildNumber"
    $Container = "BridgeCognos_Destination_BETAQA"

    try{
        
        [Array]$dwdestresult = Get-TfsChildItem $DWTFSPathDest -Recurse -Server (Get-TfsServer -Name $tfserver) | 
                    Select ServerItem

        foreach($item in $dwdestresult){
            
            [String]$serveritem = $item.ServerItem
            [String]$filename = Split-Path $serveritem -Leaf

            #Download only if its a file           
            If($filename -match '.sql'){
                
                #Split path to Gather Dir name    
                [String]$parentstring = Split-Path $serveritem -Parent
                [Array]$dirarr = $parentstring.Split("\")
                [String]$dirname = $dirarr[($dirarr.Count)-1]

                #Construct Destination Path for the file to dowload
                [String]$DestinationFile = "$DestinationFolder\$dirname\$filename"

                Write "----- Downloading $filename" | Tee-Object $OutputLogFile -Append
                $tfvcs.DownloadFile($serveritem, $DestinationFile)
            
                #ScrubScripts after Download
                Scrub-OWScripts -FileToScrub "$DestinationFile" | Tee-Object $OutputLogFile -Append
           }
          
        }

        #Write Update_OWSysModule.SQL with Current Build Number
        Set-Content -Path $owsysmodule_scriptpath "PRINT 'Processing OwSysModule insert'`rINSERT INTO [dbo].[OwSysModule]([ModuleName],[InstalledFlag],[VersionNo],[ObjectType],[UpdateDate]) VALUES ('BridgeDWDestination',1,'$BuildNumber','CombinePackage',GETDATE())`r"
        Write "--- Update OWSysModule Script : $owsysmodule_scriptpath written successfully!" | Tee-Object $OutputLogFile -Append

        Copy-Item -Path $owsysmodule_scriptpath -Destination $DestinationFolder

        #Create Combine Package 
        Create-OWCombinePackage -PackageName $PackageName -ScriptsFolder $DestinationFolder -Container $Container | 
                Tee-Object $OutputLogFile -Append

        Write "==== Datawarehouse Destination Package Created =====" | Tee-Object $OutputLogFile -Append

    }catch{
        
        Write-Warning "Error getting $DWTFSPath : " + $_.Exception.Message -Verbose
        Write "Error getting $DWTFSPath" | Tee-Object $OutputLogFile -Append

    }

    #Revoke Read-Only Attributes on the Files if any
    Set-ItemProperty $owsysmodule_scriptpath -Name IsReadOnly $true
    Set-ItemProperty $grantpermission_scriptpath -Name IsReadOnly $true
