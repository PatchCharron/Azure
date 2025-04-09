# Azure Dynamic DNS Updates

## Problem

I run a small home lab with a great internet connection, but I haven't wanted to double my connection cost to get "business class" so I can get static IPs. Which leaves my options to Dynamic DNS.
Learn more about Dynamic DNS [HERE](https://www.cloudflare.com/learning/dns/glossary/dynamic-dns/)

Google Fiber has only changed my IP a handful of times in 5 years, but it still is inconvenient to update the DNS records after I can't VPN into my house or connect to a lab.

## Solution

It is pretty easy to update a DNS record in Azure DNS using the PowerShell tools. I want it automated.

### Ideas

- Use a Windows Scheduled Task on my desktop to write my current IP to a blob. Use a Function App to read that blob and update Azure DNS.
  - Pros: Very easy to write and secure. Can use a SAS token for the file upload and Managed System-assigned Identity to update DNS.
  - Cons: Two services to manage. Reliant on my desktop to be running and not on the login screen after a Windows Update.
- Use a Windows Scheduled Task on my desktop to directly change the DNS records.
  - Pros: Easy to do.
  - Cons: Still reliant on my desktop to be running and logged in to work. Don't like leaving Entra Service Principal credentials on my daily machine.
- Just run it on a Windows Server VM
  - Where is the fun in that?
- Use a container to run the task
  - Pros: Pretty isolated on my network, container only needs to run for ~10 seconds a day, using a Service Principal permissions can be scoped to only certain DNS records, which protects the root and M365 records.
  - Pro #2: I get to learn more about building on containers
  - Cons: Need to securely store the Service Principal Credentials

## Setup

Run the Setup.ps1 on a machine that is connected to the desired Azure tenant and set the variables for the DNS zone you are targeting and the sub domains.
The script will create a CMS file which contains the Service Principal information and a private key file.
I put the files in a directory on my docker host that will be mapped to a directory in the container.

## Running the container

To run a base container, all you need to do is put the cms, key, and PowerShell file in a directory, start a container based on the Microsoft provided Azure PowerShell container and map the folder
`sudo docker run -it -v /home/**USER**/DDNS:/tmp/home mcr.microsoft.com/azure-powershell:alpine-3.17`

## Automation

I tried to use crontab to have the container run every day, but had very inconsistent runs. It would sometimes work daily, other times go a week.
I eventually configured Portainer to run the task every day.

## Double encrypting

I fully understand that leaving an encrypted file with the decryption key in the same directory is not ideal.
In my production implementation I double encrypt the CMS file. After the file is encrypted, it will make a second pass using another certificate.
The parent certificate is built into the container and when the container runs it uses the built in container to decrypt the CMS then the key stored in the directory is used to decrypt the CMS which is then decrypted again using the key in the directory.

This means to get the credentials the attacker would have to have the container image and the encrypted CMS with the second key. They would need to be on the container host with knowledge of the decryption path to gain access to the credentials.

To make and export a parent certificate use this code as a reference:
```
$ParentCertificate = "Contoso"
$c = New-SelfSignedCertificate -DnsName $ParentCertificate -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsage KeyEncipherment,DataEncipherment, KeyAgreement -Type DocumentEncryptionCert -KeyLength 4096

$password = ConvertTo-SecureString -String $passwordWolf -Force -AsPlainText
Export-PfxCertificate -Cert $c -FilePath ($outputDirectory + $ParentCertificate + ".pfx") -Password $password

Set-Location "C:\Program Files\OpenSSL-Win64\bin\"

.\openssl.exe rsa -in ($outputDirectory + $ParentCertificate + ".pfx") -passin ("pass:" + $passwordWolf) -out ($outputDirectory + $ParentCertificate + ".key")
.\openssl.exe rsa -in ($outputDirectory + $ParentCertificate + ".pfx") -passin ("pass:" + $passwordWolf) -pubout -out ($outputDirectory + $ParentCertificate + ".pub")
```

Is anything truly secure, no. But this has enough levels that I feel safe releasing this method as sufficient.
