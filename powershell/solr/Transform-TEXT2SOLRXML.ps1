<#
.Synopsis
   Reads a plain Text File (UTF-8) and Transforms to XML document readable by SOLR
.DESCRIPTION
   Reads a plain Text File and encloses the entire content within a CDATA directive.
   SOLR XML fields used in this program are as defined in schema.xml of SOLR on 10.10.3.214:8983/solr
.EXAMPLE
   Transform-TEXT2SOLRXML.ps1 -FileToRead c:\design_message_header.txt -Author "Praveen Chamarthi"
.NOTES
    Author: Praveen Chamarthi
    Date: 30/12/2014
#>
[CmdletBinding()]
Param
    (
        # Text File To Read
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_})]
        [String] $FileToRead,

        # Author information
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidateScript({-Not [String]::IsNullOrEmpty($_)})]
        [String] $Author

    )

Write-Output "Initiating Transformation ..."
$fileToRead = $FileToRead
$filename = Split-Path $fileToRead -Leaf
$filepath = Split-Path $fileToRead -Parent

#Extracting Author Short
$Author_s = $Author.Split(' ')[0].ToLower()

$last_modified = Get-ChildItem -Path $filepath -File -Filter $filename | Select LastWriteTime
#Convert Time to UTC format
$last_modified = (($last_modified.LastWriteTime).ToUniversalTime()).ToString("yyyy-MM-ddThh:mm:ssZ")

Write-Output "`tReading $filename contents ..."
$txt_data = Get-Content $fileToRead

$new_filename = $filename -replace '\.txt','.xml'

Write-Output "`tChecking if Transformed_$new_filename exist ..."
#Delete if output file already exists
if(Test-Path ".\Transformed_$new_filename"){
    Write-Output "`tDeleting Transformed_$new_filename"
    Remove-Item -Path "Transformed_$new_filename" -Force | Out-Null
}

Write-Output "`tGenerating XML ..."
#Create a Here String variable for writing the final XML"
$transformed_node=@"
<?xml version="1.0" encoding="UTF-16"?>
<add>
    <doc>
      <field name="id">$filename</field>
      <field name="title">$filename</field>
      <field name="author_sname_s">$Author_s</field>
      <field name="author">$Author</field>
      <field name="doctype_s">txt</field>
      <field name="url">svn+ssh://svn.myserver.com/myserver/documentation/secure/$filename</field>
      <field name="last_modified">$last_modified</field>
      <field name="content">
        <![CDATA[$txt_data]]>
      </field>
    </doc>
</add>
"@
Write-Output "`tWriting XML to .\Transformed_$new_filename ..."
$transformed_node | Out-File ".\Transformed_$new_filename" -Append

Write-Output "Transformation Complete ..."
