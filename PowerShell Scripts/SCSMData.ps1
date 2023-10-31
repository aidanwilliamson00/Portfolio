#This script gets hardware asset information from SCSM and formats it into usable data
#By: Aidan Williamson - IT Intern

#For each device we get: 
# Names:
#   DisplayName, AssetTag, Name
# Hardware Info:
#   HardwareType, SerialNumber, CatalogItem, Manufacturer, Model
# Device Info:
#   AssetStatus, PrimaryUser, Location, LocationDetails, CostCenter

###################################################################################

#User Defined Vars

#Object Filter
$Filter      = "AssetTag -like 'TPHONE-*"

#Export Path
$Path        = "C:\Users\$env:username\Documents\SCSMDevices.csv"

#Show Timer (Suggested for larger sets as it can take up to 40 minutes)
$ShowTimer   = $True

#Computer Name
$CompName    = 'scsmdev'

###################################################################################

Write-Host "Retrieving Data..."

#Create Device Class
$DeviceClass = Get-SCSMClass -Name Cireson.AssetManagement.HardwareAsset -ComputerName $CompName

#Create Object From Device Class
$Devices     = Get-SCSMObject -Class $DeviceClass  -ComputerName $CompName -Filter $Filter

#Get Enum List
$Enums       = Get-SCSMEnumeration -ComputerName $CompName

#Get Relationship Class Ids
$PrimaryUserRelationId = (Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasPrimaryUser -ComputerName $CompName).id
$LocationRelationId    = (Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasLocation    -ComputerName $CompName).id
$CatalogItemId         = (Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasCatalogItem -ComputerName $CompName).id
$CostCenterId          = (Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasCostCenter  -ComputerName $CompName).id

#Create List to hold device info
$SCSMDevices = [System.Collections.Generic.List[Object]]::new()

#Timer Start
if($ShowTimer){
    $NumDevices = $Devices.count
    $StartTime  = $(get-date)
    $FStartTime = "{0:HH:mm:ss}" -f ([datetime]$StartTime.Ticks)
    $Counter = 1
    Clear-Host
}

#Loop Device List to get the info that we need
foreach($Device in $Devices){
    
    #Create/Reset Device Vars
    $DeviceType,$DeviceStatus,$PrimaryUser,$Location,$CatalogItem,$CostCenter = $null

    #Find Device Type, Status, Model, and Manufacturer from Enum List
    $Enums | ForEach-Object{
        if($_.Name -eq $Device.HardwareAssetType)  {$DeviceType         = $_.DisplayName}
        if($_.Name -eq $Device.HardwareAssetStatus){$DeviceStatus       = $_.DisplayName}
        if($_.Name -eq $Device.ManufacturerEnum)   {$Manufacturer       = $_.DisplayName}
        if($_.Name -eq $Device.ModelEnum)          {$Model              = $_.DisplayName}
    }

    #Get List of Relationship Objects for this device
    $Relationships = Get-SCSMRelationshipObject -BySource $Device -computername $CompName

    #Select PrimaryUser, Location, CatalogItem, and CostCenter by RelationshipClass id
    $Relationships | ForEach-Object{
        if($_.IsDeleted -eq $false){
            if($_.RelationshipId -eq $PrimaryUserRelationId){$PrimaryUser = $_.TargetObject}
            if($_.RelationshipId -eq $LocationRelationId)   {$Location    = $_.TargetObject}
            if($_.RelationshipId -eq $CatalogItemId)        {$CatalogItem = $_.TargetObject}
            if($_.RelationshipId -eq $CostCenterId)         {$CostCenter  = $_.TargetObject}
        }
    }

    #Format Data
    $ReportLine = [PSCustomObject]@{
        DisplayName        = $Device.DisplayName
        AssetTag           = $Device.AssetTag
        Name               = $Device.Name
        HardwareType       = $DeviceType
        AssetStatus        = $DeviceStatus
        SerialNumber       = $Device.SerialNumber
        PrimaryUser        = $PrimaryUser
        Location           = $Location
        LocationDetails    = $Device.LocationDetails
        CatalogItem        = $CatalogItem
        Manufacturer       = $Manufacturer
        Model              = $Model
        CostCenter         = $CostCenter
    }
    #Add data to report
    $SCSMDevices.Add($ReportLine)

    #Progress Timer
    if($ShowTimer){
        $elapsedTime   = $(get-date) - $StartTime
        $currentTime   = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
        $avgTime       = [math]::Truncate($elapsedTime.TotalMilliseconds / $Counter)
        $perc          = [int](($Counter/$NumDevices)*100)
        Write-Progress "$Counter/$NumDevices  -  Timer: $currentTime, Avg(ms): $avgTime" -PercentComplete $perc
        $Counter++
    }
}

#Timer End
if($ShowTimer){
    $elapsedTime = $(get-date) - $StartTime
    $totalTime   = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
    $avgTime     = [math]::Truncate($elapsedTime.TotalMilliseconds / $Devices.count)
    Write-Host "Total time elapsed: $totalTime, Average time per device: $avgTime ms"
}

#Export or Return
$SCSMDevices | Export-Csv -Path $Path
#return $SCSMDevices
