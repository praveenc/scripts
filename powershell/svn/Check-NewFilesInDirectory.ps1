<#
    SYNOPSIS.
        
    NOTES.
        Author: Praveen Chamarthi
        Create Date: 23 July 2014
#>

    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Directory to monitor 
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_})]
        [String]$dir_to_monitor

    )
    Begin{

        #[Environment]::CurrentDirectory=(Get-Location -PSProvider FileSystem).ProviderPath
    
        $prev_file="$dir_to_monitor\prev_src_files.txt"
        $now_file="$dir_to_monitor\now_src_files.txt"

        $prev_name = Split-Path $prev_file -Leaf
        $now_name = Split-Path $now_file -Leaf
        [String[]]$exclude = "$prev_name","$now_name","smtp-tests","test"
        if(-Not (Test-Path "$prev_file")){

            Write-Output "Couldn't find $prev_file in this directory"
            exit
        }

        Write-Output "Getting Latest File list from $dir_to_monitor ..."
        Get-ChildItem -Path $dir_to_monitor -Recurse -Exclude $exclude | Select FullName | Out-File $now_file

        If((Test-Path $prev_file) -and (Test-Path $now_file)){
            
            Write-Output "Comparing Latest File list with $prev_file .."
            $res = Compare-Object -ReferenceObject (Get-Content $prev_file) -DifferenceObject (Get-Content $now_file)
        
        }else{
            
            Write-Output "Couldn't find one of the files: $prev_file OR $now_file"
            exit 1

        }

        if($res.Count -ge 1){
        
            Write-Output "Found New Files in $dir_to_monitor .."
            $res
        }

    }
