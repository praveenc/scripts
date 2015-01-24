function Update-AssemblyInfo
{
<#
.Synopsis
   Updates AssemblyInfo.cs file with Build Number
.DESCRIPTION
   Updates the following lines only
   ...
   [assembly: AssemblyVersion("1.0.0.0")]
   [assembly: AssemblyFileVersion("1.0.0.0")]
.EXAMPLE
   Update-AssemblyInfo -BuildNumber "5.3.0.125" -FileName "C:\svn\trunk\blah\properties\AssemblyInfo.cs"
.EXAMPLE
   Another example of how to use this cmdlet
#>

    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Version Number
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidatePattern("\d\.\d\.\d\.\d{2,4}")]
        [String]$BuildNumber,

        # AssemblyInfo.cs FullPath
        [ValidateScript({Test-Path $_})]
        [String]$FileName
    )

    $file = Split-Path $FileName -

    Write "--- Updating AssemblyInfo in folder $file with $BuildNumber"
    $fc = (Get-Content $FileName) | % { $_ -replace "\[assembly\:\sAssemblyVersion\(.*?\)\]","[assembly: AssemblyVersion(""$BuildNumber"")]"}
    $fc | % {$_ -replace "\[assembly\:\sAssemblyFileVersion\(.*?\)\]","[assembly: AssemblyFileVersion(""$BuildNumber"")]"} | Set-Content $FileName
    Write "-- Done --"
    Get-Content $FileName
}