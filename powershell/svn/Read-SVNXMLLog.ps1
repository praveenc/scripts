<#
.Synopsis
   Reads SVN Log and Transforms to document readable by SOLR
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
[CmdletBinding()]
Param
    (
        # XML File To Read
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [String]
        $XMLFileToRead,

        # Param2 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [String]
        $SVNBranchName
    )

$fileToRead = ".\doc_logdump.xml"
$branch_name = "svn.myserver.com/archive/documentation"
[xml]$xml_data = Get-Content $fileToRead

$logentry = Select-Xml "//logentry" $xml_data
$transformed_node=@"
<?xml version="1.0" encoding="UTF-8"?>
<add>

"@

foreach($log in $logentry){
    
    $revision = $log.Node.revision
    $author = $log.Node.author
    $last_modified = $log.Node.date
    $msg = $log.Node.msg
$transformed_node+=@"
    <doc>
        <field name="id">$revision</field>
        <field name="name">$branch_name</field>
        <field name="author">$author</field>
        <field name="last_modified">$last_modified</field>
        <field name="comments">$msg</field>

"@
    $paths = $log.Node.paths.path.'#text'
    foreach($path in $paths){
$transformed_node+=@"
        <field name="content">$path</field>

"@
    }
$transformed_node+=@"
    </doc>

"@
}
$transformed_node+=@"
</add>
"@

$transformed_node = $transformed_node | % {if($_ -match "\&"){$_ -replace "\&","&amp;"}else{$_}}


