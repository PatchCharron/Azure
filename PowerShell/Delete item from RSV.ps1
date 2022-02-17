<#
When using Terraform, when I needed to do a redeployment using a different OS, Terraform needed to do a VM replacement, but the problem was with Soft Delete on the Recovery Services Vault TF couldn't perform the removal so the plan failed.

Here is some PS that will change the soft delete setting, delete the backup, then turn it back on.

Much better than waiting 14 days.

Run TF plan to delete the VM and backup, when the deployment fails, run this, then run the plan again.
#>

$vault = Get-AzRecoveryServicesVault -ResourceGroupName "BACKUPS" -Name "BACKUPS"

Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $vault.id | Where-Object {$_.DeleteState -eq "ToBeDeleted"} -ov item

Set-AzRecoveryServicesVaultProperty -VaultId $vault.id -SoftDeleteFeatureState Enable

Disable-AzRecoveryServicesBackupProtection -Item $item[0] -VaultId $vault.id -RemoveRecoveryPoints -Force