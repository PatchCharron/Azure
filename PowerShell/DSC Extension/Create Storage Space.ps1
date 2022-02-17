Script ConfigureStorageSpace
{
    TestScript =  {
        (get-virtualdisk -ErrorAction SilentlyContinue -friendlyName VirtualDisk1).operationalSatus -EQ 'OK'
    }
    GetScript = {
        @{
            Disk = if((get-volume -filesystemlabel VirtualDisk1).filesystem -EQ 'NTFS') {'Present'} Else {'Absent'}
            Volume = if((Get-VirtualDisk -FriendlyName VirtualDisk1).OperationalStatus -eq 'OK') {'Present'} Else {'Absent'}
            StorageSpace = if ((Get-StoragePool -FriendlyName StoragePool1).OperationalStatus -eq 'OK') {'Present'} Else {'Absent'}
        }
    }
    SetScript = {
        New-StoragePool -FriendlyName StoragePool1 -StorageSubSystemFriendlyName '*storage*' -PhysicalDisks (Get-PhysicalDisk -CanPool $True)
        $disks = Get-StoragePool –FriendlyName StoragePool1 -IsPrimordial $False | Get-PhysicalDisk
        New-VirtualDisk –StoragePoolFriendlyName StoragePool1 –FriendlyName VirtualDisk1 –ResiliencySettingName simple -NumberOfColumns $disks.Count –UseMaximumSize 
        Get-VirtualDisk –FriendlyName VirtualDisk1 | Get-Disk | Initialize-Disk –Passthru | New-Partition –AssignDriveLetter –UseMaximumSize | Format-Volume -NewFileSystemLabel Data –AllocationUnitSize 64KB -FileSystem NTFS
    }
}