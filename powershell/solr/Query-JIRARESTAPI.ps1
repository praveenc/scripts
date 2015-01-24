#=====================================
#Author: Praveen Chamarthi
#Create Date: 22 Dec 2014
#=====================================
$myb64 = "enter 64bit encoded passwordstring here""

$headers = @{"Authorization"="Basic $myb64";
             "Content-Type"="application/json";
             "charset"="UTF-8"}
$dest_folder = "F:\SOLR\DocsToIndex\JIRA\FR"
$skip_count = 0
$download_count = 0

#Query Single JIRA Issue: http://jira.myserver.com/rest/api/latest/issue/NM-7124
#Query a JQL result set (using POST): http://jira.myserver.com/rest/api/latest/search
#curl -D- -u admin:admin -X POST -H "Content-Type: application/json" --data '{"jql":"project = QA","startAt":0,"maxResults":2,"fields":["id","key"]}' "http://jira.myserver.com/rest/api/latest/search"

if(-not(Test-Path .\Download-AttachmentsFromJIRA.ps1))
{
    Write "Script Download-AttachmentsFromJIRA.ps1 is required - exiting ..."
    exit 1

}else{
    . .\Download-AttachmentsFromJIRA.ps1
}

#$jql = "jql=project+%3D+FR+and+attachments+is+not+EMPTY&maxResults=100"
$jql = "jql=project%20%3D%22Product%20Enhancements%22%20and%20type%20in%20(%22User%20Story%22%2C%20%22Change%20Request%22)&maxResults=-1"
$issues_url = "http://jira.myserver.com/rest/api/latest/search?$jql"

#As the response object could be more than 50 records, we need to set the MaxJSONLength
[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null
$serialize_obj = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$serialize_obj.MaxJsonLength = "50000000"

$resp = (Invoke-WebRequest -Headers $headers -Uri $issues_url).Content
#$resp = $resp | ConvertFrom-Json
$resp = $serialize_obj.DeserializeObject($resp)

#Display all issue links
$tickets = $resp.issues

Write "Found $($tickets.Count) JIRA tickets matching JQL $jql"

#For each ticket download attachments
foreach($ticket in $tickets)
{
    $t_num = $ticket.key
    $t_url = $ticket.self
    Write "Analysing http://jira.myserver.com/browse/$t_num ..."
    
    #First Download all attachments in this ticket    
    $t = [System.IO.Path]::Combine($dest_folder,$t_num)
    Download-AttachmentsFromJIRA -jiraticketurl $t_url -downloadfolderpath $t -b64hash $myb64

    #Now download all attachments from all the linked issues as well
    $issue_links = $ticket.fields.issuelinks.self

    if($issue_links.Count -ge 1)
    {
        Write "`tFound $($issue_links.Count) linked issues in ticket $t_num ..."
        foreach($il in $issue_links)
        {

            $il_json = (Invoke-WebRequest -Headers $headers -Uri $il).Content | ConvertFrom-JSON
            #$t_url = $il_json.inwardIssue.self
            $iss_num = $il_json.inwardIssue.key
            if($iss_num -eq $t_num)
            {
                $iss_num = $il_json.outwardIssue.key
            }
            Write "`tAnalysing $iss_num for attachments .."
            $t_url = "http://jira.myserver.com/rest/api/latest/issue/$iss_num"
            $t = [System.IO.Path]::Combine($dest_folder,$iss_num)
            Download-AttachmentsFromJIRA -jiraticketurl $t_url -downloadfolderpath $t -b64hash $myb64
            
        }
    
    }

}

