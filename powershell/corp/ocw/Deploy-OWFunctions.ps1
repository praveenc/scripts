$appcmdexe = "C:\Windows\System32\inetsrv\appcmd.exe"
#Start IIS AppPool USING appcmd
function Stop-AppPool($AppPoolName){

    $is_apppool = $false
    $app_pools = & $appcmdexe list apppool

    #Find if AppPool Exist
    foreach($apool in $app_pools){
        if($apool -match "$AppPoolName"){
            $is_apppool = $true
        }
    }

    if($is_apppool){

        Write "... Stopping $AppPoolName"
        & $appcmdexe stop apppool $AppPoolName

    }else{

        Write "Not Found AppPool $AppPoolName..skipping"
        return
    }
    
}
#Stop IIS AppPool USING appcmd
function Start-AppPool($AppPoolName){

    $is_apppool = $false
    $app_pools = & $appcmdexe list apppool

    #Find if AppPool Exist
    foreach($apool in $app_pools){
        if($apool -match "$AppPoolName"){
            $is_apppool = $true
        }
    }

    if($is_apppool){

        Write "... Starting $AppPoolName"
        & $appcmdexe start apppool $AppPoolName

    }else{

        Write "Not Found AppPool $AppPoolName..skipping"
        return
    }
    
}
#Enables Specified Nagios Alerts
function Enable-OWNagiosAlerts(
        $Name,
        $CurlExePath="d:\utilities",
        $NagiosURL="http://itmon.myserver.com/nagios/cgi-bin/cmd.cgi",
        $NagiosUID="builduser",
        $NagiosPW="pass1word"
){
    
        $CurlExe = "$CurlExePath\curl.exe"
        If(-Not (Test-Path $CurlExe -PathType Leaf) ){

            Write "Can't find Curl on Disk at $CurlExe. Try rerunning with -CurlExePath option" -Verbose
            return
        }

        #Prepare Arguments to pass on to Curl
        $arg1 = "-d"
        $arg2 = "cmd_typ=28&cmd_mod=2&host=$Name&btnSubmit=Commit"
        $arg3 = "$NagiosURL"
        $arg4 = "-u"
        $arg5 = $NagiosUID+':'+$NagiosPW

        try{

            #Call Curl with above arguments
            & $CurlExe $arg1 $arg2 $arg3 $arg4 $arg5
        
        }catch{
            
            Write-Warning "Error Executing: $CurlExe $arg1 $arg2 $arg3 $arg4 $arg5" -Verbose
    
        }
    
}
#Disables Specified Nagios Alerts
function Disable-OWNagiosAlerts
(
        $Name,
        $CurlExePath="d:\utilities",
        $NagiosURL="http://itmon.myserver.com/nagios/cgi-bin/cmd.cgi",
        $NagiosUID="builduser",
        $NagiosPW="pass1word"

){
    
        $CurlExe = "$CurlExePath\curl.exe"
        If(-Not (Test-Path $CurlExe -PathType Leaf) ){

            Write "Can't find Curl on Disk at $CurlExe. Try rerunning with -CurlExePath option" -Verbose
            return
        }

        #Prepare Arguments to pass on to Curl
        $arg1 = "-d"
        $arg2 = "cmd_typ=29&cmd_mod=2&host=$Name&btnSubmit=Commit"
        $arg3 = "$NagiosURL"
        $arg4 = "-u"
        $arg5 = $NagiosUID+':'+$NagiosPW

        try{

            #Call Curl with above arguments
            & $CurlExe $arg1 $arg2 $arg3 $arg4 $arg5
        
        }catch{
            
            Write-Warning "Error Executing: $CurlExe $arg1 $arg2 $arg3 $arg4 $arg5" -Verbose
    
        }
    
}
