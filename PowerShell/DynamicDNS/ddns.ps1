


# Need the openssl package to unpack the cms file, if it was installed in a docker file then move on
if($null -eq (Invoke-Expression "apk info | grep 'openssl'"))
{
    apk add openssl
}

$files = Get-ChildItem "/tmp/home"

# Check if the file is going to be double encrypted
if(Test-Path -Path "/usr/local" -Filter "*.key")
{
    $Encrypted = Invoke-Expression ("openssl cms -decrypt -in " + (($files | Where-Object name -like "*.cms").FullName) + " -inkey " + (Get-ChildItem "/usr/local" | Where-Object name -like "*.key").FullName + " -inform PEM")

    Set-Content -Value $Encrypted -Path "/usr/local/creds_encrypted.cms"

    $credentials = Invoke-Expression ("openssl cms -decrypt -in /usr/local/creds_encrypted.cms -inkey " + (($files | Where-Object name -like "*.key").FullName) + " -inform PEM") | ConvertFrom-Json

    # For safety reasons, delete the key and decrypted file. So even if someone gets in the container they can't get the creds from here.
    # Yes, I know the creds are stored in the keystore, but it makes me feel better
    Remove-Item -Path "/usr/local/creds_encrypted.cms"
    Remove-Item -Path (Get-ChildItem "/usr/local" | Where-Object name -like "*.key").FullName

} else {
    $credentials = Invoke-Expression ("openssl cms -decrypt -in " + (($files | Where-Object name -like "*.cms").FullName) + " -inkey " + (($files | Where-Object name -like "*.key").FullName) + " -inform PEM") | ConvertFrom-Json

}

if($null -ne $credentials)
{

    $SecureStringPassword = $credentials.secret | ConvertTo-SecureString -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $credentials.appId, $SecureStringPassword
    Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $credentials.tenant -Environment $credentials.environment


    # I use role assignments for a 
    $Records = (Get-AzRoleAssignment)

    # In case someone assigns this Service Principal to something else
    $Records = $Records | Where-Object Scope -Like "*Microsoft.Network/dnszones*"

    #Get the current IP. 
    $CurrentIP = (Invoke-RestMethod "https://api.ipify.org?format=json").ip

    if($null -eq $Records)
    {
        Add-Content -Path "/tmp/home/log.log" -Value ((Get-Date).ToString('yyyy-MM-dd_hh:mm:ss') + " WARNING: No dns role assignments found")
    }

    foreach($Record in $Records.Scope)
    {
        $currentRecord = (Get-AzDnsRecordSet -Name $Record.Split('/')[-1] -ZoneName $Record.Split('/')[8] -ResourceGroupName $Record.Split('/')[4] -RecordType A)

        #Make sure the record exists
        if($currentRecord)
        {
            if($currentRecord.Records[0].ipv4Address -ne $CurrentIP)
            {
                #Log the change
                Add-Content -Path "/tmp/home/log.log" -Value ((Get-Date).ToString('yyyy-MM-dd_HH:mm:ss') + " Changed; Record: " + $currentRecord.Name + "; OldIP: " + $currentRecord.Records[0].ipv4Address + "; NewIP: " + $CurrentIP)
                
                #Set the current object to the new IP and set it
                $currentRecord.Records[0].ipv4Address = $CurrentIP
                Set-AzDnsRecordSet -RecordSet $currentRecord

            } else {
            Add-Content -Path "/tmp/home/log.log" -Value ((Get-Date).ToString('yyyy-MM-dd_HH:mm:ss') + " No Change")
            }
        } else {
            ((Get-Date).ToString('yyyy-MM-dd_hh:mm:ss') + " WARNING: No records found")
        }
    }
} else {
    Add-Content -Path "/tmp/home/log.log" -Value ((Get-Date).ToString('yyyy-MM-dd_hh:mm:ss') + " ERROR: Couldn't decrypt credential file.")
}

