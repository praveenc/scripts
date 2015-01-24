<#
.Synopsis
   Appreciate, Blame Authors based on build success/failure
.DESCRIPTION
   Post build, this script will notify developers, on their checkins, and the affect of their checkins.
   If a checkin was made and the build was successful, the developer will be informed.
   If build is failing, then all the developers, that made check-ins since last successful build will be notified.
.EXAMPLE
   Blame-SVNAuthors.ps1 -BuildNumber 5.3.0.1432
.EXAMPLE
   Blame-SVNAuthors.ps1 -BuildNumber 5.3.1.45
.NOTES
    Author: Praveen Chamarthi
    Date Created: 01 Aug 2014
    Date Modified: 12 Aug 2014
#>
[CmdletBinding()]
Param(
        # BuildNumber
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("\d\.\d\.\d\.\d{2,4}")]
        [String]$BuildNumber
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

#Check if mail_securestring.txt exists - if not exit
If(-not (Test-Path .\mail_securestring.txt)){
    Write "*** Cannot Find mail_securestring.txt ***"
    exit 1
}

#SVN Repository paths
$svn_root="svn+ssh://svn.myserver.com/netmail"
$svn_branch="trunk"
$svn_tag_root="svn+ssh://svn.myserver.com/netmail/tags"
$nm_releasename="Iberville"
$nm_projects=@("platform","archive","secure","webadmin")

#EMAIL Stuff
#$smtpserver = "10.200.1.80"
$from = "Builds@BuildMaster.com"
$to = "praveenc@netmail.com"
$smtp_user="buildmachine"
$smtp_pass= cat .\mail_securestring.txt | ConvertTo-SecureString
$smtp_cred = New-Object System.Management.Automation.PSCredential -ArgumentList $smtp_user, $smtp_pass
$Subject = "-- Build $BuildNumber Blame Summary--"
$EMAIL_BODY=@"
Dear developer,`r`n
`tBuild ${buildnumber} failed!`r
`tCheck Netmail_trunk jenkins build log for error details http://10.10.23.159:8070/job/Netmail_Trunk/lastBuild/console`r
`n
`tThis email is being sent to you because you have made commits since the last successful build.`r
`tPlease check the build error log to verify if the commits are the cause for the failure`r
`r`n
`t==== PLATFORM checkins =====`r`n
`t[PLATFORM]
`n    
`t==== ARCHIVE checkins =====`r`n
`t[ARCHIVE]`r
`t==== SECURE checkins =====`r`n
`t[SECURE]`r
`t==== WEBADMIN checkins =====`r`n
`t[WEBADMIN]`r`n
`r`n
Yours Sincerely,
Build Master
"@


Write-Output "Extracting Previous successful revision from tags branch ..."

#Foreach project query the last revision from tags branch and current revision from trunk
#Extract detailed log info and write into xml
#Use xpath to query log info and send email to authors
$to_list = ""
foreach($proj in $nm_projects){
    
    Write "--- Querying $proj ..."
    $prev_rev = Invoke-Expression -Command "svn log $svn_tag_root/$nm_releasename/$proj -l 1" 
    $prev_rev = $prev_rev | % {if( $_ -match '^r\d{6}'){ $_ -replace '\s\|.*$',''}}
    Write " $proj Prev: $prev_rev"

    $build_rev = Invoke-Expression -Command "svn log $svn_root/$svn_branch/$proj -l 1"
    $build_rev = $build_rev | % {if( $_ -match '^r\d{6}'){ $_ -replace '\s\|.*$',''}}
    Write " $proj Committed: $build_rev"

    Write " Extracting logs to $($proj)_log.xml"
    $filen = "$($proj)_log.xml"
    Invoke-Expression -Command "svn log $svn_root/$svn_branch/$proj -r $($prev_rev):$($build_rev) -v --xml" | Out-File $filen

    #Get log details
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
Author: $author`t`tRevision: $rev
`t--------------------------------------------------
`tFiles: `r
$fils`r
`tMessage: $msg`r
"@

}

    $authors = (Select-Xml -Path $filen -XPath "//logentry/author").Node.InnerText | Select -Unique
    
    #Send-MailMessage uses String array for Recipient List, so create one
    [String[]]$to_list = @()
    foreach($a in $authors){
        #Maps user names in svn to email addressess
        $to_list += (Map-UserToEmail $a)
    }

    #Replace placeholders in email body with email_text
    $placeholder_text = "[" + $($proj).ToUpper() + "]"
    $esc = [System.Text.RegularExpressions.Regex]::Escape($placeholder_text)
    $EMAIL_BODY = $EMAIL_BODY -replace "$esc",$email_text

}

$EMAIL_BODY | Out-File ./email.txt
$to_list = $to_list | Select -Unique
Write-Output "Email will be sent to: $to_list"

Write-Output "Actual Email to: $to"
Send-MailMessage -SmtpServer "10.200.1.80" -Port 587 -UseSsl -Credential $smtp_cred -From $from -To $to -Subject $Subject  -Body $EMAIL_BODY
