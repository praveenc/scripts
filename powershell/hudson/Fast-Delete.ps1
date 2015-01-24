<#
.Synopsis
   Fast Deletes folders on disk
.DESCRIPTION
   Deleting folders using del, rmdir is upto 3 times faster than normal delete.
.EXAMPLE
   Fast-Delete -FolderPath E:\test\CI
.NOTES
   Author: Praveen Chamarthi
   Create Date: 24 Dec 2014
#>
function Fast-Delete
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # FolderPath to Delete
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_})]
        [String]$FolderPath
    )

    
    Write-Output "`tDELETING $FolderPath ..."
    Write-Output "`t==========================================="
    Write-Output "`tDELETE STARTED: $(Get-Date)"
    Write-Output "`t==========================================="
        
    Write-Output "`t`tDELETING FILES AND FOLDERS ..."
    cmd.exe /c "del /f/s/q $FolderPath >nul & rmdir /s/q $FolderPath"

    #Write-Output "`t`tDELETING FOLDERS ..."
    #cmd.exe /c "rmdir /s/q $FolderPath"

    Write-Output "`t==========================================="
    Write-Output "`tDELETE COMPLETE: $(Get-Date)"
    Write-Output "`t==========================================="

}