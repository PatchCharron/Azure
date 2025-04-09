$ParentCertificate = "MyParentCERT"
$AppName = "DDNS-Nashville"
$ZoneName = "contoso.com"
$ResourceGroup = "DNS"
[array]$SubDomains = @("vpn")
$outputDirectory = "C:\temp\"

$app = New-AzADServicePrincipal -DisplayName $appName -Description "Dynamic DNS" -EndDate (Get-Date).AddDays(730)

$c = New-SelfSignedCertificate -DnsName $AppName -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsage KeyEncipherment,DataEncipherment, KeyAgreement -Type DocumentEncryptionCert

$c = Get-ChildItem -Path ("Cert:\CurrentUser\My\" + $c.Thumbprint)

$passwordWolf = (Invoke-RestMethod -uri "https://passwordwolf.com/api/?length=18&upper=on&lower=on&special=off&repeat=5").password[(get-random -Minimum 0 -Maximum 4)]

$password = ConvertTo-SecureString -String $passwordWolf -Force -AsPlainText
Export-PfxCertificate -Cert $c -FilePath ($outputDirectory + $AppName + ".pfx") -Password $password

if(test-path "C:\Program Files\OpenSSL*")
{
    Set-Location "C:\Program Files\OpenSSL-Win64\bin\"

    .\openssl.exe rsa -in ($outputDirectory + $AppName + ".pfx") -passin ("pass:" + $passwordWolf) -out ($outputDirectory + $AppName + ".key")

    # We can remove the PFX since we don't need it anymore
    Remove-Item -Path ($outputDirectory + $AppName + ".pfx")

    # Create the object with everything we need. Include the environment so we can support Azure Gov. Write out the CMS file.
    [PSCustomObject]@{
        appId = $app.AppId
        objectId = $app.Id
        secret = $app.PasswordCredentials.SecretText
        tenant = (Get-AzContext).Tenant.Id
        environment = (get-AzContext).environment.name
    } | ConvertTo-Json | Protect-CmsMessage -To ("*" + $AppName) -OutFile ($outputDirectory + $AppName + ".cms")

    if($null -ne $ParentCertificate)
    {
        $p = (get-ChildItem ("Cert:\CurrentUser\My") | where subject -like ("*" + $ParentCertificate))
        if($p)
        {
           Get-Content -Path ($outputDirectory + $AppName + ".cms") | Protect-CmsMessage -To ("*" + $ParentCertificate) -OutFile ($outputDirectory + $AppName + "_" + $ParentCertificate + ".cms")
    
           Export-PfxCertificate -Cert $p -FilePath ($outputDirectory + $ParentCertificate + ".pfx") -Password $password
        } else {
            Write-Warning "Can't find certificate"
        }
    }
} else {
    Write-Error "You need OpenSSL installed"
}

# Ensure we see the DNS Zone.
if(Get-AzDnsZone -Name $ZoneName -ResourceGroupName $ResourceGroup)
{
    # Create the sub domains with a generic IP.
    foreach($SubDomain in $SubDomains)
    {
        $DefaultRecord = New-AzDnsRecordConfig -Ipv4Address "1.2.3.4"
        $CreatedRecord = New-AzDnsRecordSet -Name $SubDomain -ZoneName $ZoneName -ResourceGroupName $ResourceGroup -Ttl 3600 -RecordType A -DnsRecords $DefaultRecord

        New-AzRoleAssignment -Scope $CreatedRecord.Id -ApplicationId $app.appId -RoleDefinitionName "Contributor"
    }
} else {
    Write-Error "Can't find the DNS Zone, is the right subscription selected?"
}
