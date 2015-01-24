<#
.Synopsis
   Parse PDF, Word, Office documents to SOLR readable xml
.DESCRIPTION
   This script assumes that all folders that may contain Design Docs is checked out\downloaded to a local\shared folder
   All the files in the folders are scanned and all txt, rtf, doc, docx and pdf documents are transformed to SOLR readable xml
   This Script/Program requires tika-app-1.6.jar to be present in the current directory
   Transformed xml will contain standard fields like - id, title, description, author, last_modified, url and content
.EXAMPLE
   Transform-DOCS2XML.ps1 -svnworkingfolderpath E:\myserver\documentation -destinationfolder F:\DocsToIndex\svn
.NOTES
    Author: Praveen Chamarthi
    Date: 14-Jan-2015
    Modified: 15-Jan-2015
    Comments: Transforms all documents under each working folder to one xml
#>
[CmdletBinding()]
Param
    (
        # SourceFilePath
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [String] $svnworkingfolderpath,

        # DestinationFolder
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [String] $destinationfolder

    )

    #$ErrorActionPreference = "Stop"

    #The Scripts relies on having apache tika jar to be present in the current directory
    #Download url: http://tika.apache.org/download.html
    #Current Version: 1.6
    $tika_jar = "tika-app-1.6.jar"
    $transformed_count = 0
    $anon_svn_url = "http://svn.myserver.com/anonsvn/myserver/documentation"

    if(-Not (Test-Path .\$tika_jar ))
    {
        Write "Apache Tika ($tika_jar) is required in the same directory as the script"
        Write "You may download tika from http://tika.apache.org/download.html"
        exit 1
    }
    Write "Updating working folder $svnworkingfolderpath ..."
    svn update $svnworkingfolderpath

    Write "Transforming files under folder $svnworkingfolderpath ..."
    
    #Delete if Transformed file already exists

    #Get all files of type txt, doc, docx, pdf, odt, rtf under svnfolderpath
    $fils_to_transform = Get-ChildItem -Path $svnworkingfolderpath -Recurse -Include "*.txt","*.rtf","*.doc","*.docx","*.pdf","*.odt","*.ppt" | Select FullName
    
    #svn log contains username in short form - dictionary maps shortnames to full names
    $user_dict = @{"praveenc"="Praveen Chamarthi";"seanp"="Sean Phillips";"guangl"="Guang Li";"kenl"="Ken Liu";"ericb"="Eric Briere";
                    "ludovicj"="Ludovic Jean-Louis";"damiend"="Damien Dykman";"philliper"="Phillipe Raymond";"benoitl"="Benoit Labonte";
                    "sun"="Sun Dezhan";"hans"="Hans Guevremont";"thane"="Thane Diamond";"micah"="Micah Gorrell";"owen"="Owen Swerkstrom";
                    "rodney"="Rodney Price";}

    Write "Found $($fils_to_transform.Count) documents"
    #Scan each folder for attachments, if found transform them into one xml containing multiple <doc>....</doc> nodes
    foreach($fil in $fils_to_transform)
    {
        $fqfn = $fil.FullName
        $fname = Split-Path $fqfn -Leaf

        #Write Destination FileName
        $s_extension = [System.IO.Path]::GetExtension($fname)
        $s_extension = $s_extension.Replace(".","")
        $s_basename = [System.IO.Path]::GetFileNameWithoutExtension($fname)
        $s_basename = $s_basename.Replace(" ","")
        $dest_filepath = [System.IO.Path]::Combine("$destinationfolder",$s_basename+"_"+$s_extension+".xml")

        if(Test-Path $dest_filepath)
        {
            Remove-Item -Path $dest_filepath -Force
        }

        $svn_file_url = $fqfn.Replace("$svnworkingfolderpath","")
        $svn_file_url = $svn_file_url.Replace("\","/")
        $svn_file_url = [System.Uri]"$anon_svn_url$svn_file_url" | Select AbsoluteUri
        $svn_file_url = $svn_file_url.AbsoluteUri
        #$svn_file_url
        
        $svn_log = svn log $svn_file_url -q -l 1
        #SVN Log record is returned in format - need to process this string to extract rev, author and lastmodified date
        # ------------------------------------------------------------------------
        # r156052 | praveenc | 2015-01-09 12:14:55 -0500 (Fri, 09 Jan 2015)
        # ------------------------------------------------------------------------
        $svn_log = $svn_log.Replace("--","")
        $svn_log = $svn_log.Replace(" | ","*")
        $svn_log = $svn_log.Split("*")
        
        #"0: " + $svn_log[0]
        #"1: " + $svn_log[1]
        #"2: " + $svn_log[2]
        #"3: " + $svn_log[3]
        #Pause

        if($svn_log.Count -ge 3)
        {

            $id = $svn_log[1]
            $author =$svn_log[2]
            #Get FullName from User Dictionary
            if($user_dict.ContainsKey($author))
            {
                $author = $user_dict["$author"]
            }
            $last_modified = $svn_log[3]
            
            #Date String is returned in format 2015-01-09 12:14:55 -0500 (Fri, 09 Jan 2015) - replace everything after -0500 with nothing
            $last_modified = $last_modified -replace '\-\d{4}\s\(.*?\)',''
            
            #Convert DateTime to UTC string accepted by SOLR
            $last_modified = [System.Convert]::ToDateTime($last_modified).ToUniversalTime().ToString('yyyy-MM-ddThh:mm:ss.ffZ')
            #Write "$id - $author - $last_modified"

            #Title, Subject and Description will be the filename
            $title = $fname
            $subject = $fname
            $description = $fname
            $url = $svn_file_url
            $page_count=1
           
                    
        }
 
        Write "`tTransforming $fname..."
        
        #Use tika to detect document type
        $doc_type=java -jar .\$tika_jar -d $fqfn

        if($doc_type -match 'text')
        {
            $content = Get-Content "$fqfn"
        }
        if($doc_type -match 'rtf')
        {
            #Write "`tRTF file ..."
            $content = java -jar .\$tika_jar -t $fqfn -eutf-16
        }
        if($doc_type -match '(msword|openxmlformat|pdf|opendocument|powerpoint)')
        {
            # Extract metadata in JSON format - flag -j does that for you
            try{
                $metadata_j = java -jar .\$tika_jar -m -j "$fqfn" | ConvertFrom-Json

            }catch [System.Exception] {
                Write "`tError extracting metadata for $fname ..."
                Write "`t$($error[0].Exception.Message)"
                continue
            }

            # Extract context in Text format (structured) -t flag does that for you
            $content = java -jar .\$tika_jar -t $fqfn -eutf-16

            #We would need atleast the following fields - Title, Author, LastModified date, Content-Type, Page Count
            #Most of the above listed fields are already defined in schema.xml - making it easier to transform/transport documents over to SOLR
            $doc_type = $metadata_j.'Content-Type'
            if(-Not [String]::IsNullOrEmpty($metadata_j.Author))
            {
                $author = $metadata_j.Author
                if($user_dict.ContainsKey($author))
                {
                    $author = $user_dict["$author"]
                }
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

        #Construct ID string to be as unique as possible
        $id = $id +"_" + $s_basename.Trim() +"_" + $last_modified
        
        #The final document XML string
        $document_node=@"
<?xml version="1.0" encoding="UTF-8"?>
<add>
    <doc>
          <field name="id">$id</field>
          <field name="title"><![CDATA[$title]]></field>
          <field name="subject"><![CDATA[$subject]]></field>
          <field name="description">
            <![CDATA[$description]]>
          </field>
          <field name="url">$url</field>
          <field name="url_s">$url</field>
          <field name="author">$author</field>
          <field name="content_type">$doc_type</field>
          <field name="content_type">SVN</field>
          <field name="last_modified">$last_modified</field>
          <field name="pagecount_s">$page_count</field>
          <field name="content">
            <![CDATA[$content]]>
          </field>
    </doc>
</add>
"@        
            $document_node | Out-File $dest_filepath -Encoding utf8
            $transformed_count++
       } #end of file forloop
        
Write "$transformed_count files were transformed"
