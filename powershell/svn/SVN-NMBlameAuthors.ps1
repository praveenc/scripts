<#
.Synopsis
   Appreciate, Blame Authors based on build success/failure
.DESCRIPTION
   Post build, this script will notify developers, on their checkins, and the affect of their checkins.
   If a checkin was made and the build was successful, the developer will be informed.
   If build is failing, then all the developers, that made check-ins since last successful build will be notified.
.EXAMPLE
   SVN-NMBlameAuthors.ps1 -BuildNumber 5.3.0.1432
.EXAMPLE
   SVN-NMBlameAuthors.ps1 -BuildNumber 5.3.1.45
.NOTES
    Author: Praveen Chamarthi
    Date: 01 Aug 2014
#>

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
    }else{
        $u_email=$username    
    }

    "$($u_email)$($nm_suffix)"
        
}

#SVN Repository paths
$svn_root="svn+ssh://svn.myserver.com/netmail"
$svn_branch="trunk"
$svn_tag_root="svn+ssh://svn.myserver.com/netmail/tags"
$nm_releasename="Iberville"
$nm_projects=@("platform","archive","secure","webadmin")

#EMAIL Stuff
$smtpserver = "10.200.1.80"
$from = "Praveen@BuildMaster.com"
$to = "praveenc@netmail.com"
$Subject = "--Build Blame Summary--"
$EMAIL_BODY=@"
Dear developer,
	
	Build ${buildnumber} failed!
	Check Netmail_trunk jenkins build log for error details http://10.10.23.159:8070/job/Netmail_Trunk/lastBuild/console
	
	This email is being sent to you because you have made commits since the last successful build.
    Please check the build error log to verify if the commits are the cause for the failure
	
    ==== PLATFORM checkins =====
    [PLATFORM]
    
    
    ==== SECURE checkins =====
    [SECURE]
    
    
    ==== WEBADMIN checkins =====
    [WEBADMIN]
    
    
    ==== ARCHIVE checkins =====
    [ARCHIVE]
    
	
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

    foreach($l in $logs){
        
        $rev = $l.revision
        $author = $l.author
        $msg = $l.msg
        $paths = $l.paths
        $fils = ""
        foreach($p in $paths){
            $fils += "`t" + $($p.InnerText) + "`r`n"
        }


        $email_text =@"
Author: $author   --- Revision: $rev
    ------------------------------
    Files:
        $fils
"@

    
    }


    #Get svn path from log info so that you can exclude some non-important ones e.g. Test Automation
    #$paths = (Select-Xml -Path $filen -XPath "//logentry/paths").Node.ChildNodes

    #foreach($p in $paths){

    #   if($p -notmatch "Test Automation"){

    #       $email_text = (Select-Xml -Path $filen -XPath "//logentry").Node.InnerText

    #   }

    #}
    $authors = (Select-Xml -Path $filen -XPath "//logentry/author").Node.InnerText | Select -Unique
    
    #Maps user names in svn to email addressess
    foreach($a in $authors){

        $to_list += (Map-UserToEmail $a) +";"

    }


    #Replace placeholders in email body with email_text
    $placeholder_text = "[" + $($proj).ToUpper() + "]"
    $esc = [System.Text.RegularExpressions.Regex]::Escape($placeholder_text)
    $EMAIL_BODY = $EMAIL_BODY -replace "$esc",$email_text
  

}

$to_list
$EMAIL_BODY

Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject $Subject -Body $EMAIL_BODY
