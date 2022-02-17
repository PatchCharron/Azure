<#
First off, yes I know the Publish-AzVMDscConfiguration lets you directly upload to a Storage Account, but for this customer has dozens of subscriptions so having to change contexts was annoying.

Also this is a great way to upload a file to a Storage Account container using a SAS token
#>
# If you use the full resource ID, you don't need to change subscription context if you are deploying to a different subscription than where the storage account is
$saID = "/subscriptions/99999999-9999-9999-9999-999999999999/resourceGroups/RG1/providers/Microsoft.Storage/storageAccounts/contosostorage1"
[string]${SAS} = ("?" + (Invoke-AzResourceAction -Parameters @{keyToSign = "key1";signedExpiry = (Get-Date -Date ((Get-Date).AddHours(6)) -UFormat '+%Y-%m-%dT%H:%M:%S.000Z').ToString();signedPermission = "rw";signedResourceTypes = "o";signedServices = "b";signedProtocol = "https"} -ResourceId $saID -Action "listaccountsas" -ApiVersion "2019-06-01" -Force).accountSASToken)
#Add -Force to override existing file
Publish-AzVMDscConfiguration -ConfigurationPath .\config.ps1 -OutputArchivePath .\config.zip -Force

$ctx = New-AzStorageContext -SasToken $SAS -Environment AzureUSGovernment -StorageAccountName l3sharedassets
#Use -Force to override existing file
Set-AzStorageBlobContent -File .\PowerShell\deploy.zip -Blob deploy.zip -Container dsc -Context $ctx -Force

