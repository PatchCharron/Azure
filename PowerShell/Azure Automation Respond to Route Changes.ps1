<#
Have a customer where all network data is forced routed to a central Palo Alto. Its a large environment and the CISO office wanted to ensure someone didn't either delete the 0.0.0.0/0 or added a route with the destination of Internet, either out of malace or a mistake.

This takes the alert data sent over from Azure Monitor, compares to the previous state to identify what's changed then kicks off an email if it identifies a difference.

The companion to this is an Azure Alert looking for any updates to route tables, if it finds one it fires off a WebHook to a runbook which has the code below.

Because I have the alert firing based on an Activity Log, it will sometimes fire on the the "submitted" and the "succeeded", so you may see two runs. Someday I will dig into that.

You can use this for any Azure resource type to identify drift, I have also used it to track Azure SQL Server firewall changes and someday NSGs

TODO: Release ARM template for alert

#>

[OutputType("PSAzureOperationResponse")]
param
(
    [Parameter (Mandatory=$false)]
    [object] $WebhookData
)


$sendMail = $false
if ($WebhookData)
{
    try
    {
        $servicePrincipalConnection=Get-AutomationConnection -Name "AzureRunAsConnection"       

        "Logging in to Azure..."
        Add-AzAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint -Environment AzureUSGovernment
    }
    catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }

    $Data = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)
    if ($data.schemaId -eq "azureMonitorCommonAlertSchema") {
        $Essentials = [object] ($Data.data).essentials
        # Get the first target only as this script doesn't handle multiple
        $alertTargetIdArray = (($Essentials.alertTargetIds)[0]).Split("/")

            Select-AzSubscription ($alertTargetIdArray)[2]

            [array]$CurrentList = (Get-AzRouteTable -Name ($alertTargetIdArray)[-1] -ResourceGroupName ($alertTargetIdArray)[4])

                Write-Debug "Got Current"
                $c = @()
                foreach($current in $currentList.Routes)
                {
                    $c += [pscustomobject]@{
                        Name = $current.Name
                        NextHop = $current.NextHopIpAddress
                        Prefix = $current.AddressPrefix
                        Type = $current.NextHopType
                    }
                }
                Write-Debug "Finished parsing"


            $ctx = New-AzStorageContext -StorageAccountName "storage1" -StorageAccountKey (Get-AutomationVariable -Name 'StorageAccountKey')  -Environment AzureUSGovernment
            Write-Debug "Got the context"
            $Table = (Get-AzStorageTable –Name "states" –Context $ctx).CloudTable
            Write-Debug "Got table"
            $row = Get-AzTableRow -RowKey ($alertTargetIdArray)[-1] -Table $table -PartitionKey "RouteTable" -errorAction Continue 
            if($row)
            {
                Write-Debug "Got Row"
                [array]$prefixes = $row.Routes | ConvertFrom-Json
                $compared = Compare-Object -ReferenceObject $prefixes -DifferenceObject $c -Property prefix, NextHop
                Write-Debug "Finished comparing"
                $changes = @()
                foreach($compare in $compared)
                {  
                    $changes += [pscustomobject]@{
                        Name = ($c | where Prefix -eq $compare.prefix).name
                        NextHop =($c | where Prefix -eq $compare.prefix).NextHop
                        Prefix = ($c | where Prefix -eq $compare.prefix).Prefix
                        Type = ($c | where Prefix -eq $compare.prefix).Type
                        Action = if($compare.SideIndicator -eq "=>"){"Added/Modified"}elseif($compare.SideIndicator -eq "<="){"Removed"}
                    }
                }
                if($changes.Count -gt 0)
                {
                    Write-Debug "Finished compare hashtable"
                    $row.Routes = $c | ConvertTo-Json
                    $row | Update-AzTableRow -Table $table
                    Write-Debug "finished updating"

                   $sendMail = $true

                } else {
                    Write-Warning "No Changes, was duplicate fire of alert, this happens a lot"
                }
            } else {
                Write-Warning "Couldn't find server in table, adding"

                $o = [hashtable]@{
                    Routes = $c | ConvertTo-Json
                }
                Add-AzTableRow -Table $table -PartitionKey "RouteTable" -RowKey ($alertTargetIdArray)[-1] -property $o

                $sendMail = $true
                $changes = $c
            }
    }
    else {
        # Schema not supported
        Write-Error "The alert data schema - $schemaId - is not supported."
    }
}


if($sendMail)
{
    
    $body = "<HTML><BODY>"
    $body += ("<H1>"+ ($alertTargetIdArray)[-1] + " Route Changed</H1>")
    $body += $changes | Select Name, NextHop, Type, Prefix | ConvertTo-Html -Fragment
    $body += ("Modified By : " + $user)
    $body += "</BODY></HTML>"

    Write-Debug "Finished making an HTML body"

    $From = "Azure_Alerts@sendgrid.net"
    $To = "admins@contoso.com"
    $Subject = "Route Changed"

    $secret = (Get-AutomationVariable -Name 'SendGrid') | ConvertTo-SecureString -AsPlainText -Force
    $c = [pscredential]::new("apikey", $secret)

    Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -BodyAsHtml -SmtpServer "smtp.sendgrid.net" -Port 587  -Credential $c
    Write-Debug "Email Sent"
}
