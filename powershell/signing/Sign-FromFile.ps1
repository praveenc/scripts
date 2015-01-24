param(
    [String]$PathToFile=$(throw "Must provide a PathToFile"),
    [String]$PathToBuildFolder=$(throw "Must provide a PathToBuildFolder")
)
<#
.Synopsis
   Sign Files using SignTool (Cert + TimeStamp Server)
   This script is designed to run on PowerShell v2.0 and above
.DESCRIPTION
   Reads all files to be signed under [BUILD_MA_FOLDER] from file netmail_ism_signlist.txt
   Verifies if the file is signed or not - collects all unsigned files
   Signs each file using a Random TimeStamp Server
   Verifies files again after Signing
.EXAMPLE
   Sign-FromFile -PathToFile "D:\Hudson\jobs\Archive_Trunk_MSBuild\workspace\svn\BuildScripts_withExalead\signing\netmail_ism_signlist.txt" -PathToBuildFolder "D:\Builds\Archive_Trunk_MSBuild\5.3.0.116\M+Archive\Messaging Architects"
.NOTES
   Author: Praveen Chamarthi
   Create Date: 08 May 2014
#>

if(-Not (Test-Path $PathToFile)){
    Write "***File $PathToFile doesn't exist on disk***"
    exit
}
if(-Not(Test-Path $PathToBuildFolder)){
    
    Write "***File $PathToBuildFolder doesn't exist on disk***"
    exit
}

#List of timeservers used to sign dlls
$tservers = @("http://timestamp.verisign.com/scripts/timstamp.dll",
"http://timestamp.comodoca.com/authenticode",
"http://timestamp.globalsign.com/scripts/timestamp.dll",
"http://tsa.starfieldtech.com")



$filestoSign = Import-Csv $PathToFile | ForEach-Object { "$PathToBuildFolder\$($_.FILENAME)".Trim()}

$filesnotinbuild = @()

Write "Verifying file existence.."
foreach($x in $filestoSign){
    if(-Not(Test-Path '$x' -PathType Leaf)){
        $filesnotinbuild += $filesnotinbuild
    }
}

Write "FilesNotInBuild: $($filesnotinbuild.Length)"

#Write "Verifying Signatures on files..."#

#foreach($file in $filestoSign){
#    $status = (Get-AuthenticodeSignature -FilePath $file).Status
#    if($status -ne 'Valid'){
#        Write "File $file has no Signature!!"
#    }
#}
Write "Signing files..."

foreach($file in $filestoSign){

    $signingserver = $tservers | Get-Random
    Write "Signing $file using $signingserver ..."
    & {.\signtool.exe sign /f .\MA.pfx /p m3ss4g1ng /t $signingserver $file} | Out-File "$PathToBuildFolder\logs\Archive.Sign.log"

}

Write "Verifying Signatures on files..."
foreach($file in $filestoSign){
    $status = (Get-AuthenticodeSignature -FilePath $file).Status
    if($status -ne 'Valid'){
        Write "File $file has no Signature!!"
    }
}
