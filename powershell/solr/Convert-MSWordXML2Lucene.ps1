<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Convert-XMLWord2Lucene
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Full Path to the MSWord File in XML Format, Use Apache Tika with -x option to Generate XML
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_})]
        [String]$MSWordFileToConvert,

        # Param2 help description
        [int]
        $Param2
    )

    Begin
    {
    }
    Process
    {
    }
    End
    {
    }
}
[xml]$msword_xml = Get-Content .\doctest.xml

$transformed_node=@"
<?xml version="1.0" encoding="UTF-8"?>
<add>
    <doc>

"@

Write-Output "Extracting document metadata..."
#Extracting Document Metadata
$meta_tags = $msword_xml.html.head.meta

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

    if($tag.name -eq "meta:last-author"){

$transformed_node+=@"
            <field name="lastauthor_t">$($tag.content)</field>
            
"@
    }
    if($tag.name -eq "meta:line-count"){

$transformed_node+=@"
<field name="linecount_i">$($tag.content)</field>
            
"@
    }
    if($tag.name -eq "meta:paragraph-count"){

$transformed_node+=@"
<field name="paragraphcount_i">$($tag.content)</field>
            
"@
    }
    if($tag.name -eq "meta:page-count"){

$transformed_node+=@"
<field name="pagecount_i">$($tag.content)</field>
            
"@
    }
    if($tag.name -eq "Word-Count"){

$transformed_node+=@"
<field name="wordcount_i">$($tag.content)</field>
            
"@
    }
    if($tag.name -eq "Character Count"){

$transformed_node+=@"
<field name="charcount_i">$($tag.content)</field>
            
"@
    }
    if($tag.name -eq "Last-Save-Date"){

$transformed_node+=@"
<field name="last_saved_dt">$($tag.content)</field>
            
"@
    }
    if($tag.name -eq "Last-Modified"){

$transformed_node+=@"
<field name="last_modified">$($tag.content)</field>
            
"@
    }

}

Write-Output "Extracting document body..."
#Extracting Document body
$content_ = $msword_xml.html.body
$content_ = $content_ | Select -Property *

$transformed_node+=@"
<field name="text">$($content_.ChildNodes.'#text')</field>

"@


$transformed_node+=@"

    </doc>
</add>
"@

$transformed_node
