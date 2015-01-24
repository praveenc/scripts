<#
    
    NOTES.
        Author: Praveen Chamarthi
        Create Date: 15 July 2014
#>

    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # filename 
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidatePattern("^\S+\.(dll|exe|js|json)$")]
        [String]$filename,

        # DirName
        [Parameter(Mandatory=$true,

                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [String]$dirname
    )

    Begin
    {

        #Create two new guids
        $guid1 = [GUID]::NewGuid()
        $guid2 = [GUID]::NewGuid()

        $guid1 = "{$guid1}".ToUpper()

        $guid2 = "_$guid2".ToUpper().Replace("-","_")
        $guid2 = "$guid2" + "_FILTER"
        $dirnameL = $dirname.ToLower()
        $dirnameU = $dirname.ToUpper()
        
        $fn = $filename.Split(".")
        $ext = $fn[1].ToUpper()

        #Construct component type text
        

        if($fn[0].Length -gt 8){
            $fname = $filename.ToUpper().Substring(0,6) + "~1.$ext|$filename"
        }else{
            $fname = $filename
        }
    }
    Process
    {

        Write "Creating Netmail.ism table records for $dirname\$filename .."

        $featcomp_table=@"
    <table name="FeatureComponents">
	    <row><td>Archive</td><td>$filename</td></row>	
	</table>
"@
        $file_table=@"
	<table name="File">
	    <row><td>$filename</td><td>$filename</td><td>$fname</td><td>0</td><td/><td/><td/><td>1</td><td>&lt;PATH_TO_MESSAGING ARCHI_FI&gt;\netmail webadmin\$dirnameL\$filename</td><td>1</td><td/></row>
	</table>
"@
        $compext_table=@"
	<table name="ISComponentExtended">
	    <row><td>$filename</td><td/><td/><td>$guid2</td><td/><td/><td/><td/></row>
	</table>
"@

        if($ext -eq "exe"){
        
            $cmp_text="This component consists of a Windows executable."
            $comp_table=@"
    <table name="Component">
        <row><td>$filename</td><td>$guid1<td><td>$dirnameU</td><td>8</td><td/><td>$filename</td><td>1</td><td>$cmp_text</td><td/><td/><td>/LogFile=</td><td>/LogFile=</td><td>/LogFile=</td><td>/LogFile=</td></row>
    </table>
"@

            $thelines = "$comp_table`r`n$featcomp_table`r`n$file_table`rn$compext_table"

        }
        if($ext -eq "dll"){
            
            $cmp_text="This component consists of a Windows dynamic link library."
            $comp_table=@"
    <table name="Component">
        <row><td>$filename</td><td>$guid1<td><td>$dirnameU</td><td>8</td><td/><td>$filename</td><td>1</td><td>$cmp_text</td><td/><td/><td>/LogFile=</td><td>/LogFile=</td><td>/LogFile=</td><td>/LogFile=</td></row>
    </table>
"@
            $thelines = "$comp_table$featcomp_table$file_table$compext_table"
        }
        if($ext -eq "js"){

            $cmp_text="This component consists of files not belonging to other components."
            $file_table=@"
	<table name="File">
	    <row><td>$filename</td><td>AllOtherFiles70</td><td>$fname</td><td>0</td><td/><td/><td/><td>1</td><td>&lt;PATH_TO_MESSAGING ARCHI_FI&gt;\netmail webadmin\$dirnameL\$filename</td><td>1</td><td/></row>
	</table>
"@
            $comp_table=@"
    <table name="Component">
        <row><td>AllOtherFiles70</td><td>$guid1<td><td>$dirnameU</td><td>8</td><td/><td>$filename</td><td>1</td><td>$cmp_text</td><td/><td/><td>/LogFile=</td><td>/LogFile=</td><td>/LogFile=</td><td>/LogFile=</td></row>
    </table>
"@
        $thelines = "$file_table`r`n$comp_table`r`n"

       }
    
        
    }
    End
    {
        Write "Insert the below <row> into each table in Netmail.ism"
        $thelines
    }

