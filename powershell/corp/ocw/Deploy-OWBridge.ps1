<#
.SYNOPSIS
    Deploys a Bridge build to Web server
.DESCRIPTION
    Remote Connects to Target Server, Stops AppPool Copy files from E:\Builds\Latest
.PARAMETER BuildNumber
    Build number to deploy e.g. 2.1.0.13
.PARAMETER ComputerName
    Target Computer Name e.g. PRB1STW2
.PARAMETER Licensee [Optional]
    Licensee Name to be Deployed Default is OWBridge
.PARAMETER SiteRoot [Optional]
	Path to Site Root on Target Server. Directory to root of website
.PARAMETER WCFRoot [Optional]
	Path to WCF Root on Target Server.
.NOTES
    Author: -- Praveen Chamarthi --
    Created On: 16 Apr 2013
.EXAMPLE
    .\Deploy-OWBridge.ps1 -ComputerName PRB1STW2  -BuildNumber 2.1.0.12
.EXAMPLE
    .\Deploy-OWBridge.ps1 -ComputerName PRB1STW2  -BuildNumber 2.1.0.12 -SourceDir 'E:\Builds\OWBridge'
.EXAMPLE
    .\Deploy-OWBridge.ps1 -ComputerName PRB1STW2  -BuildNumber 2.1.0.12 -SourceDir 'E:\Builds\OWBridge' -Licensee OWBridge
.EXAMPLE
    .\Deploy-OWBridge.ps1 -ComputerName PRB1STW2  -BuildNumber 2.1.0.12 -SourceDir 'E:\Builds\OWBridge' -Licensee OWBridge -SiteRoot 'E:\BRIDGE_WEBSITE_LIVE'
.EXAMPLE
    .\Deploy-OWBridge.ps1 -ComputerName PRB1STW2  -BuildNumber 2.1.0.12 -SourceDir 'E:\Builds\OWBridge' -Licensee OWBridge -SiteRoot 'E:\BRIDGE_WEBSITE_LIVE' -WCFRoot 'E:\WCF_Service\ComplianceService'
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
                   Position=1)]
    [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{1,3}")]
    [String]$BuildNumber,
    
    #Source Directory of the Build
    [Parameter(Mandatory=$false,
                   Position=2,
                   HelpMessage="Build Directory Root (one level above branch path) on local computer")]
    [String]$SourceDir='E:\Builds\OWBridge',
    
    #Licensee Name
    [Parameter(Mandatory=$false,
                   Position=3,
                   HelpMessage="Licensee name ")]
    [String]$Licensee='OWBridge',

    #Site Root Directory on Target (UNC)
    [Parameter(Mandatory=$false,
                   Position=4,
                   HelpMessage="Root Directory of Bridge Website")]
    [String]$SiteRoot='E:\Bridge_Website_LIVE',

    #WCF Service Root Directory on Target (UNC)
    [Parameter(Mandatory=$false,
                   Position=5,
                   HelpMessage="WCF_Service Root Directory")]
    [String]$WCFRoot='E:\WCF_Service\ComplianceService'

)

    $Release=$BuildNumber.Substring(0,3)
    $LogFile = "$SourceDir\$Release\$BuildNumber\log\$BuildNumber.$Licensee.$ComputerName.Deploy.log"
    Write-Output "Commencing Deploy to $ComputerName" | Tee-Object $LogFile -Append

    #Read SecureString for Authentication Hop
    $uname = "OWLAND1\BridgeBuild"
    $hash = Get-Content .\SecureString.txt | ConvertTo-SecureString
    $cred =  new-object -typename System.Management.Automation.PSCredential -argumentlist $uname, $hash

    #InsuranceIndex Server
    $insindex_server = "\\PROPU2\E`$\InsuranceIndex"
    $bridgeindex_file = "BridgeSiteIndex.htm"

    #Open Session to Remote Computer
    Write-Output "Opening Remote Session to $ComputerName..." | Tee-Object $LogFile -Append
    
    $mysess = New-PSSession -ComputerName $ComputerName -Authentication Credssp -Credential $cred

    #Deploy on Target Computer

    Invoke-Command -ScriptBlock { 
        
        $SiteRoot = $args[0]
        $Licensee = $args[1]
        $WCFRoot = $args[2]
        $BuildNumber = $args[3]
        $Branch = $BuildNumber.Substring(0,3)
        $apppool_name = 'Bridge_'+$Licensee+'_AppPool'
        $BuildSource = "\\192.168.0.31\Builds\OWBridge\$Branch\$BuildNumber"

        
        Write-Output "Loading WebAdministration module..." -Verbose
        if ((Get-PSSnapin -Name WebAdministration -ErrorAction SilentlyContinue) -eq $null ){
            
            Add-PSSnapin WebAdministration

        }

        If((Get-WebAppPoolState -Name $apppool_name).value -eq 'Started'){
            Write-Output "Stopping AppPool $apppool_name" -Verbose
            Stop-WebAppPool -Name $apppool_name
        }

        #Mirror Bin From LatestBuild
        Write-Output "Mirroring MIDSWeb\bin..." -Verbose
        robocopy "$BuildSource\app\MIDSWeb\bin" "$SiteRoot\$Licensee\bin" /MIR /NP /NJS

        #Copy latest files to MIDSWeb
        Write-Output "Copying MIDSWeb..." -Verbose
        robocopy "$BuildSource\app\MIDSWeb" "$SiteRoot\$Licensee" /XD "bin" /E /NP /NJS

        #Copy WCF_Service files
        Write-Output "Copying WCF_Service..." -Verbose
        robocopy "$BuildSource\app\WCF_Service\ComplianceService" "$WCFRoot" /MIR /NP /NJS
        
        If((Get-WebAppPoolState -Name $apppool_name).value -eq 'Stopped'){

            Write-Output "Starting AppPool $apppool_name" -Verbose
            Start-WebAppPool -Name $apppool_name
        }
        
    } -Session $mysess -ArgumentList $SiteRoot, $Licensee, $WCFRoot, $BuildNumber | Tee-Object $LogFile -Append

    
    #LogOut of Remote computer Computer
    $mysess | Remove-PSSession

    Write-Output "Deploy complete..Session Exited" | Tee-Object $LogFile -Append

    #Update Insurance Index
    Write-Output "Updating Build Number on Insurance Index" | Tee-Object $LogFile -Append
    $filname = "$insindex_server\$bridgeindex_file"

    If(Test-Path $filname){

        #Save a copy of file before modifying it
        Write-Host "Saving a copy of $filname" | Tee-Object $LogFile -Append

        Get-Content "$filname"|Set-Content "$filname.tmp"

        #Read each line and if line matches the RegExp Replace with Build Number
        (Get-Content "$filname") | 
        ForEach-Object {
            If($_ -match "<a(.*)(BETA STAGING)(.*?)>(.*)</a>"){

                $first_m = $Matches[1]
                $second_m = $Matches[2]
                $third_m = $Matches[3]

                $line = "<a$first_m$second_m$third_m>$BuildNumber</a>"
                #Write-Host "Inside If: $line"
                $_ -replace "<a(.*)(BETA STAGING)(.*?)>(.*)</a>","$line"
            }else{
                $_
            }
        } | Set-Content $filname
    }else{

        Write-Output "Could not Update Insurance Index: $filname not Found" | Tee-Object $LogFile -Append

    }
    
    Write-Output "Insurance Index Updated with line: $line" | Tee-Object $LogFile -Append

    Write-Output "Back on $env:COMPUTERNAME" | Tee-Object $LogFile -Append

    Write-Output "===Deploy Complete===" | Tee-Object $LogFile -Append