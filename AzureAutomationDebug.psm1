$thismodulepath = $psscriptroot

if (test-path "azureautomationdebugconfig.json")
{
    $configfile = get-item "azureautomationdebugconfig.json"
}
Else
{   
    $ConfigFile = Join-Path $thismodulepath "azureautomationdebugconfig.json"
}
Write-verbose "Loading settings from $($configfile.fullname)"
$ConfigObject = get-content $configfile -raw | ConvertFrom-Json



. $thismodulepath\Connect-AzureRest.ps1

#Test credxml first
$AACredsPath = $ConfigObject.AACredentialsXmlPath
if (test-path $AACredsPath)
{
    Write-verbose "Loading creds from $AACredsPath"
    $Cred = Import-Clixml $AACredsPath
    $AAUsername = $cred.username
    $AAPassword = $Cred.GetNetworkCredential().Password

}
Else
{
    Write-verbose "Loading creds from json config"
    $AAUserName = $ConfigObject.AAUsername
    $AAPassword = $ConfigObject.AAPassword
    $cred = New-Object System.Management.Automation.PSCredential($AAUserName,($AAPassword | ConvertTo-SecureString -AsPlainText -Force))
}


$AutomationAccount = $ConfigObject.AutomationAccount
$AutomationResourceGroup = $ConfigObject.AutomationResourceGroup
$subscriptionId = $configobject.SubscriptionId



write-verbose "Logging in to Azure"
$null = Login-AzureRmAccount -Credential $cred

$null = Select-azureRMsubscription -SubscriptionId $subscriptionId

Write-Verbose "Logging in to Azure Rest api"
$Token = Connect-AzureRest -username $AAUserName -password $AAPassword
if (!$token) {write-error "Could not authenticate";exit}

function Decrypt-String
{
    Param (
        $Encrypted, 
        $Passphrase, 
        $salt="SaltCrypto", 
        $init="IV_Password"
    )
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


Function Get-AutomationPSCredential
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential])]
    Param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$Name
    )


    #Generate salt
    $alphabet=$NULL;For ($a=65;$a –le 90;$a++) {$alphabet+=,[char][byte]$a }
    For ($loop=1; $loop –le 32; $loop++) {
            $Salt1+=($alphabet | GET-RANDOM)
    }

    For ($loop=1; $loop –le 32; $loop++) {
            $Salt2+=($alphabet | GET-RANDOM)
    }
    
    $Params = @{"Name"=$name;"Salt1"=$Salt1;"Salt2"=$Salt2}

    #First Try
    try
    {
            $job = Start-AzureRmAutomationRunbook -name "Get-PSCredential" -Parameters $Params -AutomationAccountName $AutomationAccount -ResourceGroupName $AutomationResourceGroup -ErrorAction Stop -ErrorVariable JobErr
    }
    Catch
    {
        if ($joberr)
        {
            if (($JobErr[0].Message.ToString()) -like "The Runbook was not found*")
            {
                Write-Verbose "Adding runbook Get-PsCredential to Azure Automation"
                Import-AzureRmAutomationRunbook -Name "Get-PSCredential" -Type PowerShell -Path "$thismodulepath\AzureAutomationRunbook\Get-PSCredential.ps1" -Published -AutomationAccountName $AutomationAccount -ResourceGroupName $AutomationResourceGroup | out-null
                Do {
                    Write-verbose "Waiting until the runbook is registered"
                    $runbookExists = $false
                    Try
                    {
                        $rbexists = Get-AzureRmAutomationRunbook -Name "Get-PSCredential" -AutomationAccountName $AutomationAccount -ResourceGroupName $AutomationResourceGroup -ErrorAction Stop
                    }
                    Catch {}
                    if ($rbexists) {$runbookExists = $true}
                    
                }
                Until ($runbookExists -eq $true)
                
            }
        }
        Else 
        {
            Write-error "Could not start runbook";exit
        }
    }

    

    
    #Second try
    $job = Start-AzureRmAutomationRunbook -name "Get-PSCredential" -Parameters $Params -AutomationAccountName $AutomationAccount -ResourceGroupName $AutomationResourceGroup

    do {
        Write-verbose "Waiting for credentials"
        Start-sleep -seconds 1
        $job = $job | Get-AzureAutomationJob
    }
    until ($job.Status -eq "completed")
    
    $out = Get-AzureRmAutomationJobOutput -Id $job.Id -Stream Output -AutomationAccountName $AutomationAccount -ResourceGroupName $AutomationResourceGroup
    $uri = "https://management.core.windows.net/$subscriptionid/cloudservices/OaaSCS/resources/automation/~/automationAccounts/$AutomationAccount/jobs/$($job.id)/streams/$($out.JobStreamId)?api-version=2014-12-08"
    $headers = @{
        "x-ms-version"="2013-06-01";
        "Content-Type"="application/json";
        "Authorization"=$token
        }
    Write-verbose "Getting the job output"
    $StreamDetails = Invoke-RestMethod -Uri $uri -Headers $headers
    $ReturnObj = $StreamDetails.properties.value.value | convertfrom-json | convertfrom-json
    $returnedUserName = $returnobj.UserName
    $returnedPassword = $returnobj.Password
    Write-verbose "Decrypting credentials"
    $returnedPasswordDecrypted = Decrypt-String -Encrypted $returnedpassword -salt $salt1 -Passphrase $salt2

    $returncredential = New-Object System.Management.Automation.PSCredential($returnedUserName,($returnedPasswordDecrypted | ConvertTo-SecureString -AsPlainText -Force))
    Write-verbose "Credentials decrypted. Returning"
    $returncredential
}

Function Get-AutomationVariable
{
    Param ($name)
    try
    {
        $return = Get-AzureRmAutomationVariable -Name $name -ResourceGroupName $AutomationResourceGroup -AutomationAccountName $AutomationAccount -ErrorAction stop
    }
    catch
    {
    }
    
    if ($return)
    {
        $return.Value
    }
    
}

