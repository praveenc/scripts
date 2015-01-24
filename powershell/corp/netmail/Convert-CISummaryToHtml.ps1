#Author: Praveen Chamarthi
#Create Date: 06-Dec-2014

#Honor exit codes
$ErrorActionPreference = 'Stop'

$reports_src_dir="\\10.10.150.27\Reports"
$reports_dest_dir="E:\git\sites\ci_website\data"

$dt = (Get-Date).AddDays(-1)
# Date Format 3 on Win2008 R2 returns 2014-11-24 like string
# Date Format 5 on Win 8.1 returns 2014-11-24 like string
$dt = $dt.GetDateTimeFormats()[5].ToString()

if(-Not (Test-Path $reports_src_dir))
{
    Write "*** Source Dir: $reports_src_dir not found! ***"
    exit 1
}

If(-Not (Test-Path $reports_dest_dir))
{
   New-Item -Path $reports_dest_dir -ItemType Directory -Force | Out-Null
}

$dest_file = [IO.Path]::Combine($reports_dest_dir,"$($dt)_Archive.json")

$day_of_week = (Get-Date).DayOfWeek
Write "--Fetching Report Folders for $day_of_week"

#Get Directories modified in the last 24 hours
$srcdirs = Get-ChildItem -Path $reports_src_dir -Directory | 
            Where-Object { $_.LastWriteTime -gt ((Get-Date).AddDays(-1))} | Select FullName


#Get Directories (FullPath) modified in the last 24 hours - because one directory contains runs from previous day as well
if($day_of_week -eq "Monday")
{
    Write "-- Today is Monday: Check for runs over the weekend"
}

$paths = $srcdirs | 
            ForEach-Object { 
                Get-ChildItem "$($_.FullName)\*" -Directory | 
                Where-Object { $_.LastWriteTime -gt ((Get-Date).AddHours(-23))}
            } | Select FullName

# From the Directory list, Get only the Summary*.JSON files
$paths = $paths | ForEach-Object { Get-ChildItem "$($_.FullName)\*" -Filter "summary*eml" | Select FullName }
# Exclude Reports of CI-WIZARD
$paths = $paths | ForEach-Object { if($_ -notmatch 'WIZARD'){ $_ }}

#----- VARIABLES ------
#Temporary Hash Table to store Build # and Paths
$records = @()
foreach($path in $paths)
{

 $path = $path."FullName"
 if(Test-Path $path){
     $eml_content = Get-Content -LiteralPath $path
 
     $rec_hash = @{}
     #Get Build Number, backend and percentage values
     $buildnum = ($eml_content[17..23][1]).Replace('Build: ','')
     $backend = ($eml_content[17..23][2]).Replace('Suite: ','')
     $success = ($eml_content[17..23][5] -replace '^.*?\(','').Replace(')','')
 
     $rec_hash.Add('BUILD',$buildnum)
     $rec_hash.Add('SUITE',$backend)
     $rec_hash.Add('PERCENT',$success)
     $records += $rec_hash
 }else{
    Write "$path not found!"
 }
}

$records
exit 0