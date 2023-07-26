$me = Get-AzAccessToken

$apiPrefix = "management.usgovcloudapi.net"



$Headers = @{"Authorization" = "$($me.Type) "+ " " + "$($me.Token)"} 


$subscriptions = (Invoke-RestMethod -Uri ("https://" + $apiPrefix +"/subscriptions?api-version=2019-05-01") -Headers $headers).value
$body = @{
    "subscriptions" = $subscriptions.subscriptionId
    "query" = "resources | where type == 'microsoft.storage/storageaccounts'| where properties.networkAcls.virtualNetworkRules != '[]'"
}

$accounts = (Invoke-RestMethod -Uri ("https://" + $apiPrefix + "/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01") -Body ($body | ConvertTo-Json) -Headers $Headers -Method POST -ContentType "application/json").data

$count = 0

foreach($sa in $accounts)
{
    [System.Collections.ArrayList]$rules = $sa.properties.networkAcls.virtualNetworkRules
    $toRemove = @()

    foreach($subnet in $rules)
    {
        
        try {
            Invoke-RestMethod -Method GET -Headers $headers -Uri ("https://" + $apiPrefix + $subnet.id + "?api-version=2022-11-01") | Out-Null
        } catch {
           Write-Output ("Storage Account: " + $sa.name + "; VNET: " + $subnet.id.split('/')[8] + "; subnet: " + $subnet.id.split('/')[-1])
            $count ++
            $toRemove += $subnet.id
        }
    }

    if($toRemove.count -gt 0)
    {
        foreach($a in $toRemove)
        {
            $rules.RemoveAt($rules.id.IndexOf($a))
        }
        $sa.properties.networkAcls.virtualNetworkRules = $rules
        
        Invoke-RestMethod -ContentType "application/json" -Headers $headers -Method Patch -Uri ("Https://management.usgovcloudapi.net" + $sa.id + "?api-version=2022-09-01") -Body (@{"properties" = @{"networkAcls" = ($sa.properties.networkAcls)}} | ConvertTo-Json -Depth 4)

    } else {
        Write-Output "Good to go"
    }
    
}

