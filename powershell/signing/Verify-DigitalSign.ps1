<#
.Synopsis
   Verifies DigitalSignature on File
.DESCRIPTION
   Verifies status of DigitalSignature on File
.EXAMPLE
   Verify-DigitalSign -FilesToVerify snmpd.dll,snmpservice.exe
.INPUTS
   [String[]]FilesToVerify
.OUTPUTS
   Spits out Files that are Not Signed or with Invalid Digital Signatures.
.NOTES
   Author: Praveen Chamarthi
   Create Date: 05/05/2014
.FUNCTIONALITY
   Retrieves Digital Signature from a file and its status
   If Signed and Valid Status string will be set to "Valid"
   If Not Signed Status string will be set to "Invalid"
   If File has no Digital Signature Status string will be set to "UnknownError"
#>
param(  
    [String[]]$FilesToVerify
)

if($FilesToVerify.Length -gt 0){
    
    $invalid = @()

    foreach($file in $FilesToVerify){

      $status = (Get-AuthenticodeSignature $file).Status
        
      if($status -ne "Valid"){
          Write-Output "Verifying $file ... STATUS: $status"
          $invalid += $file
      }

    }
    if($invalid.Length -gt 0){
        Write-Output "*** Found Invalid Files: $invalid"
    }

}else{
    Write-Output "*** No Files to Verify ***"
}