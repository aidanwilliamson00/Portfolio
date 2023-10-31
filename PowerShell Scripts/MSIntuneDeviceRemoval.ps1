#Set permissions & Prepare variables

$Scopes = "DeviceManagementManagedDevices.ReadWrite.All"

Connect-Graph $Scopes

$DevicesWithID = [System.Collections.Generic.List[Object]]::new()

#Download devices from intune

$AllDevices = Get-MgDevice -All -Select "DisplayName, DeviceId"

#Import devices to be removed from csv

$RemoveDevices | Import-Csv -Path "C:\Users\$env:username\Documents\DevicesToBeRemoved.csv"

#Match device id to laptop num
#   for-each with a where object

foreach($Laptop in $AllDevices){
    if($RemoveDevices.DeviceName -eq $Laptop.DisplayName){
        $ReportLine = [PSCustomObject]@{
            DeviceName = $Laptop.DisplayName
            DeviceId   = $Laptop.DeviceId
        }
    $DevicesWithID.Add($ReportLine)
    }
}
$DevicesWithID | Export-Csv -Path "C:\Users\$env:username\Documents\DeviceIdsToBeRemoved"

#Delete devices from intune

#foreach($Device in $DevicesWithID){
    #Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $Device.DeviceId
#}

