<#
Customer wanted to know how large their backups were, they felt they were paying too much for backups and wanted to track the daily rate of change to see if a specific VM (or set of VMs) were causing the problem.

Final product dumped to a CSV each day then I did some Measure-Object's. Such a specific use case so I'm not releasing that code.



#>

$key = ""
$app = ""
$tenant = ""

$tokenEndpoint = {https://login.microsoftonline.com/{0}/oauth2/token} -f $tenant

$arm = "https://management.core.windows.net/"

$Body = @{
    'resource'=$arm
    'client_id' = $app
    'grant_type' = 'client_credentials'
    'client_secret' = $key
}

$params1 = @{
    ContentType = 'application/x-www-form-urlencoded'
    Headers = @{'accept'='application/json'}
    Body = $Body
    Method = 'Post'
    URI = $tokenEndpoint
}

$token = Invoke-RestMethod @params1

$Headers = @{}

$Headers.Add("Authorization","$($Token.token_type) "+ " " + "$($Token.access_token)")


$url = "https://management.azure.com/subscriptions?api-version=2019-05-01"
$subscriptions = Invoke-RestMethod -Uri $url -Headers $headers

[array]$SubData = @()

foreach($subscription in $subscriptions.value)
{
    $urlPrefix = ("https://management.azure.com/subscriptions/" + $Subscription.SubscriptionId)

    $url = ($urlPrefix + "/providers/Microsoft.RecoveryServices/vaults?api-version=2016-06-01")
    $RSVs = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

    foreach($RSV in $RSVs.value)
    {
        $Sub = New-Object -TypeName PSObject

        $Sub | Add-Member -MemberType NoteProperty -Name "Subscription" -Value $subscription.displayName
        $Sub | Add-Member -MemberType NoteProperty -Name "RSV" -Value $RSV.name

        $url = ("https://management.azure.com" + $RSV.ID + "/usages?api-version=2016-06-01")
        $a = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
        
        $LRSBackup = (($a.value | Where {$_.name.value -eq "LRSStorageUsage"})[0]).CurrentValue /1GB
        $GRSBackup = (($a.value | Where {$_.name.value -eq "GRSStorageUsage"})[0]).CurrentValue /1GB
        $VMs = (($a.value | Where {$_.name.value -eq "ProtectedItemCount"})[0]).CurrentValue

        $Sub | Add-Member -MemberType NoteProperty -Name "GRS" -Value $GRSBackup
        $Sub | Add-Member -MemberType NoteProperty -Name "LRS" -Value $LRSBackup
        $Sub | Add-Member -MemberType NoteProperty -Name "VMs" -Value $VMs

        $SubData += $Sub
    }

}

$SubData

