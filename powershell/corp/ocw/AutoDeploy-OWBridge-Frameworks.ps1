<#
.SYNOPSIS
    Auto Deploys a Frameworks Bridge Build to Target Server    
.DESCRIPTION
    Remotes to Target machine and Deploys a Frameworks Bridge build by calling Deploy script DeployBridgeSF.vbs
.PARAMETER BuildNumber
    Build number to deploy e.g. 2.6.05.07
.PARAMETER ComputerName
    Target Computer Name e.g. PRF1QAW1
.PARAMETER Licensee [Optional]
    Licensee Name to be Deployed Default is OWBridge
.PARAMETER SiteRoot [Optional]
	Path to Site Root on Target Server. Directory to root of website
.PARAMETER WCFRoot [Optional]
	Path to WCF Root on Target Server.
.NOTES
    Author: -- Praveen Chamarthi --
    Created On: 12 June 2013
.EXAMPLE
    .\AutoDeploy-OWBridge-Frameworks.ps1 -ComputerName PRF1QAW1  -BuildNumber 2.6.05.07
.EXAMPLE
    .\AutoDeploy-OWBridge-Frameworks.ps1 -ComputerName PRF1QAW1  -BuildNumber 2.6.05.07 -TagToUpdate 'FWBRIDGE QA'
.EXAMPLE
    .\AutoDeploy-OWBridge-Frameworks.ps1 -ComputerName PRF1QAW1  -BuildNumber 2.6.05.07 -SourceDir 'E:\Builds\SFBridge'
.EXAMPLE
    .\AutoDeploy-OWBridge-Frameworks.ps1 -ComputerName PRF1QAW1  -BuildNumber 2.6.05.07 -SourceDir 'E:\Builds\SFBridge' -Licensee OWBridge
.EXAMPLE
    .\AutoDeploy-OWBridge-Frameworks.ps1 -ComputerName PRF1QAW1  -BuildNumber 2.6.05.07 -SourceDir 'E:\Builds\SFBridge' -Licensee OWBridge -SiteRoot 'E:\BRIDGE_WEBSITE_LIVE'
.EXAMPLE
    .\AutoDeploy-OWBridge-Frameworks.ps1 -ComputerName PRF1QAW1  -BuildNumber 2.6.05.07 -SourceDir 'E:\Builds\SFBridge' -Licensee OWBridge -SiteRoot 'E:\BRIDGE_WEBSITE_LIVE' -WCFRoot 'E:\WCF_Service\ComplianceService'
#>
Param(
    
    [CmdletBinding()]
    #Target Computer Name
    [Parameter(Mandatory=$true,
                   Position=0,
                   HelpMessage="Target ComputerName or IP Address")]
    [String]$ComputerName,

    #Build Number to Deploy
    [Parameter(Mandatory=$true,
                   Position=1,
				   HelpMessage="FW Build Number to Deploy")]
    [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{1,3}")]
    [String]$BuildNumber,

	#HTML Tag in Insurance Index to Update
	[Parameter(Mandatory=$false,
                   Position=2,
				   HelpMessage="HTML id tag on Frameworks Insurance Index e.g 'FWBRIDGE QA'")]
    [ValidateNotNullOrEmpty()]
	[String]$TagToUpdate="FWBRIDGE QA",
    
    #Source Directory of the Build
    [Parameter(Mandatory=$false,
                   Position=3,
                   HelpMessage="Build Directory Root (one level above branch path) on local computer")]
    [String]$SourceDir='E:\Builds\SFBridge',
    
    #Licensee Name
    [Parameter(Mandatory=$false,
                   Position=4,
                   HelpMessage="Licensee name ")]
    [String]$Licensee='OWBridge'

)
    #Include Common Functions, Scrub-OWScripts, Create-OWCombinePackage
    . .\OW-CMTools.ps1

    #Set Working Directory to Current Directory
    [Environment]::CurrentDirectory=(Get-Location -PSProvider FileSystem).ProviderPath


    $Release=$BuildNumber.Substring(0,3)
    $LogFile = "$SourceDir\$Release\$BuildNumber\log\$BuildNumber.$Licensee.$ComputerName.FWDeploy.log"
    Write-Output "Commencing Bridge Frameworks Deploy to $ComputerName" | Tee-Object $LogFile -Append

    #Read SecureString for Authentication Hop
    $uname = "OWLAND1\BridgeBuild"
    $hash = Get-Content .\SecureString.txt | ConvertTo-SecureString
    $cred =  New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $uname, $hash

    

    
    Write-Output "Opening Remote Session to $ComputerName..." | Tee-Object $LogFile -Append
    
    try{

        #Open Session to Remote Computer with Authentication as Credssp
        $mysess = New-PSSession -ComputerName $ComputerName -Authentication Credssp -Credential $cred    
    
    }catch{

        Write-Output "Error Opening Remote Session: " $_.Exception.Message | Tee-Object $LogFile -Append
        
    }
    

    #Deploy on Target Computer
    Invoke-Command -ScriptBlock { 
        
        $Branch = $args[0]
        $BuildNumber = $args[1]
        $Licensee = $args[2]

        $DeployScript = "\\192.168.0.55\scripts\DeployBridgeSF.vbs"
        
        Write-Output "Calling $DeployScript with Params /Build $BuildNumber /Branch $Branch /Licensee $FWLicensee" -Verbose
        
        cscript /nologo "$DeployScript" /Build "$BuildNumber" /Branch "$Branch" /Licensee "$Licensee"
        
    } -Session $mysess -ArgumentList $Release, $BuildNumber, $Licensee | Tee-Object $LogFile -Append

    
    #LogOut of Remote computer Computer
    $mysess | Remove-PSSession

    Write-Output "Deploy complete to $ComputerName ..Session Exited" | Tee-Object $LogFile -Append

    #Update FW Insurance Index
    #InsuranceIndex Server
    $insindex_server = "\\PROPU2\E`$\InsuranceIndex"
    $fwindex_file = "fwsiteindex.html"

    Write-Output "Updating Build Number on Insurance Index" | Tee-Object $LogFile -Append
    $filname = "$insindex_server\$fwindex_file"

    If(Test-Path $filname -PathType Leaf){

        #Save a copy of file before modifying it
        Write-Host "Saving a copy of $filname" | Tee-Object $LogFile -Append

        Get-Content "$filname"|Set-Content "$filname.tmp"

        #$tag_toupdate = "BETA QA"

        #Read each line and if line matches the RegExp Replace with Build Number
        (Get-Content "$filname") | 
        ForEach-Object {
            If($_ -match "<a(.*)($TagToUpdate)(.*?)>(.*?)</a>"){

                $first_m = $Matches[1]
                $second_m = $Matches[2]
                $third_m = $Matches[3]

                $line = "<a$first_m$second_m$third_m>$BuildNumber</a>"
                #Write-Host "Inside If: $line"
                $_ -replace "<a(.*)($TagToUpdate)(.*?)>(.*?)</a>","$line"
            }else{
                $_
            }
        } | Set-Content $filname
    }else{

        Write-Output "Could not Update Insurance Index: $filname not Found" | Tee-Object $LogFile -Append

    }

    Write-Output "===Frameworks Deploy to $ComputerName Complete===" | Tee-Object $LogFile -Append2.06