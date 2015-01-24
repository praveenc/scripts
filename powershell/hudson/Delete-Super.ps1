[CmdletBinding()]
[OutputType([int])]
<#
.Synopsis
   Fast Delete Files/Folders
.DESCRIPTION
   Fast Delete Files/Folders - This delete is about 3 times faster than regular Windows standard delete
.EXAMPLE
   Delete-Super -Folder E:\test
.EXAMPLE
   Delete-Super -Folder "\\10.10.23.159\Builds\Netmail_trunk\5.3.1.265"
#>

Param
(
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)]
    [ValidateScript({Test-Path $_})]
    $FolderPath
)

    Write-Output "==========================================="
    Write-Output "DELETE STARTED: " (Get-Date).ToString()
    Write-Output "==========================================="

    Write-Output "DELETING FILES UNDER $FolderPath..."
    cmd.exe /c "del /f/s/q $FolderPath"

    Write-Output "DELETING $FolderPath STRUCTURE..."
    cmd.exe /c "rmdir /s/q $FolderPath"

    Write-Output "==========================================="
    Write-Output "DELETE COMPLETE:" (Get-Date).ToString()
    Write-Output "==========================================="
