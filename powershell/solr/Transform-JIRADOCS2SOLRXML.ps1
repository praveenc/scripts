<#
.Synopsis
   Parse PDF, Word, Office documents to SOLR readable xml
.DESCRIPTION
   This script assumes that all the attachments in JIRA tickets have been downloaded to a local\shared folder
   All the files in the folders are scanned and all txt, rtf, doc, docx and pdf documents are transformed to SOLR readable xml
   This Script/Program requires tika-app-1.6.jar to be present in the current directory
   Metadata is extracted in JSON format for easy parsing
   Extracted metadata is written to XML 
   Transformed xml will contain standard fields like - id, title, description, author, last_modified, url and content
.EXAMPLE
   Transform-DOCS2XML.ps1 -jiradownloadsfolder E:\JIRA\FR
.NOTES
    Author: Praveen Chamarthi
    Date: 03-Jan-2015
    Modified: 13-Jan-2015
    Comments: Transforms all documents under each FR-xx folder to one xml
#>
[CmdletBinding()]
Param
    (
        # SourceFilePath
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [String] $jiradownloadsfolder,

        # DestinationFilePath
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [String] $DestinationFilePath

    )

    #$ErrorActionPreference = "Stop"
    $tika_jar = "tika-app-1.6.jar"
    $b64hash = "cHJhdmVlbmM6aGFja2VyNjk="
    #Headers required when querying JIRA JSON
    $headers = @{"Authorization"="Basic $b64hash";
               "Content-Type"="application/json";
                "charset"="UTF-8"}

    #The Scripts relies on having apache tika jar to be present in the current directory
    #Download url: http://tika.apache.org/download.html
    #Current Version: 1.6
    #$working_dir = Split-Path ($MyInvocation.MyCommand.Path) -Parent
    #$DestinationFilePath = $working_dir
    $transformed_count = 0
    
    if(-Not (Test-Path .\$tika_jar ))
    {
        Write "Apache Tika ($tika_jar) is required in the same directory as the script"
        Write "You may download tika from http://tika.apache.org/download.html"
        exit 1
    }
        
    #Get all folders names under jiradownloadsfolder
    $fldrs = Get-ChildItem -Path $jiradownloadsfolder -Directory | Select FullName
    
    Write "Found $($fldrs.Count) ..."

    #Scan each folder for attachments, if found transform them into one xml containing multiple <doc>....</doc> nodes
    foreach($fldr in $fldrs)
    {
       #Clear all fields
        $id = ""
        $title = ""
        $subject = ""
        $description = ""
        $content = ""
        $last_modified = ""
        $author = ""
        $doc_type=""
        $jira_url = ""
        $fv_string = ""
        $comp_string = ""

        $fqdn = $fldr.FullName
        $fname = Split-Path $fqdn -Leaf
        $dest_filename = "$fname.xml"
        $dest_filepath = [System.IO.Path]::Combine("$fqdn","$dest_filename")

        #Default values for fields, if metadata exists they get overridden
        $jiraurl = "http://jira.myserver.com/browse/$fname"
        $jirametaurl = "http://jira.myserver.com/rest/api/latest/issue/$fname"
        $jira_json = (Invoke-WebRequest -Headers $headers -Uri $jirametaurl).Content | ConvertFrom-Json
        $subject = $jira_json.fields.summary
        $description = $jira_json.fields.description
        $last_modified = $jira_json.fields.updated
        $author = $jira_json.fields.assignee.displayName
        #Get fixVersion, Components information from JIRA - they could be more than one
        if( $jira_json.fields.fixVersions){
            if($jira_json.fields.fixVersions.Count -eq 1)
            {
                $fv_string = "<field name=""fixversion_ss"">$($jira_json.fields.fixVersions.name)</field>"
            }

            if($jira_json.fields.fixVersions.Count -gt 1)
            {
                $fv_obj = $jira_json.fields.fixVersions.name
                foreach($fv in $fv_obj)
                {
                    $fv_string += "<field name=""fixversion_ss"">$($fv)</field>`r"
                }
            }
        }else
        {
            $fv_string = "<field name=""fixversion_ss"">NONE</field>"
        }
        if( $jira_json.fields.components){
            if($jira_json.fields.components.Count -eq 1)
            {
                $comp_string = "<field name=""components_txt"">$($jira_json.fields.components.name)</field>"
            }
            if($jira_json.fields.components.Count -gt 1)
            {
                $comp_obj = $jira_json.fields.components.name
                foreach($comp in $comp_obj)
                {
                    $comp_string += "<field name=""components_txt"">$($comp)</field>`r"
                }
            }
        }else{
            $comp_string = "<field name=""components_txt"">NONE</field>"
        }
        $page_count=1

        Write "Transforming files under folder $fname ..."
        $transformed_node=""
        $transformed_node=@"
<?xml version="1.0" encoding="UTF-16"?>
<add>

"@

        #Get all attachments inside the folder (except json files - they contain metadata) and dll and zip files
        $att_files = Get-ChildItem -Path $fqdn -Exclude '*dll','*zip' | Select FullName

        foreach($att in $att_files)
        {

            $fqfn = $att.FullName
            # Get SourceFileName - Transformed XML will be of the same name but with extension .xml
            # Construct Destination File Full Path
            $s_filename = Split-Path $fqfn -Leaf
            $title="$s_filename"

            Write "`tTransforming $s_filename ..."
            
            $s_extension = [System.IO.Path]::GetExtension($s_filename)
            $s_basename = [System.IO.Path]::GetFileNameWithoutExtension($s_filename)
            #Destination filename (transformed XML) will be FR-XX.xml
            
            $doc_type=$s_extension.Replace('.','')

            #Extract field information based on filetypes
            if(($s_extension -match 'xml') -and ($s_basename -notmatch '(FR|NM|MA|MACPR|MG|MGCPR|DOC)\-'))
            {
                $content = $s_filename
            }
            if($s_extension -match '(bmp|jpg|png|gif|tiff|msi)')
            {
                $content = $s_filename
            }
            if($s_extension -match 'txt')
            {
                $content = Get-Content "$fqfn"
            }
            if($s_extension -match 'rtf')
            {
                #Write "`tRTF file ..."
                $content = java -jar .\$tika_jar -t "$fqfn" -eUTF-16
            }
            if($s_extension -match '(doc|docx|pdf)')
            {
                # Extract metadata in JSON format - flag -j does that for you
                try{
                    $metadata_j = java -jar .\$tika_jar -m -j $fqfn | ConvertFrom-Json

                }catch [System.Exception] {
                    Write "`tError extracting metadata for $s_filename ..."
                    Write "`t$($error[0].Exception.Message)"
                    break
                }

                # Extract context in Text format (structured) -t flag does that for you
                $content = java -jar .\$tika_jar -t "$fqfn" -eUTF-16

                #We would need atleast the following fields - Title, Author, LastModified date, Content-Type, Page Count
                #Most of the above listed fields are already defined in schema.xml - making it easier to transform/transport documents over to SOLR
                $doc_type = $metadata_j.'Content-Type'
                if(-Not [String]::IsNullOrEmpty($metadata_j.Author))
                {
                    $author = $metadata_j.Author
                }
                if(-Not [String]::IsNullOrEmpty($metadata_j.'Last-Modified'))
                {
                    $last_modified=$metadata_j.'Last-Modified'
                }
                if(-Not [String]::IsNullOrEmpty($metadata_j.resourceName))
                {
                    $title = $metadata_j.resourceName
                }
                if(-Not [String]::IsNullOrEmpty($metadata_j.'xmpTPg:NPages'))
                {
                    $page_count = $metadata_j.'xmpTPg:NPages'
                }
            }

            $id = $s_basename.Trim() +"_" + $last_modified
            $id = $id.Replace(" ","")

            #If file type is not being supported then pass the filename as the content
            if([String]::IsNullOrEmpty($content))
            {
                $content = $s_filename
            }

            #Ensure last_modified field is always in UTC format
            if([String]::IsNullOrEmpty($last_modified)){
                $last_modified = ((Get-ItemProperty -Path $fqfn -Name LastWriteTime).LastWriteTime).ToUniversalTime().ToString('yyyy-MM-ddThh:mm:ss.ffZ')
            }else{
                #Transform last_modified date to UTC format
                $last_modified = [System.Convert]::ToDateTime($last_modified).ToUniversalTime().ToString('yyyy-MM-ddThh:mm:ss.ffZ')
            }


            $document_node=@"
    <doc>
          <field name="id">$id</field>
          <field name="title"><![CDATA[$title]]></field>
          <field name="subject"><![CDATA[$subject]]></field>
          <field name="description">
            <![CDATA[$description]]>
          </field>
          <field name="url">$jiraurl</field>
          <field name="url_s">$jiraurl</field>
          <field name="author">$author</field>
          <field name="content_type">$doc_type</field>
          <field name="content_type">JIRA</field>
          <field name="last_modified">$last_modified</field>
          $fv_string
          $comp_string
          <field name="pagecount_s">$page_count</field>
          <field name="content">
            <![CDATA[$content]]>
          </field>
    </doc>

"@        
            $transformed_node+=$document_node
            $transformed_count++
       } #end of file forloop

       $transformed_node+=@"

</add>
"@
        #Write "`tTransformed file will be written to $fqdn\$dest_filename"
        #Write to file if there are only docs in them
        $dest_xml = [System.IO.Path]::Combine($fqdn,$dest_filename)
        $transformed_node > $dest_xml
                
  }

Write "$transformed_count files were transformed"
