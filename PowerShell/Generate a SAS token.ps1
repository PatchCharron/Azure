<#
I use this to pass a SAS token into a VM via the DSC extension which downloads software from a Storage Account.
This can also be run from inside the VM if you've configured a User / Managed Identity that has blob reader / contributor
#>

# If you use the full resource ID, you don't need to change subscription context if you are deploying to a different subscription than where the storage account is
$saID = "/subscriptions/99999999-9999-9999-9999-999999999999/resourceGroups/RG1/providers/Microsoft.Storage/storageAccounts/contosostorage1"
[string]$SAS = ("?" + (Invoke-AzResourceAction -Parameters @{keyToSign = "key1";signedExpiry = (Get-Date -Date ((Get-Date).AddHours(6)) -UFormat '+%Y-%m-%dT%H:%M:%S.000Z').ToString();signedPermission = "r";signedResourceTypes = "o";signedServices = "b";signedProtocol = "https"} -ResourceId $saId -Action "listaccountsas" -ApiVersion "2019-06-01" -Force).accountSASToken)

$SAS