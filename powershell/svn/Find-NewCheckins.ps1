<#
.Synopsis
   Checks for a new changes since the last succesful build
.DESCRIPTION
   This script is best run on a schedule (windows task scheduler)
   Finds any checkins made into svn since the last successful build.
.EXAMPLE
   Find-NewCheckins.ps1 -ProjectName Platform -ReleaseName "Iberville"
.EXAMPLE
   Find-NewCheckins.ps1 -ProjectName Archive -ReleaseName "Iberville"
.NOTES
    Author: Praveen Chamarthi
    Create Date: 22 Aug 2014
#>
[CmdletBinding()]
Param(
        # BuildNumber
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("platform","secure","archive","webadmin")]
        [String]$ProjectName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=1)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("GlenValley","Iberville")]
        [String]$ReleaseName

)
function Map-UserToEmail
{
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        # Some usernames in svn doesnt map with AD logins
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [String]$username
    )
    $nm_suffix = "@dev.myserver.com"

    if($username -eq "hans"){
        $u_email="hansg"
    }
    elseif($username -eq "micah"){
        $u_email="micahg"
    }
    elseif($username -eq "rodney"){
        $u_email="rodneyp"
    }
    elseif($username -eq "owen"){
        $u_email="owens"
    }
    elseif($username -eq "thane"){
        $u_email="thaned"
    }
    elseif($username -eq "tanya"){
        $u_email="tatyanac"
    }
    elseif($username -eq "danb"){
        $u_email="danielb"
    }
    elseif($username -eq "archive-build"){
        $u_email="praveenc"
    }
    else{
        $u_email=$username    
    }

    "$($u_email)$($nm_suffix)"
        
}

$valid_project_names = @("platform","archive","secure","webadmin")
$valid_release_names = @("GlenValley","Iberville")

$ProjectName = $ProjectName.ToLower()

if($valid_project_names -notcontains $ProjectName){
    Write "*** Invalid Project Name: ***"
    Write "*** Valid Project Names are: $valid_project_names ***"
    exit 1
}
if($valid_release_names -notcontains $ReleaseName){
    Write "*** Invalid Release Name: ***"
    Write "*** Valid Release Names are: $valid_release_names ***"
    exit 1
}
Write "Checking for Curl.exe ..."
#Check if curl.exe exists on c:\sw folder
if(-not (Test-Path c:\sw\curl.exe)){
    Write "*** Curl.exe is needed to Trigger a build ***"
    Write "--- Make sure you have curl in c:\sw directory"
    exit 1
}

Write "Checking for Send-NMEmail.ps1 ..."
#Check if Send-NMEmail.ps1 exists on c:\sw folder
if(-not (Test-Path c:\buildscripts\Send-NMEmail.ps1)){
    Write "*** Send-NMEmail.ps1 is needed for emailing ***"
    Write "--- Make sure you the script in c:\buildscripts"
    exit 1
}else{
    Write "Adding Send-NMEmail.ps1 to scope ..."
    . .\Send-NMEmail.ps1
}

Write "Checking for mail_securestring.txt ..."
#Check if Send-NMEmail.ps1 exists on c:\sw folder
if(-not (Test-Path c:\buildscripts\mail_securestring.txt)){
    Write "*** mail_securestring.txt is needed for emailing ***"
    Write "--- Make sure you the script in c:\buildscripts"
    exit 1
}


#SVN Repository paths
$svn_root="svn+ssh://svn.myserver.com/netmail"
$svn_branch="trunk"
$svn_tag_root="svn+ssh://svn.myserver.com/netmail/tags"
$nm_releasename=$ReleaseName
$nm_projects=$ProjectName

Write-Output "Extracting Previous successful revision from tags branch ..."

#Foreach project query the last revision from tags branch and current revision from trunk
#Extract detailed log info and write into xml
#Use xpath to query log info and send email to authors
    
    Write "--- Querying $ProjectName ..."
    $prev_rev = Invoke-Expression -Command "svn log $svn_tag_root/$ReleaseName/$ProjectName -l 1" 
    $prev_rev = $prev_rev | % {if( $_ -match '^r\d{6}'){ $_ -replace '\s\|.*$',''}}
    Write " $ProjectName Prev: $prev_rev"

    $build_rev = Invoke-Expression -Command "svn log $svn_root/$svn_branch/$ProjectName -l 1"
    $build_rev = $build_rev | % {if( $_ -match '^r\d{6}'){ $_ -replace '\s\|.*$',''}}
    Write " $ProjectName Committed: $build_rev"

    Write " Extracting logs to $($ProjectName)_log.xml"
    $filen = "$($ProjectName)_log.xml"
    Invoke-Expression -Command "svn log $svn_root/$svn_branch/$proj -r $($prev_rev):$($build_rev) -v --xml" | Out-File $filen

    $changes_count = (Select-Xml -Path .\platform_log.xml -XPath "//log").Node.SelectNodes("logentry").Count
    
    Write " Found $changes_count Changes ..."

    if($changes_count -gt 0){

        $trigger_build="curl -X POST localhost:8080/job/Trunk_Platform_Win/build"
        Write "Triggering build for Trunk_Platform_Win using curl .."
        Invoke-Expression -Command "c:\sw\curl.exe -X POST localhost:8080/job/Trunk_Platform_Win/build"
        $authors = (Select-Xml -Path $filen -XPath "//logentry/author").Node.InnerText | Select -Unique
        [String[]]$to_list = @()
        foreach($a in $authors){
            #Maps user names in svn to email addressess
            $to_list += (Map-UserToEmail $a)
        }
        $logs = (Select-XML -Path $filen -XPath "//logentry").Node
        $email_text=""
        foreach($l in $logs){
        
            $rev = $l.revision
            $author = $l.author
            $msg = $l.msg.TrimStart()
            $msg = $msg.TrimEnd()
            $paths = $l.paths
            $fils = ""
            #Paths can contain multiple path objects
            if($paths.path.Count -gt 1){
                foreach($sp in $paths.path){
                    $kind = $sp.action
                    $fils +="`t$kind`t$($sp.'#text')`r`n"
                }
            }else{
                $kind = $paths.path.action
                $fils = "`t$kind`t$($paths.path.'#text')`r`n"
            }
            $email_text +=@"

`t--------------------------------------------------`r
`t$msg`r
`t--------------------------------------------------`r
`tAuthor: $author`t`tRevision: $rev

`tFiles: `r
$fils`r

"@
        }
}else{

    Write "-- No checkins found .. Sleeping for the next hour "

}

Write "Email: $email_text" | Out-File ./email_text.txt



#Send-NMEmail -FromAddress "PlatformWinBuilds@10_10_23_146.com" -ToAddress $to_list -Subject "Platform(Win) Build Summary" -Body $email_text
