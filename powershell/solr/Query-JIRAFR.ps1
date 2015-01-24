#=====================================
#Scavenge through JQL results and create a dictionary object of all issues, linked issues
#Use this HashTable of issues to then Download Attachments
#Author: Praveen Chamarthi
#Create Date: 27 Dec 2014
#=====================================
$myb64 = "ENTER 64bit encoded password string here"
$jirabaseurl = "http://jira.myserver.com:portno/"
$headers = @{"Authorization"="Basic $myb64";
             "Content-Type"="application/json";
             "charset"="UTF-8"}
$dest_folder = "F:\SOLR\DocsToIndex\JIRA\FR"
#$skip_count = 0
#$download_count = 0

#Query Single JIRA Issue: http://jira.myserver.com/rest/api/latest/issue/AB-7124
#Query a JQL result set (using POST): http://jira.myserver.com/rest/api/latest/search
#$jql = "jql=project%20%3D%22Product%20Enhancements%22%20and%20type%20in%20(%22User%20Story%22%2C%20%22Change%20Request%22)&maxResults=-1"

if(-not(Test-Path .\Download-AttachmentsFromJIRA.ps1))
{
    Write "Script Download-AttachmentsFromJIRA.ps1 is required - exiting ..."
    exit 1

}else{
    . .\Download-AttachmentsFromJIRA.ps1
}

function create-ticketdictionary
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$jql
    )
    
    $issues_url = "http://jira.myserver.com/rest/api/latest/search?$jql"
    #As the response object could be more than 50 records, we need to set the MaxJSONLength
    [System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null
    $serialize_obj = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $serialize_obj.MaxJsonLength = "50000000"
    $resp = (Invoke-WebRequest -Headers $headers -Uri $issues_url).Content

    $resp = $serialize_obj.DeserializeObject($resp)

    $tickets = $resp.issues

    Write "`tFound $($tickets.Count) JIRA tickets ..."

    foreach($ticket in $tickets)
    {
        $t_num = $ticket.key
        $t_url = $ticket.self

        if(-Not $jira_all_issues.ContainsKey($t_num))
        {
            $jira_all_issues.Add($t_num, $t_url)
        }
        else{
            Write "$t_num already in dictionary"
            continue
        }

        #Now download all attachments from all the linked issues as well
        $issue_links = $ticket.fields.issuelinks.self

        if($issue_links.Count -ge 1)
        {
            Write "$t_num : $($issue_links.Count) Links"
            #Write "`tFound $($issue_links.Count) linked issues ..."

            foreach($il in $issue_links)
            {

                $il_json = (Invoke-WebRequest -Headers $headers -Uri $il).Content | ConvertFrom-JSON
                #$t_url = $il_json.inwardIssue.self
                $iss_num = $il_json.inwardIssue.key
                if($iss_num -eq $t_num)
                {
                    $iss_num = $il_json.outwardIssue.key
                }
                Write "`tLinked Issue: $iss_num"
                $t_url = "http://jira.myserver.com/rest/api/latest/issue/$iss_num"
            
                if(-Not $jira_all_issues.ContainsKey($iss_num))
                {
                    $jira_all_issues.Add($iss_num, $t_url)

                }else{
                    Write "`t$iss_num already in dictionary"
                }
            
            }
            #    $jira_all_issues
    
        }
    }

    Return $jira_all_issues
}


#-- A bit twisted but we need to run JQL twice to get more than 1000 issues
Write "Processing first batch ..."
# first you need to run the query in JIRA and get the total no of tickets resulted from your query - if more than 1000 results then split
# In this case, total results were around 1200+ so decided to query by updatedate desc and get the first 1000
# Then re-execute query with updatedate ASC with maxresults set to 300
$jql = "jql=project %3D FR and type in (""User Story""%2C""Feature Request""%2C""Change Request"") ORDER BY updatedDate DESC&maxResults=-1"
$h1 = create-ticketdictionary -jql $jql

Write "`tFirst batch has : $($h1.Count)"

Write "Processing second batch ..."

$jql = "jql=project %3D FR and type in (""User Story""%2C""Feature Request""%2C""Change Request"") ORDER BY updatedDate ASC&maxResults=200"
$h2 = create-ticketdictionary -jql $jql

Write "`tSecond batch has : $($h2.Count)"

#Best thing about Dictionary objects is that you can join them using + operator - uniqueness of keys is taken care of.
$h1 += $h2

Write "After Dictionary merge: $($h1.Count)"

#Download Attachments for each ticket in the Dictionary
foreach($iss in $h1.Values)
{
    #$iss
    Download-AttachmentsFromJIRA -jiraticketurl $iss -downloadfolderpath $dest_folder -b64hash $myb64

}

