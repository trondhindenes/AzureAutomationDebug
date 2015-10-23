Param (
$name, $salt1,$salt2
)

function Encrypt-String($String, $Passphrase, $salt="SaltCrypto", $init="IV_Password", [switch]$arrayOutput)
{
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
	
	# Starts the New Encryption using the Key and IV   
	$c = $r.CreateEncryptor()
	# Creates a MemoryStream to do the encryption in
	$ms = new-Object IO.MemoryStream
	# Creates the new Cryptology Stream --> Outputs to $MS or Memory Stream
	$cs = new-Object Security.Cryptography.CryptoStream $ms,$c,"Write"
	# Starts the new Cryptology Stream
	$sw = new-Object IO.StreamWriter $cs
	# Writes the string in the Cryptology Stream
	$sw.Write($String)
	# Stops the stream writer
	$sw.Close()
	# Stops the Cryptology Stream
	$cs.Close()
	# Stops writing to Memory
	$ms.Close()
	# Clears the IV and HASH from memory to prevent memory read attacks
	$r.Clear()
	# Takes the MemoryStream and puts it to an array
	[byte[]]$result = $ms.ToArray()
	# Converts the array from Base 64 to a string and returns
	return [Convert]::ToBase64String($result)
}

$Cred = Get-automationPsCredential -name $name
$CredUserName = $cred.username
$CredPasswordClear = $cred.GetnetworkCredential().Password
$CredPasswordEncrypted = Encrypt-String -String $CredPasswordClear -salt $salt1 -Passphrase $salt2

$CredObj = "" | Select Username, Password
$CredObj.username = $CredUserName
$CredObj.Password = $CredPasswordEncrypted

return $CredObj | convertto-json