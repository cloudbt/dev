
```
Get-Partition | Where-Object DriveLetter -in 'D','E' | ForEach-Object {
    $disk = Get-Disk -Number $_.DiskNumber
    [PSCustomObject]@{
        DriveLetter = $_.DriveLetter
        DiskNumber  = $_.DiskNumber
        Serial      = $disk.SerialNumber
        FriendlyName= $disk.FriendlyName
    }
} | Format-List
```
