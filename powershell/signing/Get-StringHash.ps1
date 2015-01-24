function Hash($textToHash)

{

    $hasher = new-object System.Security.Cryptography.SHA256Managed

    $toHash = [System.Text.Encoding]::UTF8.GetBytes($textToHash)

    $hashByteArray = $hasher.ComputeHash($toHash)

    foreach($byte in $hashByteArray)

    {

         $res += $byte.ToString()

    }

    return $res;

}