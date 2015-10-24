# AzureAutomationDebug
Emulated cmdlets for local debugging of Azure Automation Powershell runbooks

This module allows you to run Azure Automation scripts and runbooks locally. Calls to Get-AutomationPSCredential and get-AutomationVariable will return values from the specified Automation Account.

In order to make it a little harder to plain-text sniff output from Get-AutomationPSCredentials, the output values are encrypted in Azure, and decrypted locally.
Note at it is STILL possible to decrypt using the auto-generated salt1 and salt2 params sent to the automation job.

This module requires the AzureRm module for interacting with Azure thru ARM.




