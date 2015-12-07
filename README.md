# AzureAutomationDebug
Emulated cmdlets for quick and easy local debugging of Azure Automation Powershell runbooks.

This module allows you to run Azure Automation scripts and runbooks locally. Calls to Get-AutomationPSCredential and get-AutomationVariable will return values from the specified Automation Account. This module does not use a local cache or "vault" for credentials, it retrieves the actual values directly from Azure automation. Less configuration, less fuss.

In order to make it a little harder to plain-text-read output from Get-AutomationPSCredentials (by simply looking at the job output), the output values are encrypted in Azure, and decrypted locally (this happens behind the scenes).
Note that it is STILL possible to decrypt passwords using the auto-generated salt1 and salt2 params sent to the automation job (the salting mechanism just makes it a bit harder, since passwords won't be displayed in clear-text).

This module requires the AzureRm module for interacting with Azure thru ARM.

This module requires the existence of the "Get-PSCredential" runbook (of type powershell) in Azure automation. It will be auto-added to the target account if it doesn't already exist. If using a service principal without permission to upload/publish runbooks, the runbook needs to be uploaded/published manually into Azure Automation prior to running the functions in this module. The Get-PSCredential.ps1 can be found in the directory "AzureAutomationRunbook" in this module.

To configure the automation account, use `AzureAutomationDebugConfig.json` (example provided). The module looks for `AzureAutomationDebugConfig.json` in the current directory, and falls back to the module directory if not found.
This means that if you work on different projects requiring different credentials, you can use different `AzureAutomationDebugConfig.json` files, for example by storing them in the various project directories.
Note that the module looks for `AzureAutomationDebugConfig.json` during module loading (it basically logs in to Azure during module load), so if you want to switch config files you need to run `Import-Module AzureAutomation -Force` in order to get the module to log in to Azure with the updated credentials.

Configure credentials either by using the `AACredentialsXmlPath` setting pointing to a xml file with saved credentials (using `Get-credential | export-clixml mycreds.xml`) or by providing username and password directly in the json (using  `AAUsername` and `AAPassword` ) which is less secure.




