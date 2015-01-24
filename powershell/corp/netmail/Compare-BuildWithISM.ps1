﻿<#
.Synopsis
   Compares files in Build with InstallShield Project (Netmail.ism)
.DESCRIPTION
   Compares files in Netmail Webadmin folder in Build with NetmailMSI.ism file and reports any changes.
   Netmail.ism file is an XML file under the hood.
.EXAMPLE
   Compare-BuildWithISM.ps1 -PathToISM E:\pshell\NetmailMSI\Netmail.ism -PathToIgnoreFiles E:\pshell\NetmailMSI\to_ignore_from_install_shield.txt
.NOTES
   Author: Praveen Chamarthi
   Create Date: 08th Oct 2014
.FUNCTIONALITY
   File Compare and Report
#>
    Param
    (
        [CmdletBinding()]
        [OutputType([String])]

        # Full Path to Netmail.ism file
        [Parameter(Mandatory=$true, 
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        $PathToISM,

        # Full Path Build folder
        [Parameter(Mandatory=$true, 
                   Position=1)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_ -PathType Container })]
        $PathToBuildFolder,

        # Full Path to to_ignore_from_install_shield.txt file
        [Parameter(Mandatory=$true, 
                   Position=2)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_ -PathType Leaf })]
        $PathToIgnoreFiles
    )

    $PathToBuildFolder = [System.IO.Path]::Combine("$PathToBuildFolder","M+Archive\Messaging Architects\Netmail WebAdmin")

    If(-not (Test-Path $PathToBuildFolder -PathType Container)){
        Write "~~~~ Cannot Find Netmail WebAdmin folder in Build... check path: $PathToBuildFolder"
        exit 1
    }

    Write "Comparing Files in Build with Files in InstallShield Project (Netmail.ism) ..."
    
    #Extract all file records for Netmail WebAdmin in Netmail.ism
    $ism_list=Select-String -Path $PathToISM -Pattern "ARCHI_FI&gt;.Netmail.WebAdmin" | 
        % { $_ -replace "^.*PATH_TO_MESSAGING",""} | 
        % { $_ -replace "</td.*$",""} | 
        % { $_ -replace "^.*netmail webadmin","0"} | Get-Unique

    #Extract list of files generated by build in Build folder
    $build_list = gci -Path $PathToBuildFolder -Recurse -File | Select FullName | % { $_ -replace '^.*Netmail WebAdmin(.*?)}','0$1'}
    
    #Extract list of files to be ignored
    $ignore_list = Get-Content $PathToIgnoreFiles | % { $_ -replace "\/","\"} | % { if(($_ -notmatch "^#") -and (-not [String]::IsNullOrEmpty($_))){ $_ -replace "^","0\" }}

    #Remove files to be ignored from build_list and ism_list
    $build_list_trim = $build_list | % { if($ignore_list -notcontains $_){ $_ }} | Sort-Object
    $ism_list_trim = $ism_list | % { if($ignore_list -notcontains $_){ $_ }} | Sort-Object
    
    #Compare objects to find anything files missing in Build or InstallShield Netmail.ism
    $compared_lines = Compare-Object -ReferenceObject $build_list_trim -DifferenceObject $ism_list_trim | Sort-Object
    
    if(-not $compared_lines){
        
        Write "~~~ All files in build match files in Netmail.ism ~~~"
    
    }else{
        $build_missing = @()
        $ism_missing = @()
        $compared_lines | foreach {

            #Remove those 0s in the front        
            $fil = $_.InputObject
            $fil = $fil -replace "0\\",""

            if($_.SideIndicator -eq "=>"){
                $build_missing+=$fil
            }elseif($_.SideIndicator -eq "<="){
                $ism_missing+=$fil
            }
        }
    }
    if($build_missing.Count -gt 0){
        Write "=== Missing Files in Build ==="
        $build_missing
    }
    if($ism_missing.Count -gt 0){
        Write "=== Missing Files in InstallShield (Netmail.ism) ==="
        $ism_missing
    }
    #Write the compared objects to disk for later debugging
    $build_list_trim | Set-Content .\build_list_trim.txt
    $ism_list_trim | Set-Content .\ism_list_trim.txt