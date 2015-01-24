    $ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName="10.10.23.146"
            PSDscAllowPlainTextPassword=$true
         }
    )
}
 
Configuration DownFiles
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$SourcePath,

        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential
    )

    Node $AllNodes.NodeName
    {
        File DownloadCMDFile
        {
            Ensure = "Present"
            SourcePath = $SourcePath
            DestinationPath = "C:\"
            Type = "Directory"
            Recurse="True"
            Credential=$Credential
        }
    
    }
}
DownFiles -ConfigurationData $ConfigurationData -SourcePath "\\10.10.4.107\dev\Praveen\secure" -Credential (Get-Credential)