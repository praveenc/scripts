<#
.Synopsis
   Launch O365 SetupWizard on Latest build on 10.10.150.28
.DESCRIPTION
   Reverts Snapshot to Zero, Sets Machine Defaults
   Copies O365 Prop_ini, Installs latest Netmail.msi build using SetupLauncher.exe
   Stops all services, Starts NetmailwebadminService.exe
   Runs WizardLauncher.exe
.EXAMPLE
   ./Launch-SetupWizard -CodeBranch Netmail_Trunk
#>

    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        # Enter the Code Branch for which the Setup Wizard needs to be run
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet("Netmail_GlenValley","Netmail_Trunk")]
        $CodeBranch
    )

#VMware variables
$vmrun = "C:\Program Files (x86)\VMware\VMware VIX\vmrun.exe"
$vm_host = "10.10.23.223"
$vmx_name = "[23_37_datastore1] CI_builds-10.10.3.103/CI_builds-10.10.3.103.vmx"
$vm_uname = "administrator"
$vm_hash = "123Password"
$vm_365host = "10.10.150.28"
$build_folder = "\\10.10.23.159\Builds\$CodeBranch\5.3.0.1469\Automation"
 
# Revert to SnapShot Zero
Write "Reverting $vmx_name to SnapShot ZERO ..."
& $vmrun -T esx -h $vm_host -u $vm_uname -p $vm_hash revertToSnapshot $vmx_name 'Zero'

# Start the 0365 CI_Builds VM 10.10.150.28
Write "Starting the VM ..."
& $vmrun -T esx -h $vm_host -u $vm_uname -p $vm_hash start $vmx_name nogui

