$ErrorActionPreference = 'Stop'
$hostname = $env:COMPUTERNAME
$hudson_jobname = "{job_name}"
$buildfolder_root = "\\{fileserve_ip}\Builds\$hudson_jobname"
if($hostname -ne "OSIRIS" ){#

    Write-Output "*** This script can be run only on Admins Machine. Exiting..."
    exit 1
}    

#$failedbuilds_uri = "http://jenkinsurl/rssFailed"
$allbuilds_rss = "http://{jenkinsip}:{port}/job/{job_name}/rssAll"
$releasenumber = "5.3.0"
[Array]$failedbuild_folders = @()
[Array]$stablebuild_folders = @()
#Load SyndicationFeed class to Consume RSS Feed
[System.Reflection.Assembly]::LoadWithPartialName("System.ServiceModel") | Out-Null
[System.ServiceModel.Syndication.SyndicationFeed] $feed = [System.ServiceModel.Syndication.SyndicationFeed]::Load([System.Xml.XmlReader]::Create($allbuilds_rss))
$feeditems = $feed.Items
#$feeditems

foreach ($item in $feeditems){

    $title = $item.Title.text
    #$title
    if ($title -match '#(\d{4})\s\((aborted|broken)'){
        $failed_buildnumber = $Matches[1]
        $failed_buildnumber = "$releasenumber.$failed_buildnumber"
        $failedbuild_folders += "$buildfolder_root\$failed_buildnumber"
    }
    if ($title -match '#(\d{4})\s\((stable|back)'){
        $stable_buildnumber = $Matches[1]
        $stable_buildnumber = "$releasenumber.$stable_buildnumber"
        $stablebuild_folders += "$buildfolder_root\$stable_buildnumber"
    }


}

Write "Failed Build Folders.."
#$failedbuild_folders
$failedli = ""
$failedbuild_folders | % { $failed_li += "<li>$_</li>" }


Write "Latest (5) Stable Build Folders.."
[System.Array]::Sort($stablebuild_folders)
$stablebuild_folders[5..10] | % { $stable_li += "<li>$_</li>" }
#Write "Older (5) Stable Builds (can be deleted) ***"
$stablebuild_folders = $stablebuild_folders[0..5]
$stablebuild_folders

$failedbuild_folders| % {
    If(Test-Path $_ ){ 
        Write "Found Failed Build Folder: $_"
        $deleted += "<li>$_ </li>"
        Remove-Item -Path $_
    }
}

$stablebuild_folders| % { 
    if(Test-Path $_){
        Write "Found Older Stable Build : $_"
        $deleted += "<li>$_ </li>"
        Remove-Item -Path $_
    }
}

$smtpserver = "xxxxxxx"
$from = "Janitor@BuildMachine.com"
$to = "praveenc@xxxxx.com"
$Subject = "Netmail_Trunk Builds = Folder Cleanup"
if($deleted){
    #$Subject = "Netmail_Trunk Build Folders"
    $body = @"
        <html>
        <head>
            <title>Build Folder Cleanup</title>
        </head>
        <body>
            <h1>Deleted Folders: </h1><br>
            <ul>$deleted</ul>
            <hr/>
            <h2>Failed Build Folders<h2><br>
            <ul>$failed_li</ul>
            <hr/>
            <h2>Stable Build Folders<h2><br>
            <ul>$stable_li</ul>
        </body>
        </html>
"@
}else{
    $body = @"
        <html>
        <body>
            <h2>No Folders were deleted under $buildfolder_root</h2>
            <hr/>
            <h3>Failed Build Folders<h3><br>
            <ul>$failed_li</ul>
            <hr/>
            <h3>Stable Build Folders<h3><br>
            <ul>$stable_li</ul>
            <em>Yippee!!</em>
        </body>
        </html>
"@
}
Write "Emailing Stats to Praveen..."
Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject $Subject -Body $body -BodyAsHtml
