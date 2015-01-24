function Send-NMEmail
{
    <#
    .Synopsis
       Sends Email using Send-MailMessage CmdLet
    .DESCRIPTION
       Sends Email using Send-MailMessage Cmdlet - Accepts (Ignores) the default Certificate
       Uses "buildmachine" account to send email
    .EXAMPLE
       Send-NMEmail -FromAddress "BuildMaster@netmail.com" -ToAddress "praveenc@netmail.com" -Subject "Testing cod mail" -Body "cod mail"
    #>
    [CmdletBinding()]
    Param
    (
        # FromAddress
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidatePattern("(.*?)\@(.*?)\.com")]
        [ValidateNotNullOrEmpty()]
        [String]$FromAddress,

        # ToAddress 
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidatePattern("(.*?)\@(.*?)\.com")]
        [ValidateNotNullOrEmpty()]
        [String[]]$ToAddress,

        # Subject 
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [ValidateNotNullOrEmpty()]
        [String]$Subject,
        
        # Body 
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=3)]
        [ValidateNotNullOrEmpty()]
        [String]$Body,

        #File to Attach (Full Path)
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=4)]
        [String]$FileToAttach


    )

    Begin
    {
        $strSMTP = "10.200.1.80"
        $strFrom = "$FromAddress"
        $strTo = "$ToAddress"
        $strSub = "$Subject"
        $strBody = $Body
        $smtp_user="buildmachine"
        $smtp_pass= cat .\mail_securestring.txt | ConvertTo-SecureString
        $smtp_cred = New-Object System.Management.Automation.PSCredential -ArgumentList $smtp_user, $smtp_pass

    }
    Process
    {
        

        $message = New-Object System.Net.Mail.MailMessage ($strFrom, $strTo)
        #$message.From = $strFrom
        #$message.To = $strTo
        [System.Net.Mail.MailAddress]$cc = New-Object System.Net.Mail.MailAddress("praveenc@netmail.com")
        $message.Subject = $strSub
        $message.Body = $strBody
        $message.CC.Add($cc)

        #Use SMTP MSA Port 587 to relay message
        $client = New-Object System.Net.Mail.SmtpClient ("10.200.1.80",587)
        $client.Host = "10.200.1.80"
        $client.Port = 587
        $client.EnableSsl = $true
        $client.UseDefaultCredentials = $false
        $client.Credentials = $smtp_cred #New-Object System.Net.NetworkCredential ("buildmachine", $(Read-Host -Prompt "Enter" -AsSecureString))

        #Set ServerCertificateValidationCallback to True by force
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }

        $client.Send($message)

    }
    End
    {   
        Write-Output "Email delivered Successfully to $to"
    }
}