#Sleep 120secs
Write "Waiting for system 10.10.150.28 to boot ..."
if(Test-Connection -ComputerName $vm_365host -Quiet){

    #Set some machine defaults
    Write "Setting machine defaults ..."

    # Turn FireWall off
    Write " Turning FIREWALL off ..."
    & $vmrun -T esx -h $vm_host -u $vm_uname -p $vm_hash -gu $vm_uname -gp $vm_hash runProgramInGuest $vmx_name netsh.exe advfirewall set allprofile state off

    # Set Default DNS Server to 10.200.0.9 as Primary
    Write " Setting Primary DNS Server to 10.200.0.9"
    & $vmrun -T esx -h $vm_host -u $vm_uname -p $vm_hash -gu $vm_uname -gp $vm_hash runProgramInGuest $vmx_name netsh.exe interface ipv4 set dnsservers source=static name='Ethernet 2' address=10.200.0.9 primary

    # Sync Server Time with NTP
    Write " Syncing time with ca.pool.ntp.org ..."
    & $vmrun -T esx -h $vm_host -u $vm_uname -p $vm_hash -gu $vm_uname -gp $vm_hash runProgramInGuest $vmx_name net.exe start w32time
    & $vmrun -T esx -h $vm_host -u $vm_uname -p $vm_hash -gu $vm_uname -gp $vm_hash runProgramInGuest $vmx_name w32tm.exe /config /syncfromflags:manual /manualpeerlist:ca.pool.ntp.org /update
    & $vmrun -T esx -h $vm_host -u $vm_uname -p $vm_hash -gu $vm_uname -gp $vm_hash runProgramInGuest $vmx_name w32tm.exe /resync

    Write " Enabling PS Remoting on host ..."
    & $vmrun -T esx -h $vm_host -u $vm_uname -p $vm_hash -gu $vm_uname -gp $vm_hash runProgramInGuest $vmx_name powershell.exe -Command "{Enable-PSRemoting -Force}"    

    # Make credential object for System Login
    $uname = "administrator"
    $pass = cat .\login_securestring_150_28.txt | ConvertTo-SecureString
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $uname, $pass

    # Make credential object for Mapping Builds folder (\\10.10.23.159\Builds)
    $share_uname = "ci_user"
    $share_pass = cat .\buildmc_securestring_150_28.txt | ConvertTo-SecureString
    $share_cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $share_uname, $share_pass
    
    # Copy ini file contents
    $ini = Get-Content .\Props_10.10.150.28.ini

    $sess = New-PSSession -ComputerName 10.10.150.28 -Credential $cred -Authentication Credssp

    if(-not $sess){
        Write "Something wrong with Session object ..."
    }

    Invoke-Command -Session $sess -ScriptBlock {
        
        $cred = $args[0]
        $branch = $args[1]
        $ini = $args[2]

        $build_share = "\\10.10.23.159\Builds"
        
        Write "Mapping Build folder to K drive ..."
        New-PSDrive -Name "K" -PSProvider FileSystem -Root $build_share -Credential $cred

        $last_success = Get-Content K:\$branch\lastsuccess.txt
        $ci_folder = "C:\NetmailArchiveScripts"

        If(-not(Test-Path $ci_folder)){
            Write "creating folder $ci_folder ..."
            New-Item -Path $ci_folder -ItemType directory
        }

        #Copying Automation folder from last successful build
        Write "Using"
        robocopy $build_share\$branch\$last_success\Automation $ci_folder /E /XN /NP /NFL /NDL

        $ini_dir = "$ci_folder\Configurations\O365\WizardPlayback"

        If(-not(Test-Path $ini_dir)){
            Write "Creating folder $ini_dir ..."
            New-Item -Path "$ini_dir" -ItemType directory
        }
        
        Write "Writing Props_10.10.150.28.ini to $ini_dir ..."
        Set-Content -Path "$ini_dir\Props_10.10.150.28.ini" -Value $ini -Encoding Default

        #At this point we install the latest build using SetupLauncher.exe
        Write "Call SetupLauncher.exe ..."
        # TYPE=archive CONFIG=c:\\NetmailArchiveScripts\\Configurations\\Common\\Setups\\netmailsetup_NoSA.iss PLAYBACKFILE=c:\\NetmailArchiveScripts\\Configurations\\O365\\WizardPlayback\\PlaybackWithExalead.json PLAYBACKFILEPRMS=c:\\NetmailArchiveScripts\\Configurations\\O365\\WizardPlayback\\Props_10.10.150.28.ini ModuleResultPath=
        & $ci_folder\SetupLauncher.exe TYPE=archive `
                                      CONFIG=$ci_folder\Configurations\Common\Setups\netmailsetup_NoSA.iss `
                                      PLAYBACKFILE=$ci_folder\Configurations\O365\WizardPlayback\PlaybackWithExalead.json `
                                      PLAYBACKFILEPRMS=$ci_folder\Configurations\O365\WizardPlayback\Props_10.10.150.28.ini `
                                      ModuleResultPath=$ci_folder\PS_Results.txt
        
        # Stop Services started by setup.sh
        Write "Stopping Service MAOpen ..."
        Stop-Service -Name MAOpen

        Write "Stopping Service GWA_XMLV_SVC ..."
        Stop-Service -Name GWA_XMLV_SVC | Wait-Process

        Write "Stopping Service AWA_XMLV_SVC ..."
        Stop-Service -Name AWA_XMLV_SVC | Wait-Process

        Write "Stopping Service NDS Server0 ..."
        Stop-Service -Name "NDS Server0" | Wait-Process
    
        Write "Starting NetmailwebadminService ..."
        Start-Service -Name NetmailwebadminService | Wait-Process

        #Disable HTTP to HTTPS redirection for CI testing
        & setx NETMAIL_WARPD_OPTIONS "" /M
        & setx NETMAIL_WARPD_REDIRECT 0 /M

        Write "Calling WizardLauncher.exe ..."
        & curl http://10.10.150.28:8686/start?command=C:\NetmailArchiveScripts\WizardLauncher.exe
        
    } -ArgumentList $share_cred, $CodeBranch, $ini


}





