param(

    [String]$buildnumber,
    [String[]]$workspaces,
    [String]$svntagpath="tags/GlenValley"
)

#$buildnumber = (Get-Content env:BUILD_NUMBER)

if($buildnumber){

    foreach($ws in $workspaces){

        Write "Workspace: $ws"
        
        $lastrev = (Get-Content -Path "$ws\lastrev.txt")
        $lastrev = $lastrev -match '\sRev\:\s(\d{6})'
        $lastrev = $lastrev -replace "(.*?)\:\s",""

        Write "Last Change Rev: $lastrev"

        if(($ws -match 'svn$') -and ($lastrev -match '\d{6}')){

            $svnfrom = "svn+ssh://svn.myserver.com/archive/trunk@$lastrev"
            $svnto = "svn+ssh://svn.myserver.com/archive/$svntagpath/$buildnumber"
        }
        if(($ws -match 'netmail_platform$') -and ($lastrev -match '\d{6}')){
            
            $svnfrom = "svn+ssh://svn.myserver.com/netmail/branches/platform-nma-5.3.0-glenvalley@$lastrev"
            $svnto = "svn+ssh://svn.myserver.com/netmail/$svntagpath/$buildnumber"
        }
        if($svnfrom -and $svnto){
            
            Invoke-Command {svn cp $svnfrom $svnto -m "Auto Tagging: for build $buildnumber"} -ErrorVariable tagerr

            if($tagerr){

                Write "*** -- Errors tagging this build -- **"
                $tagerr
            }

        }
        
    }

}else{

    Write "*** ERROR: No buildnumber - Please pass BUILD_NUMBER as parameter to the script"
    exit
}


