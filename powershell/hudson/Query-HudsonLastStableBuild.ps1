$netmailtrunk_uri = "http://10.10.23.159:8070/job/{job_name}/"


$content = Invoke-WebRequest -Uri $netmailtrunk_uri
$links = $content.Links

$links | 
    % { if($_.href -match "lastStableBuild")
        {
            $_.outerText -match "\(\#(\d{4,5})\)" | Out-Null
            $lastStableBuild = $Matches[1]

        }
        if($_.href -match "lastFailedBuild"){

            $_.outerText -match "\(\#(\d{4,5})\)" | Out-Null
            $lastFailedBuild = $Matches[1]
        }

      }

Write "Last Stable Build: $lastStableBuild"
Write "Last Failed Build: $lastFailedBuild"
