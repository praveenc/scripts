Param(

    <#
    .Synopsis
       Merges given set of builds into a Single folder
    .DESCRIPTION
       Copies latest app, BridgeNewDB, Cognos, CognosAutomation, JobQueue from Latest Build
       Traverses through all the build folders and copies Deployment Instructions, db-Combine, DW scripts to TargetFolder
       Writes progress to LogFile
       This process is non-destructive - doesn't modify the original build folders contents
    .EXAMPLE
       Merge-BridgeBuilds -FromBuildNumber 2.2.2.01 -ToBuildNumber 2.2.2.19 -TargetDirectory D:\BridgeMerge
    .NOTES
       Author: Praveen Chamarthi
       Create Date: 26 Sep 2013
       Modified Date: 27 Jan 2014

    #>
    [CmdletBinding()]
    [Parameter(Mandatory=$true,
               Position=0,
               HelpMessage="First BuildNumber in Merge Package  e.g. 2.2.2.01")]
    [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{2,3}")]
    [String]$FromBuildNumber,

    [Parameter(Mandatory=$true,
               Position=1,
               HelpMessage="Last BuildNumber (inclusive) in Merge Package  e.g. 2.2.2.19")]
    [ValidatePattern("\d\.\d{1,2}\.\d{1,2}\.\d{2,3}")]
    [String]$ToBuildNumber,

    [Parameter(Mandatory=$true,
               Position=2,
               HelpMessage="Log Dir Path")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [String]$TargetDirectory
)
    
    $WorkingDir = (Get-Location -PSProvider FileSystem).ProviderPath
    [Environment]::CurrentDirectory=$WorkingDir

    if(Test-Path -Path "$WorkingDir\OW-CMTools.ps1" -PathType Leaf){
        Write "--- Loading OW-CMTools.ps1 to current scope ..." -Verbose
        . .\OW-CMTools.ps1
    }else{
        Write "*** ERROR: OW-CMTools.ps1 is required in $WorkingDir ***" -Verbose
        exit
    }

    $host_name = [System.Net.Dns]::GetHostName()
    
    if($host_name -eq "PRB1DPA1"){
        
        $build_repository = "E:\Builds\OWBridge"

    }else{

        $build_repository = "\\192.168.0.31\Builds\OWBridge"
    }
    $is_frombuild = $false
    $is_tobuild = $false
    $final_merge_folder = "$TargetDirectory\$FromBuildNumber-$ToBuildNumber"
    $LogDirectory = "$final_merge_folder\log"
    $log_file = "$LogDirectory\Merge-$FromBuildNumber-$ToBuildNumber.log"
    


    #Create Log Directory if not exist
    if(-Not (Test-Path $LogDirectory -PathType Container)){
        mkdir $LogDirectory | Out-Null
    }

    #Create final Merge Folder if not exist
    if(-Not (Test-path $final_merge_folder -PathType Container)){
    
        Write "--- Creating $final_merge_folder" | Tee-Object -FilePath $log_file -Append
        mkdir $final_merge_folder | Out-Null

    }

    Write "--- Validating Build Numbers and Directories... " | Tee-Object -FilePath $log_file -Append
    #Check if Passed build numbers exist
    if($FromBuildNumber -match "(\d\.\d{1,2})(\.\d{1,2}\.)(\d{2,3})" ){

        $from_short_releasenum = $Matches[1]
        $from_releasenum = $from_short_releasenum + $Matches[2]
        $from_buildsuffix = $Matches[3]
        
        if(-Not (Test-Path "$build_repository\$from_short_releasenum\$FromBuildNumber" -PathType Container)){
            
            Write " ** Cannot find $FromBuildNumber in $build_repository\$from_short_releasenum ..." |
                Tee-Object -FilePath $log_file -Append
            #return

        }else{
            
            $is_frombuild = $true
        }
    }
    if($ToBuildNumber -match "(\d\.\d{1,2})(\.\d{1,2}\.)(\d{2,3})" ){
        
        $to_short_releasenum = $Matches[1]
        $to_releasenum = $to_short_releasenum + $Matches[2]
        $to_buildsuffix = $Matches[3]
        
        if(-Not (Test-Path "$build_repository\$to_short_releasenum\$ToBuildNumber" -PathType Container)){
            
            Write " ** Cannot find $ToBuildNumber in $build_repository\$to_short_releasenum ..." |
                Tee-Object -FilePath $log_file -Append
            return

        }else{
          
            $is_tobuild = $true
        }
    }
    if($from_releasenum -ne $to_releasenum){

      Write " ** Release number mismatch $from_releasenum, $to_releasenum - you can only merge builds in the same release " |
            Tee-Object -FilePath $log_file -Append
      return

    }else{
      
      $build_threedigit_prefix = $from_releasenum
      $release_num = $from_short_releasenum

    }

    $build_repository += "\$release_num"

    #If all build folders exist then start the Process
    if($is_frombuild -and $is_tobuild){
        
        Write "********************** Merge Builds Start **********************" | Tee-Object -FilePath $log_file -Append
                                                                  
        Write "--- Copying Latest app, BridgeNewDB, Cognos, CognosAutomation, Datawarehouse, JobQueue from $ToBuildNumber " |
                                        Tee-Object -FilePath $log_file -Append
        $exclude_folders = @("log", "Deployment", "db-Combine", "Incremental")
        #First copy latest version of app, JobQueue, Cognos, MIDSInitDB, CognosAutomation from the Last Build
        robocopy "$build_repository\$ToBuildNumber" "$final_merge_folder" /XD $exclude_folders /MIR /NP /NJS | Out-Null

        $builds_with_scripts = @()
        
        #Find builds with incremental DBScripts, Deployment Instructions & Cognos
        $from_buildsuffix..$to_buildsuffix |

       ForEach-Object {
              if($_.ToString().Length -eq 1){
                $suffix = "0" + $_.ToString()
              }else{
                $suffix = $_.ToString()
              }
              $fldr_name = "$build_threedigit_prefix$suffix"
              #Write Progress Bar
              Write-Progress -Activity "Scanning Build Folders..." -PercentComplete $_ `
                  -CurrentOperation "Scanning $fldr_name" -Status "This may take a while..."
                
              if(Get-ChildItem -Path "$build_repository\$fldr_name" -Recurse -Directory -Filter "db-Combine"){

                $builds_with_scripts += $fldr_name

              }
              if(Get-ChildItem -Path "$build_repository\$fldr_name" -Recurse -Directory -Filter "Deployment"){

                $builds_with_scripts += $fldr_name

              }
              if(Get-ChildItem -Path "$build_repository\$fldr_name" -Recurse -Directory -Filter "Cognos"){

                $builds_with_scripts += $fldr_name

              }
           }
        
        Write-Progress -Activity "Scanning Build Folders..." -Completed -Status "All done."

        #Remove duplicates in an array
        $builds_with_scripts = $builds_with_scripts | Select -Unique

        Write "--- Following builds have incremental dbscripts or deploy instructions or cognos: $builds_with_scripts" |
                                  Tee-Object -FilePath $log_file -Append

        #Copy all Incremental Deployment Instructions, db-Combine, Datawarehouse folders
        Write "--- Merging incremental scripts & deploy ins from builds" | Tee-Object -FilePath $log_file -Append


        #Recurse through each build that has either dbCombine or Deploy ins or Incremental Cognos and copy them to Target
        foreach($incbuild in $builds_with_scripts){
          
          $buildsrc_root = "$build_repository\$incbuild"
          
          #Set Source Directory based on folder Structure - New struct has db-Combine under Incremental, old has it in root
          if(Get-ChildItem -Path $buildsrc_root -Recurse -Directory -Filter "Incremental"){
            
            $dbcombine_src = "$buildsrc_root\Incremental\db-Combine\$incbuild"
            $deployins_src = "$buildsrc_root\Incremental\Deployment"
            $cognos_src = "$buildsrc_root\Incremental\Cognos"

          }else{

            $dbcombine_src = "$buildsrc_root\db-Combine\$incbuild"
            $deployins_src = "$buildsrc_root\app\Deployment"

          }
          
          #If db-Combine folder exists then Copy to Incremental/db-Combine
          if(Test-Path $dbcombine_src -PathType Container){
            
              Write "--- Copying db-Combine artifacts from $incbuild" | Tee-Object -FilePath $log_file -Append

              $dbc_tgt = "$final_merge_folder\Incremental\db-Combine"
              if(-Not (Test-Path -Path $dbc_tgt -PathType Container)){

                    mkdir $dbc_tgt | Out-Null

              }

              $exclude_files = @("*.cre","*.cpa")
              $dbc_DBScripts_src = "$dbcombine_src\DBScripts"
              $dbc_StoredProc_src = "$dbcombine_src\stored procedures"
              #$dbc_Functions_src = "$dbcombine_src\functions"
              #$dbc_Views_src = "$dbcombine_src\views"

              robocopy "$dbcombine_src" "$dbc_tgt" *.sql /XF $exclude_files /NP /NJS
              if(Test-Path $dbc_DBScripts_src -PathType Container){
                
                robocopy "$dbc_DBScripts_src" "$dbc_tgt\DBScripts" *.sql /XF $exclude_files /NP /NJS >> $log_file

              }
              if(Test-Path $dbc_StoredProc_src -PathType Container){

                robocopy "$dbc_StoredProc_src" "$dbc_tgt\stored procedures" *.sql /XF $exclude_files /NP /NJS >> $log_file

              }
#              if(Test-Path $dbc_Functions_src -PathType Container){
#
#                robocopy "$dbc_Functions_src" "$dbc_tgt\functions" *.sql /XF $exclude_files /NP /NJS >> $log_file
#
#              }
#              if(Test-Path $dbc_Views_src -PathType Container){
#
#                robocopy "$dbc_Views_src" "$dbc_tgt\views" *.sql /XF $exclude_files /NP /NJS >> $log_file
#
#              }
          }
          
          #If Deployment Instructions exists then Copy to Incremental/Deployment
          if(Test-Path $deployins_src -PathType Container){
            
            $deployins_tgt = "$final_merge_folder\Incremental\Deployment"
            if(-Not (Test-Path -Path $deployins_tgt -PathType Container)){

                    mkdir $deployins_tgt | Out-Null

            }

            Write "--- Copying Deployment Instructions from $incbuild" | Tee-Object -FilePath $log_file -Append

            robocopy "$deployins_src" "$deployins_tgt" *.txt /NP /NJS >> $log_file

          }
          #If Incremental Cognos exists then Copy to Incremental/Cognos; Including Destination
          if(Test-Path $cognos_src -PathType Container){
            
            $deployins_tgt = "$final_merge_folder\Incremental\Cognos"
            if(-Not (Test-Path -Path $deployins_tgt -PathType Container)){

                    mkdir $deployins_tgt | Out-Null

            }

            Write "--- Copying Cognos Incremental artifacts from $incbuild" | Tee-Object -FilePath $log_file -Append

            robocopy "$cognos_src" "$deployins_tgt" /S /NP /NJS >> $log_file

          }

        } #End of For Loop

        #Create Combine Package of all the Merged Scripts
        if(Test-Path $dbc_tgt -PathType Container){

            Write "--- Creating combine package.." | Tee-Object -FilePath $log_file -Append

            Create-OWCombinePackage -PackageName "$ToBuildNumber-Merged" -ScriptsFolder "$dbc_tgt" -Container "NA"
        
        }

        Write "********************** Merge Builds Complete **********************" | Tee-Object -FilePath $log_file -Append

    }