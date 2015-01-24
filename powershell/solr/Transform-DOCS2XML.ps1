<#
.Synopsis
   Parse PDF, Word, Office documents to SOLR readable xml
.DESCRIPTION
   This Script/Program relies on tika-app-1.6.jar
   Input either a file or a directory, each file will be sent to tika twice, once for metadata and once for content
    Metadata is extracted in JSON format for easy parsing
   Extracted metadata is written to XML 
   Transformed xml will contain standard fields like - id, title, description, author, last_modified, url and content
.EXAMPLE
   Transform-DOCS2XML.ps1 -SourceFilePath .\svn-book.pdf -DestinationFilePath .\svn-book.xml
.NOTES
    Author: Praveen Chamarthi
    Date: 30/12/2014
    Comments: This is the tits
#>
[CmdletBinding()]
Param
    (
        # SourceFilePath
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String] $SourceFilePath,

        # DestinationFilePath
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [String] $DestinationFilePath

    )

    #The Scripts relies on having apache tika jar to be present in the current directory
    #Download url: http://tika.apache.org/download.html
    #Current Version: 1.6
    $working_dir = Split-Path ($MyInvocation.MyCommand.Path) -Parent
    $DestinationFilePath = $working_dir

    $tika_jar = "tika-app-1.6.jar"

    if(-Not (Test-Path .\$tika_jar ))
    {
        Write "Apache Tika (tika-app-1.6.jar) is required in the same directory as the script"
        Write "You may download tika from http://tika.apache.org/download.html"
    }else{
        
        if(-Not (Test-Path .\tmp -PathType Container))
        {
            Write "`tCreating tmp directory .. "
            New-Item -Path .\tmp -ItemType directory | Out-Null
        }

    }

    if(-Not(Test-Path $DestinationFilePath -PathType Container))
    {
        Write "$DestinationFilePath doesn't exist on disk .. creating one"
        New-Item -Path $DestinationFilePath -ItemType directory | Out-Null
    }

    # Get SourceFileName - Transformed XML will be of the same name but with extension .xml
    # Construct Destination File Full Path
    $s_filename = Split-Path $SourceFilePath -Leaf
    $s_basename = [System.IO.Path]::GetFileNameWithoutExtension($s_filename)
    $s_basename = $s_basename -replace ' ',''
    $s_extension = [System.IO.Path]::GetExtension($s_filename)

    $dest_filename = "$s_basename.xml"
    $dest_filepath = [System.IO.Path]::Combine("$DestinationFilePath","$dest_filename")

    Write "`tTransformed file will be written to $dest_filepath"

    # Extract metadata in JSON format - flag -j does that for you
    $metadata_j = java -jar .\$tika_jar -m -j $SourceFilePath | ConvertFrom-Json
    
    # Extract context in Plain Text format -T flag does that for you
    $content = java -jar .\$tika_jar -T $SourceFilePath
    #| Out-File .\tmp\content.txt
    
    #For all documents adhering to OpenXML format, extract relevant metadata
    #We would need atleast the following fields - Title, Author, LastModified date, Content-Type, Page Count
    #Most of the above listed fields are already defined in schema.xml - making it easier to transform/transport documents over to SOLR

    $doc_type = $metadata_j.'Content-Type'
    $author = $metadata_j.Author
    $last_modified=$metadata_j.'Last-Modified'
    $creation_date = $metadata_j.'Creation-Date'
    $title = $metadata_j.resourceName
    $page_count = $metadata_j.'xmpTPg:NPages'
    $app_version = $metadata_j.'Application-Version'
    $is_encrypted = 'false'

    if($doc_type -match 'openxmlformat')
    {
        Write "OpenXML Document - probably Word 2007 and above"
    }
    if($doc_type -match 'msword')
    {
        Write "MS Word (97-2003) Document"
        if([String]::IsNullOrEmpty($author) -or ($author -match 'test'))
        {
            $author = $metadata_j.'Last-Author'
        }
        #Word 97-2003 documents doesn't have xmpTPg:NPages property
        $page_count = 'NA'
        $app_version = 'Word 97-2003'
    }
    if($doc_type -match 'pdf')
    {
        Write "`tPDF Document ..."
        $app_version = $metadata_j.'pdf:PDFVersion'
        #$pdf_producedon = $metadata_j.producer
        $is_encrypted = $metadata_j.'pdf:encrypted'
        if([String]::IsNullOrEmpty($last_modified))
        {
            $last_modified = $metadata_j.'Creation-Date'
        }
        if([String]::IsNullOrEmpty($author))
        {
            $author = 'NA'
        }
    }
    
    $id = $s_basename +"_" + $last_modified
    
    #Construct Dictionary object (HashTable) to map user short names with fullnames
    $user_hash = @{"ericb"="Eric Briere";
                    "benoitl"="Benoit Labonte";
                    "hansg"="Hans Guervemont";
                    "micahg"="Micah Gorrell";
                    "owens"="Owen Swerkstrom";
                    "thaned"="Thane Diamond";
                    "rodneyp"="Rodney Price";
                    "kenl"="Ken Liu";
                    "guangl"="Guang Li";
                    "seanp"="Sean Phillips";
                    "philliper"="Phillipe Raymond";
                    "sund"="Sun Dezhan";
                    "rolandg"="Roland Gaspar"}

    #If the author value doesn't have whitespace recorded then it's probably a short name or an author with other chars in them
    if($author -notmatch '\s')
    {
        if($user_hash.ContainsKey($author))
        {
            $user_hash.$author
        }else{
            Write "`tAuthor: $author value is short and is not in User dictionary ..."
        }
    }
    
    #Final XML document (SOLR readable) with UTF-16 encoding
    $transformed_node=@"
<?xml version="1.0" encoding="UTF-16"?>
<add>
    <doc>
      <field name="id">$id</field>
      <field name="title">$title</field>
      <field name="author">$author</field>
      <field name="doctype_txt">$doc_type</field>
      <field name="last_modified">$last_modified</field>
      <field name="pagecount_s">$page_count</field>
      <field name="content">
        <![CDATA[$content]]>
      </field>
    </doc>
</add>
"@

$transformed_node > .\$dest_filename

Write "Transformation Complete"
Write "File written to: $dest_filename"
