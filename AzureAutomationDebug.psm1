$thismodulepath = $psscriptroot

$ConfigObject = get-content (Join-Path $thismodulepath "config.json") -raw | ConvertFrom-Json

$AAUserName = $ConfigObject.AAUsername
$AAPassword = $ConfigObject.AAPassword
$AutomationAccount = $ConfigObject.AutomationAccount
$AutomationResourceGroup = $ConfigObject.AutomationResourceGroup

$cred = New-Object System.Management.Automation.PSCredential($AAUserName,($AAPassword | ConvertTo-SecureString -AsPlainText -Force))

Login-AzureRmAccount -Credential $cred

function Decrypt-String($Encrypted, $Passphrase, $salt="SaltCrypto", $init="IV_Password")
{
	# If the value in the Encrypted is a string, convert it to Base64
	if($Encrypted -is [string]){
		$Encrypted = [Convert]::FromBase64String($Encrypted)
   	}

	# Create a COM Object for RijndaelManaged Cryptography
	$r = new-Object System.Security.Cryptography.RijndaelManaged
	# Convert the Passphrase to UTF8 Bytes
	$pass = [Text.Encoding]::UTF8.GetBytes($Passphrase)
	# Convert the Salt to UTF Bytes
	$salt = [Text.Encoding]::UTF8.GetBytes($salt)

	# Create the Encryption Key using the passphrase, salt and SHA1 algorithm at 256 bits
	$r.Key = (new-Object Security.Cryptography.PasswordDeriveBytes $pass, $salt, "SHA1", 5).GetBytes(32) #256/8
	# Create the Intersecting Vector Cryptology Hash with the init
	$r.IV = (new-Object Security.Cryptography.SHA1Managed).ComputeHash( [Text.Encoding]::UTF8.GetBytes($init) )[0..15]


	# Create a new Decryptor
	$d = $r.CreateDecryptor()
	# Create a New memory stream with the encrypted value.
	$ms = new-Object IO.MemoryStream @(,$Encrypted)
	# Read the new memory stream and read it in the cryptology stream
	$cs = new-Object Security.Cryptography.CryptoStream $ms,$d,"Read"
	# Read the new decrypted stream
	$sr = new-Object IO.StreamReader $cs
	# Return from the function the stream
	Write-Output $sr.ReadToEnd()
	# Stops the stream	
	$sr.Close()
	# Stops the crypology stream
	$cs.Close()
	# Stops the memory stream
	$ms.Close()
	# Clears the RijndaelManaged Cryptology IV and Key
	$r.Clear()
}

<#
Function Get-AutomationPSCredential
{
    Param ([string]$Name)


    #Generate salt
    $alphabet=$NULL;For ($a=65;$a –le 90;$a++) {$alphabet+=,[char][byte]$a }
    For ($loop=1; $loop –le 32; $loop++) {
            $Salt1+=($alphabet | GET-RANDOM)
    }

    For ($loop=1; $loop –le 32; $loop++) {
            $Salt2+=($alphabet | GET-RANDOM)
    }
    
    $Params = @{"CredName"=$name;"Salt1"=$Salt;"Salt2"=$Salt}

    $job = Start-AzureRmAutomationRunbook -name "Get-PSCredential" -Parameters $Params -ResourceGroupName $AutomationResourceGroup -AutomationAccountName $AutomationAccount
    do {
        $job = $job | Get-AzureRmAutomationJob
    }
    until ($job.Status -eq "completed")
    
    $Output = Get-AzureRmAutomationJobOutput -Id $job.Id -ResourceGroupName $AutomationResourceGroup -AutomationAccountName $AutomationAccount
    $OutObj = $Output.Text | ConvertFrom-Json
}
#>
Function Get-AutomationVariable
{
    Param ($name)
    $return = Get-AzureRmAutomationVariable -Name $name -ResourceGroupName $AutomationResourceGroup -AutomationAccountName $AutomationAccount
    $return.Value
}

