<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Valid Hudson Job Name
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateScript({-not ([String]::IsNullOrEmpty($_))})]
        [ValidateSet("Netmail_Trunk","Netmail_GlenValley","5_3_1_BETA3")]
        [String]$HudsonJobName,

        # HudsonServerURI
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidateScript({-not ([String]::IsNullOrEmpty($_))})]
        [ValidateSet("http://10.10.23.159:8070")]
        [String]$HudsonServerURI="http://10.10.23.159:8070",

        # Builds Folder Path
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [ValidateScript({-not ([String]::IsNullOrEmpty($_))})]
        [String]$BuildFolderPath="\\10.10.23.159\Builds\"
    )
    
    $ErrorActionPreference = 'Stop'
    $hostname = $env:COMPUTERNAME
    $BuildFolderPath = "\\10.10.23.159\Builds\$HudsonJobName"
    $build_prefix = "5.3."

    if(-Not (Test-Path .\Fast-Delete.ps1))
    {
        Write-Output "Cannot find Fast-Delete.ps1 in the current directory"
        exit 1

    }else{
        . .\Fast-Delete.ps1
    }


    if($HudsonJobName -match "GlenValley")
    {
        $build_prefix += "0."
    }else {
        $build_prefix += "1."
    }

    # Can only be run from Praveen's machine.
    if($hostname -ne "OSIRIS" )
    {
        Write-Output "*** This script can be run only on Praveens Machine 10.10.3.238. Exiting..."
        exit 1
    }    

    # Verify if builds folder on Buildmachine is accessible
    if( -Not (Test-Path $BuildFolderPath))
    {
        Write-Output "$BuildFolderPath doesn't exist!"
        exit 1

    }else{
 
        #Write "$BuildFolderPath exist .. fetching last 2 good builds"
        if((Test-Path "$BuildFolderPath\lastsuccess.txt") -and (Test-Path "$BuildFolderPath\previoussuccess.txt"))
        {
            $lastgoodbuild = (Get-Content $BuildFolderPath\lastsuccess.txt)
            $prevgoodbuild = (Get-Content $BuildFolderPath\previoussuccess.txt)
            $flds = @($lastgoodbuild,$prevgoodbuild)
            #Write "Fetching folder names ..."
            $folderpaths = Get-ChildItem -Path "$BuildFolderPath" -Directory -Filter "5*" | Select Name, FullName
            $diskflds = @()
            $folderpaths | % {
                $diskflds += $_.Name
            }
            Write-Output "Analyzing $BuildFolderPath ..."
            Write-Output "Build folders on disk for $($HudsonJobName) : $($diskflds.Count)"

        }
    }

    
    #Write "Finding last failed build num ..."
    #Construct JOB URL - get job details in JSON format
    $job_url = "$HudsonServerURI/job/$HudsonJobName/api/json"

    #Test if HudsonJobName exists on Hudson Server
    try { $job_json = Invoke-WebRequest $job_url | ConvertFrom-Json } 
    catch {
        Write-Output "$job_url cannot be reached!"
        exit 1
    }

    $lastfailedbuildnum = $job_json.lastFailedBuild.number
    $lastfailedbuild = "$build_prefix$lastfailedbuildnum"
    $lastgoodbuildnum = $lastgoodbuild -replace [System.Text.RegularExpressions.Regex]::Escape("$build_prefix")

    Write-Output "`tLast 2 good builds: $lastgoodbuild, $prevgoodbuild"
    #Write-Output "Prev good: $prevgoodbuild"
    Write-Output "`tLast Failed Build: $lastfailedbuild"

    Write-Output "Analysing Folders on disk ..."
    $res = Compare-Object -ReferenceObject $flds -DifferenceObject $diskflds

    #If only 2 folders found on disk - they are most likely the last 2 good builds
    if(($($diskflds.Count) -eq 2) -and [String]::IsNullOrEmpty($res) )
    {
        Write-Output "Only 2 build folders exist for $HudsonJobName .. exiting"
        exit 0

    }else{
    
        $extrafolders_count = $res.InputObject.Count
        Write-Output "`tExtra folder(s) on disk: $extrafolders_count"
    
        foreach($fd in $res)
        {
                
            $foldertodelete = $fd.InputObject.Trim()
            Write "Analysing ... $foldertodelete"

            $buildnum = $foldertodelete -replace [Text.RegularExpressions.Regex]::Escape("$build_prefix")
            $foldertodelete =[System.IO.Path]::Combine("$BuildFolderPath","$foldertodelete")

            if(($buildnum -lt $lastgoodbuildnum) -or ($lastfailedbuildnum -gt $buildnum))
            {
                Write "`t$buildnum is an older build ... deleting"
                Fast-Delete -FolderPath $foldertodelete
            }
            if(($buildnum -gt $lastgoodbuildnum))
            {
                if ($buildnum -eq $lastfailedbuildnum)
                {
                    Write "`t$buildnum is an newer build but FAILED ... deleting"
                    Fast-Delete -FolderPath $foldertodelete
                }
                else
                {
                    Write "`t$buildnum is neither OLD nor a FAILED build ... "
                    $build_url = "$HudsonServerURI/job/$HudsonJobName/$buildnum/api/json"
                    $build_url
                    $bjson = Invoke-WebRequest -Uri $buildurl | ConvertFrom-Json
                    $build_status = $bjson.building
                    $user = $bjson.actions.causes.shortDescription
                    if($build_status -eq 'True')
                    {
                        Write "`t$buildnum is currently BUILDING was $user ... skipping"
                    }
                    
                    
                }
            }

        }
    }
