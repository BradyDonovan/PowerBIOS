# PowerBIOS
PowerBIOS is a PowerShell module that enables administration of the dynamic BIOS update system for use by OSD teams.


## What dynamic BIOS update system?
See [here](https://miketerrill.net/2017/09/10/configuration-manager-dynamic-drivers-bios-management-with-total-control-part-1/) and [here](https://miketerrill.net/2017/09/17/configuration-manager-dynamic-drivers-bios-management-with-total-control-part-2/).


## Installation instructions
```powershell
Import-Module C:\Path\To\Module\PowerBIOS.psm1
Set-PowerBIOSSettings -DatabaseServer "hostname.of.db.server.domain" -DBName "BIOS_Database" -NetworkLibrary dbmssocn -SiteServer "hostname.of.sccm.server.domain" -SCCMSiteCode CM1
```

## How do I use PowerBIOS? 
PowerBIOS has standard PowerShell cmdlets for creating, removing, updating, and deleting dynamic BIOS update packages. They are implemented via:
* `New-BIOSPackage`
* `Get-BIOSPackage`
* `Update-BIOSPackage`
* `Remove-BIOSPackage`



### New-BIOSPackage
#### Example Usage
```powershell
New-BIOSPackage -Make Dell -Model 7520 -TARGETBIOSDATE 20180101 -FLASHBIOSCMD FlashBios.cmd -BIOSContentPath \\path\to\folder\containing\files -Version 1.0.0
```
#### Parameters Explanation
| Parameter | Definition |
| -------- | -------- |
| Make | The Make of device (Dell, Lenovo, etc)|
| Model | The Model of the device (7520, X1 Carbon, etc)|
| TARGETBIOSDATE | Date of the BIOS update. The update will run if the installed version is behind this date. Format: yyyyddMM |
| FLASHBIOSCMD | Command to run for BIOS flashing. |
| BIOSCONTENTPATH | Path to folder containing BIOS update binaries. UNC paths only. |
| Version | Version of update (for the package in SCCM) |
#### Synopsis
Use the below command for further information.
```powershell
Get-Help New-BIOSPackage -Full
```

### Get-BIOSPackage
#### Example Usage
```powershell
Get-BIOSPackage -PackageID CM000000
```
#### Parameter Explanation
| Parameter | Definition |
| -------- | -------- |
| PackageID | PackageID to search SCCM for. |
#### Synopsis
Use the below command for further information.
```powershell
Get-Help New-BIOSPackage -Full
```

### Update-BIOSPackage
#### Example Usage
```powershell
Update-BIOSPackage -packageID CM000000 -newPackageID CM000001 -newFlashBiosCMD FlashBios.bat -newTargetBiosDate 20180102
```
#### Parameters Explanation
| Parameter | Definition |
| -------- | -------- |
| packageID | Target package to update. |
| newPackageID | Set a new package ID if applicable. |
| newFlashBiosCMD | Set a new FLASHBIOSCMD if applicable. |
| newTargetBiosDate | Set a new TARGETBIOSDATE if applicable. Format: yyyyddMM |
#### Synopsis
Use the below command for further information.
```powershell
Get-Help Update-BIOSPackage -Full
```

### Remove-BIOSPackage
#### Example Usage
```powershell
Remove-BIOSPackage -packageID CM000001
Remove-BIOSPackage -Make Dell -Model 7520
```
#### Parameters Explanation
| Parameter | Definition |
| -------- | -------- |
| PackageID | PackageID to remove. |
| Make | Make of BIOS package to remove (goes with Model). |
| Model | Model of BIOS package to remove (goes with Make). |
#### Synopsis
Use the below command for further information.
```powershell
Get-Help Remove-BIOSPackage -Full
```
