<#
.Synopsis
   Converts a PDF to Lucene readable XML format
.DESCRIPTION
   Converts a PDF to Lucene readable XML format
.EXAMPLE
   .\Convert-XMLPDF2Lucene.ps1 -PDFFileToConvert .\test.pdf
.NOTES
   Author: Praveen Chamarthi
   Create Date: 26 June 2014
#>
function Convert-XMLPDF2Lucene
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Full Path to the PDF File to Convert, Uses Apache Tika with -x option to Generate XML
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_})]
        [String]$PDFFileToConvert,

        # Transformed XML FileName/Path
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [String]$OutputFileName
    )

    Begin
    {
        $WorkingDir = (Get-Location -PSProvider FileSystem).ProviderPath
        $hostname = [System.Net.Dns]::GetHostName()

        if([String]::IsNullOrEmpty($OutputFileName)){
            
            $filname = Split-Path $PDFFileToConvert -Leaf
            $OutputFileName = "$WorkingDir\$filname"
        }

        if(Test-Path "$WorkingDir\tika-app-1.5.jar"){
            Write-Output "Found Tika App 1.5 ..."
        }else{
            Write-Output "Apache Tika v1.5 or higher is needed for this script to run..."
        }
        & { java -jar .\tika-app-1.5.jar -x $PDFFileToConvert > "$OutputFileName.xml" }
        
        Write-Output "Transformed $PDFFileToConvert to XML"
        $tr_file = "$OutputFileName.xml"
    }
    Process
    {
        [xml]$pdf_xml = Get-Content $tr_file

$transformed_node=@"
<?xml version="1.0" encoding="UTF-8"?>
<add>
    <doc>
        <field name="id">$([guid]::NewGuid().Guid)</field>
        <field name="contenttype_t">application/pdf</field>

"@

Write-Output "Extracting document metadata..."

#Extracting Document Metadata
$meta_tags = $pdf_xml.html.head.meta

foreach($tag in $meta_tags){

    if($tag.name -eq "resourceName"){

$transformed_node+=@"
    <field name="title">$($tag.content)</field>

"@
    }
    if($tag.name -eq "Author"){

$transformed_node+=@"
    <field name="firstauthor_t">$($tag.content)</field>

"@
    }

    if($tag.name -eq "meta:author"){

$transformed_node+=@"
    <field name="lastauthor_t">$($tag.content)</field>

"@
    }
    if($tag.name -eq "meta:creation-date"){

$transformed_node+=@"
    <field name="createdon_dt">$($tag.content)</field>

"@
    }

    if($tag.name -eq "xmpTPg:NPages"){

$transformed_node+=@"
    <field name="pagecount_i">$($tag.content)</field>

"@
    }

    if($tag.name -eq "Last-Save-Date"){

$transformed_node+=@"
    <field name="last_saved_dt">$($tag.content)</field>

"@
    }
    if($tag.name -eq "modified"){

$transformed_node+=@"
    <field name="last_modified">$($tag.content)</field>

"@
    }

}

Write-Output "Extracting document body..."
#Extracting Document body
$content_ = $pdf_xml.html.body
#$content_ = $content_ | Select -Property *

$transformed_node+=@"
    <field name="content"><![CDATA[$($content_.OuterXML)]]></field>

"@


$transformed_node+=@"

    </doc>
</add>
"@
    }
    End
    {
        Write-Output "$PDFFileToConvert transformed to Lucene XML"
        $transformed_node | Out-File "$WorkingDir\lucene_$filname.xml"
        Write-Output "Transformed file available here - $WorkingDir\lucene_$filname.xml"

    }
}

