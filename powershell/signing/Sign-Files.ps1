param(
    [String[]]$FilesToSign
)

$tservers = @("http://timestamp.verisign.com/scripts/timstamp.dll",
"http://timestamp.comodoca.com/authenticode",
"http://timestamp.globalsign.com/scripts/timestamp.dll",
"http://tsa.starfieldtech.com")


foreach($file in $FilesToSign){
    
    Write "Checking FileVersion on $file ..."
    $fileversion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$file").FileVersion
    $fileversion
    if($fileversion -match "1\.0\.0\.0"){
        Write "***Netmail Version is not set on $file***"
    }

    $signingserver = $tservers | Get-Random
    Write "Signing $filename using $signingserver ..."
    & {.\signtool.exe sign /f .\MA.pfx /p m3ss4g1ng /t $signingserver $file}


}