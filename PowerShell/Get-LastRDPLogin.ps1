<#
Though not foolproof because logs don't hold around that long.. This is a decent way to find the last person to RDP in
#>

$a = Get-WinEvent -ProviderName 'Microsoft-Windows-Security-Auditing' -FilterXPath "*[System[EventID=4624] and EventData[Data[@Name='LogonType']='10']]" -MaxEvents 1 -ErrorAction SilentlyContinue
if($a.count -eq 1)
{
    [XML]$b = $a.ToXML()

    [PSCustomObject]@{
        User = $b.Event.EventData.Data[5].'#Text'
        Time = $a.TimeCreated
    }
} else {
    Write-Warning ( "No RDP login found, oldest event in log is: " + (Get-WinEvent -ProviderName 'Microsoft-Windows-Security-Auditing' -Oldest -MaxEvents 1).TimeCreated)
}
