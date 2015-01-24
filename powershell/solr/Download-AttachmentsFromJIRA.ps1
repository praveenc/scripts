<#
.Synopsis
   Downloads all attachments from a JIRA ticket
.DESCRIPTION
   Downloads all attachments (except ZIP and Images) from JIRA ticket using JIRA's REST API
   Data is returned in JSON format.Files are downloaded using Invoke-WebRequest's -OutFile parameter
   username:password should be base64 encoded (http://base64decode.net/) and passed into b64hash variable
   JIRA authentication method used here are Basic (see headers object in code below)
.EXAMPLE
   Download-AttachmentsFromJIRA -jiraticketurl 'http://jira.myserver.com/rest/api/latest/issue/NM-7124' -downloadfolderpath F:\JIRA -b64hash
.EXAMPLE
   Another example of how to use this cmdlet
.NOTES
   Author: Praveen Chamarthi
   Create Date: 01-Jan-2015
.ROLE
   Download Files from Internet/Intranet
.FUNCTIONALITY
   Download Files from Internet/Intranet
#>
function Download-AttachmentsFromJIRA
{
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        # JIRA Ticket REST API URL e.g. http://jira.myserver.com/rest/api/latest/issue/NM-1243
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String]$jiraticketurl,

        # Folder Path to download attachment
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String]$downloadfolderpath,

        # BASE64 encoded username:password
        [Parameter(Mandatory=$true,Position=2)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String]$b64hash

    )

    
    #Define Headers object
    $headers = @{"Authorization"="Basic $b64hash";
               "Content-Type"="application/json";
                "charset"="UTF-8"}

    $resp = (Invoke-WebRequest -Headers $headers -Uri $jiraticketurl).Content
    $resp  = $resp | ConvertFrom-Json
    
    #Attachment object contains list of all attachments in the ticket
    $t_num = $resp.key
    $attachments = $resp.fields.attachment
    $downloadfolderpath = [System.IO.Path]::Combine($downloadfolderpath, $t_num)

    if($attachments.Count -ge 1)
    {
        
        Write "`t$t_num has $($attachments.Count) attachments ..."
        #Check if folder exist on disk
        if(Test-Path $downloadfolderpath -PathType Container)
        {
            Write "`t$t_num already exists on disk"
        }
        else
        {
            New-Item -Path $downloadfolderpath -ItemType directory | Out-Null            
        }     
        #Download each attachment
        foreach($fil in $attachments)
        {
            $mimeType = $fil.mimeType
            $filename = $fil.filename

            $s_extension = [System.IO.Path]::GetExtension($filename)
            if($s_extension -match 'json')
            {
                $mimeType = 'json'
            }
            if($s_extension -match 'msg')
            {
                $mimeType = 'msg'
            }
            #Attachment URL is in the content field in the attachment object
            $a_url = $fil.content

            #Ignore image and zip attachments
            if($mimeType -notmatch '(zip|msdownload|msg)')
            {
            
                #If it's a text attachment then gather assignee name
                if($mimeType -match '(text|image|json)')
                {
                    $author = $resp.fields.assignee.displayName
                }
                #Create FQ Path Name to download file
                $f_path = [System.IO.Path]::Combine($downloadfolderpath, $filename)
            
                if(-not(Test-Path $f_path -PathType Leaf))
                {
                    Write "`t`tDownloading $mimeType - $filename ..."
                    Invoke-WebRequest -Headers $headers -Uri $a_url -OutFile $f_path
            
                    #Write ticket metadata to metadata.json file
                    #This file will be used by SOLR transformer scripts to fill in fields
                    #Write "`tWriting metadata to $($resp.key).json ..."
                    #$json_filepath = [System.IO.Path]::Combine($downloadfolderpath, $resp.key, ".json")
                    #$resp | Out-File $json_filepath

                }
        
            }
        
        }
    }
    else{
        Write "`t$t_num has no attachments"
    }
}
