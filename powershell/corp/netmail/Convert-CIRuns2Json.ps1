#Author: Praveen Chamarthi
#Create Date: 12-Nov-2014
#Last Modified: 14-Nov-2014

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
$paths = $paths | ForEach-Object { Get-ChildItem "$($_.FullName)\*" -Filter "summary*json" | Select FullName }
# Exclude Reports of CI-WIZARD
$paths = $paths | ForEach-Object { if($_ -notmatch 'WIZARD'){ $_ }}

#----- VARIABLES ------
$backends = @('EX2007','EX2010','EX2013','O365','GW8','GW2012','GW2014') #This goes into every JSON record
$build_record="" #String to store a build record
$tmp_hash = [ordered]@{} #HashTable to store Paths against the builds
$cistats = @() #Array to store JSON record for each run
[String[]]$final_json = @() #Array to Store Final Json Records
$cnt = 0 #counter to identify first record

#Analyze the build numbers first and Sort then with buildnumber and filename
#TODO: Write the Map of Build Numbers to Branch in an External CSV
#Temporary Hash Table to store Build # and Paths
$tmp_hash = [ordered]@{}
foreach($path in $paths)
{

 $path = $path."FullName"
 $json_data = (Get-Content -LiteralPath $path) -join "`n" | ConvertFrom-Json
 $build = ($json_data.build).TrimEnd()
 #Path is unique, so has to be the key in the Hash Map
 $tmp_hash.Add("$path","$build")

}
#Sort Hash table by Build Numbers
$tmp_hash = $tmp_hash.GetEnumerator() | Sort-Object Value
   
Write "# Files: $($tmp_hash.Count)"

#Loop through each entry in the hashtable and create JSON records
   foreach($p in $tmp_hash)
   {
        #Write "Counter: $cnt"
        #Write "`tParsing $($p.Key) and Build $($p.Value)..."
        
        #Read json file contents and convertfrom json to access content as an object
        $json_data = (Get-Content -LiteralPath $p.Key) -join "`n" | ConvertFrom-Json
        if($cnt -eq  0)
        {
            $prev_build = ($json_data.build).ToString().Trim()
            $prev_branch = $json_data.branch
        }
        $build = ($json_data.build).ToString().Trim()
        $branch = $json_data.branch.ToString().Trim()
        $backend = $json_data.backend.ToString().Trim()
        $percentage = $json_data.percentage.ToString().Trim()
        $runtime = $json_data.runtime.ToString().Trim()
        $cistat_record = (New-Object psobject |
            Add-Member -PassThru -NotePropertyName build -NotePropertyValue "$build" |
            Add-Member -PassThru -NotePropertyName backend -NotePropertyValue "$backend" |
            Add-Member -PassThru -NotePropertyName percentage -NotePropertyValue "$percentage" |
            Add-Member -PassThru -NotePropertyName runtime -NotePropertyValue "$runtime"
        ) | ConvertTo-Json
        #Replace all the Junk created by objects to plain text
        $cistat_record = $cistat_record -replace '\\r\\n',''
        $cistat_record = $cistat_record -replace '\\\"','"'
        $cistat_record = $cistat_record -replace '\s{4}',''
        $cistat_record = $cistat_record -replace ':\s{2}',':'
        $cistat_record = $cistat_record -replace '\s{2}',''

        if($prev_build -eq $build){
            $cistats += $cistat_record
        }
        if($prev_build -ne $build)
        {
            #Write "Build: $build ===different==="
            #commit the last record to final_json array
            $build_record = (New-Object psobject |
            Add-Member -PassThru -NotePropertyName build -NotePropertyValue "$prev_build" |
            Add-Member -PassThru -NotePropertyName branch -NotePropertyValue "$prev_branch" |
            Add-Member -PassThru -NotePropertyName backends -NotePropertyValue $backends |
            Add-Member -PassThru -NotePropertyName cistats -NotePropertyValue $cistats
            )  | ConvertTo-Json
            #Replace all the Junk created by objects to plain text
            $build_record = $build_record -replace '\\\"','"'
            $build_record = $build_record -replace '\"{','{'
            $build_record = $build_record -replace '}\"','}'
            $final_json += $build_record
            $cistats = @()
            $cistats += $cistat_record
        }
        #If its the last file read then commit last record to final_json array
        if($cnt -eq ($tmp_hash.Count -1))
        {
            Write "--Read Last File in HashTable ..."
            $build_record = (New-Object psobject |
            Add-Member -PassThru -NotePropertyName build -NotePropertyValue "$prev_build" |
            Add-Member -PassThru -NotePropertyName branch -NotePropertyValue "$prev_branch" |
            Add-Member -PassThru -NotePropertyName backends -NotePropertyValue $backends |
            Add-Member -PassThru -NotePropertyName cistats -NotePropertyValue $cistats
            )  | ConvertTo-Json
            #Replace all the Junk created by objects to plain text
            $build_record = $build_record -replace '\\\"','"'
            $build_record = $build_record -replace '\"{','{'
            $build_record = $build_record -replace '}\"','}'
            $final_json += $build_record            
        }
        $prev_build = $build
        $prev_branch = $branch
        $prev_backend = $backend
        $prev_percentage = $percentage
        $prev_runtime = $runtime
        $cnt++
   } #End of ForEach Loop
   
   #Transform final_json array to final Array 
   $final_json = $final_json -join ","
   $final_json = "[$final_json]"
   
   
   
   #Write to File
   Write "--Writing Final Records to $dest_file ---"
   $final_json | Out-File $dest_file -Encoding default
    

 