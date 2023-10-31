#This Script gets physical phone data from genesys and compares it to the phone data in SCSM
#   If the phone exists in SCSM but has incorrect data, the data will be updated
#   If the phone does not exist in SCSM, a new asset will be created
#   If the phone exists in SCSM but not in the Genesys data, the phone will be retired
#       All retired phones are exported to a csv
#By: Aidan Williamson - IT Intern

########################################## User Defined Vars #################################################

#SCSM Object Filter
$SCSMFilter  = "AssetTag -like 'TPHONE-*"

#Export Path
$Path        = "C:\Users\$env:username\Documents"

#ComputerName
$CompName    = "scsmdev"



########################################## GenesysPull.ps1 ##################################################


    #Delete the less than sign below this to uncomment section
#           Pull Genesys Data 

#Create function to connect to Genesys Cloud
function Connect-GC {
    $authServiceURL = "api auth"
    $client_id = "not going to tell you"
    $client_secret = "not telling you this either"

    $clientString = "$($client_id):$($client_secret)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($clientString))


    $headers = @{
        "Content-Type" = "application/x-www-form-urlencoded"
        Authorization = "Basic $encodedCreds"
    }

    $body = @{
        grant_type = "client_credentials"
    }

    $foo = Invoke-WebRequest $authServiceURL -Method Post -Headers $headers -Body $body -UseBasicParsing
    $fooJson = $foo.Content | ConvertFrom-Json
    $access_token = $fooJson.access_token

    $headers = @{
        "Content-Type" = "application/json"
        Authorization = "Bearer $access_token"
    }
    return $headers
}

#Create A function to pull Genesys Cloud data on loop to pull all pages
function Get-GCData {
    param(
        [Parameter(Mandatory)]
            [hashtable] $GCHeader,
        [Parameter(Mandatory)]
            [string] $api,
        [Parameter()]
            [string[]] $parms = @(),
        [Parameter()]
            [boolean] $entities = $false
        )

    $apiURL = "api url"
    if ($parms.count) {
        $uriParms = "?" + ($parms -join "&")
    } else {
        $uriParms = ""
    }
    $queryUrl = $apiUrl + $api + $uriParms
    $queryResponse = Invoke-WebRequest $queryURL -Method Get -Headers $GCheader -UseBasicParsing
    $queryContent = $queryResponse.Content | ConvertFrom-Json

    if ($entities) {
        Write-Host "First Page"
        $entityList = @()
        $pageCount = $queryContent.pageCount
        $queryContent.entities | ForEach-Object {
            $entityList += $_
        }
        for ($page = 2; $page -le $pageCount; $page++) {
            Write-Host "Page $page of $pageCount"
            $pageParm = "pageNumber=$page"
            if ($parms.count) {
                $uriParms = "?" + ($parms -join "&") + "&$pageParm"
            } else { 
                $uriParms = "?$pageParm"
            }
            $queryUrl = $apiUrl + $api + $uriParms
            $queryResponse = Invoke-WebRequest $queryURL -Method Get -Headers $GCheader -UseBasicParsing
            $queryContent = $queryResponse.Content | ConvertFrom-Json
            $queryContent.entities | ForEach-Object {
                $entityList += $_
            }
        }
        return $entityList
    } else {
        return $queryContent
    }
}

#Connect to Gensys Cloud API
$GcHeader = Connect-GC 

#Specify what we are looking to pull from the API
$Phones = Get-GCData -api "api path" -GCHeader $GcHeader -entities $True

#Get hardware types
$PhoneBaseSettings = Get-GCData -api "api path" -GCHeader $GcHeader -entities $True

#Get site info
$Sites = Get-GCData -api "api path" -GCHeader $GcHeader -entities $True

#Create Phone Export Variable for reference
$GenesysDevices = [System.Collections.Generic.List[Object]]::new() 

#Loop through Gensys phones to find physical phones only by hardware ID (MAC address) and add it to the phone report variable
ForEach ($Phone in $Phones){
    if ($null -ne $Phone.properties.phone_hardwareId) {

        #Create/Reset Name Vars
        $TypeName, $SiteName = $null

        #Find Hardware Type and Site name in repective lists
        ForEach($Type in $PhoneBaseSettings){
            if($Type.id -eq $Phone.phoneBaseSettings.id){
                $TypeName = $Type.name
                break
            }
        }
        ForEach($Site in $Sites){
            if($Site.id -eq $Phone.site.id){
                $SiteName = $Site.name
                break
            }
        }

        #Create Report
        $PhoneReportLine  = [PSCustomObject] @{ 
            PhoneName     = $Phone.name
            State         = $Phone.State
            SerialNumber  = $Phone.properties.phone_hardwareId.value.instance
            HardwareType  = $TypeName
            Location      = $SiteName
        }
        $GenesysDevices.Add($PhoneReportLine)
    }
}
#Export Data
#$PhoneReport | Export-Csv -Path "$Path\GenesysDevices.csv"
#>


########################################### SCSMPull.ps1 #################################################################


    #Delete the less than sign below this to uncomment section
#      Pull SCSM Data

Write-Host "Retrieving SCSM Data..."

#Create Device Class
$DeviceClass = Get-SCSMClass -Name Cireson.AssetManagement.HardwareAsset -ComputerName $CompName

#Create Object From Device Class
$Devices     = Get-SCSMObject -Class $DeviceClass  -ComputerName $CompName -Filter $SCSMFilter

#Get Enum List
$Enums       = Get-SCSMEnumeration -ComputerName $CompName

#Get Relationship Class Ids
$PrimaryUserRelationId = (Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasPrimaryUser -ComputerName $CompName).id
$LocationRelationId    = (Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasLocation    -ComputerName $CompName).id
$CatalogItemRelationId = (Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasCatalogItem -ComputerName $CompName).id
$CostCenterRelationId  = (Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasCostCenter  -ComputerName $CompName).id

#Create List to hold device info
$SCSMDevices = [System.Collections.Generic.List[Object]]::new()

#Loop Device List to get the info that we need
foreach($Device in $Devices){
    
    #Create/Reset Device Vars
    $DeviceType,$DeviceStatus,$PrimaryUser,$Location,$CatalogItem,$CostCenter = $null

    #Find Device Type, Status, Model, and Manufacturer from Enum List
    $Enums | ForEach-Object{
        if($_.Name -eq $Device.HardwareAssetType){
            $DeviceType = $_.DisplayName
        }
        if($_.Name -eq $Device.HardwareAssetStatus){
            $DeviceStatus = $_.DisplayName
        }
        if($_.Name -eq $Device.ManufacturerEnum){
            $Manufacturer = $_.DisplayName
        }
        if($_.Name -eq $Device.ModelEnum){
            $Model = $_.DisplayName
        }
    }

    #Get List of Relationship Objects for this device
    $Relationships = Get-SCSMRelationshipObject -BySource $Device -computername $CompName

    #Select PrimaryUser, Location, CatalogItem, and CostCenter by RelationshipClass id
    $Relationships | ForEach-Object{
        if($_.IsDeleted -eq $false){
            if($_.RelationshipId -eq $PrimaryUserRelationId){
                $PrimaryUser = $_.TargetObject
            }
            if($_.RelationshipId -eq $LocationRelationId){
                $Location = $_.TargetObject
            }
            if($_.RelationshipId -eq $CatalogItemRelationId){
                $CatalogItem = $_.TargetObject
            }
            if($_.RelationshipId -eq $CostCenterRelationId){
                $CostCenter  = $_.TargetObject
            }
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

}

#Export or Return
#$SCSMDevices | Export-Csv -Path "$Path\SCSMDevices.csv"
#return $SCSMDevices
#>


############################################ Audit ############################################################

Write-Host "Starting comparison..."
#For Testing purposes, use csv import
#$SCSMDevices    = Import-Csv -Path "C:\Users\$env:username\Documents\SCSMDevices.csv"
#$GenesysDevices = Import-Csv -Path "C:\Users\$env:username\Documents\GenesysDevices.csv"

#Create List for new device export
$NewPhones = [System.Collections.Generic.List[Object]]::new()

#Retrieve relationship classes
$PrimaryUserRelation = Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasPrimaryUser -ComputerName $CompName
$LocationRelation    = Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasLocation    -ComputerName $CompName
$CatalogItemRelation = Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasCatalogItem -ComputerName $CompName
$CostCenterRelation  = Get-SCSMRelationshipClass -Name Cireson.AssetManagement.HardwareAssetHasCostCenter  -ComputerName $CompName

#Retrieve classes for relationships
$UserClass           = Get-SCSMClass -Name System.Domain.User -ComputerName $CompName
$LocationClass       = Get-SCSMClass -Name Cireson.AssetManagement.Location -ComputerName $CompName
$CatalogItemClass    = Get-SCSMClass -Name Cireson.AssetManagement.CatalogItem -ComputerName $CompName
$CostCenterClass     = Get-SCSMClass -Name Cireson.AssetManagement.CostCenter -ComputerName $CompName

#Loop Genesys devices to verify integrity of SCSM data
foreach($GDevice in $GenesysDevices){
    Write-Host $GDevice.PhoneName
    #Create/Reset All Vars
    $PrimaryUser,$Pri,$Location,$Loc,$CostCenter,$CC,$CatalogItem,$CI,$PropertyHash,$NewGuid,$NewPhone = $null

    #Create propery hash table
    $PropertyHash = @{
        "AssetTag"            = $GDevice.PhoneName
        "DisplayName"         = $GDevice.PhoneName
        "Name"                = $GDevice.PhoneName
        "LocationDetails"     = 'NOCUBE'
        "SerialNumber"        = $GDevice.SerialNumber
        "HardwareAssetStatus" = Get-SCSMEnumeration -ComputerName $CompName -name Cireson.AssetManagement.HardwareAssetStatusEnum.Deployed
        "HardwareAssetType"   = Get-SCSMEnumeration -ComputerName $CompName -Name Enum.761f04478a2945a2a184038935259743
    }

    #Get details for PrimaryUser, Location, CatalogItem, and CostCenter
    $Pri = $GDevice.Location
    $Loc = $GDevice.Location
    $CC  = 'Cost center name'
    $CI  = $GDevice.HardwareType

    #Create Filters to match above data to SCSM data
    $PriFilter = "DisplayName -like '$Pri*S*C*'"
    $LocFilter = "Name -like '$Loc*Service Center'"
    $CCFilter  = "Name -eq $CC"
    $CIFilter  = "Name -eq $CI"

    #Match Genesys Data to SCSM data using filters created above
    $PrimaryUser = Get-SCSMObject -ComputerName $CompName -Class $UserClass -Filter $PriFilter
    $Location    = Get-SCSMObject -ComputerName $CompName -Class $LocationClass -Filter $LocFilter
    $CostCenter  = Get-SCSMObject -ComputerName $CompName -Class $CostCenterClass -Filter $CCFilter
    $CatalogItem = Get-SCSMObject -ComputerName $CompName -Class $CatalogItemClass -Filter $CIFilter

    #If any matches come back with more than one object, select the first
    if($PrimaryUser.count -gt 1){
        $PrimaryUser = $PrimaryUser[0]
    }
    if($Location.count -gt 1){
        $Location = $Location[0]
    }
    if($CostCenter.count -gt 1){
        $CostCenter = $CostCenter[0]
    }
    if($CatalogItem.count -gt 1){
        $CatalogItem = $CatalogItem[0]
    }

    #Add Model and Manufacturer Enums to our property hash using CatalogItem info
    $CatalogItem.Values | ForEach-Object{
        if($_.Type.toString() -eq "Model"){
            $PropertyHash.Add("ModelEnum",$_.value)
        }
        if($_.Type.toString() -eq "Manufacturer"){
            $PropertyHash.Add("ManufacturerEnum",$_.value)
        }
    }

    #Check if device exists in SCSM
    #       We should check with serial number, however several assets exist with incorrect serial numbers
    #       By checking with asset tag we can minimize duplication assuming no duplicate asset tags exist
    #       This is a very important check as we need to make sure we are not creating duplicates in the system

    if($SCSMDevices.AssetTag -eq $GDevice.PhoneName){#This means the asset exists in SCSM

        #Create/reset SM device vars
        $SMDevice,$SMPropertyHash = $null

        #Get object with matching asset tag (should be same check as above)
        $AT = $GDevice.PhoneName
        $SMDevice = Get-SCSMObject -ComputerName $CompName -Class $DeviceClass -Filter "AssetTag -eq '$AT'"
        #If more than one device returns, select the first
        if($SMDevice.count -gt 1){
            $SMDevice = $SMDevice[0]
        }

        #Make another property hash table with SMDevice
        $SMPropertyHash = @{
            "AssetTag"            = $SMDevice.AssetTag
            "DisplayName"         = $SMDevice.DisplayName
            "Name"                = $SMDevice.Name
            "LocationDetails"     = $SMDevice.LocationDetails
            "SerialNumber"        = $SMDevice.SerialNumber
            "HardwareAssetStatus" = $SMDevice.HardwareAssetStatus
            "HardwareAssetType"   = $SMDevice.HardwareAssetType
            "ModelEnum"           = $SMDevice.ModelEnum
            "ManufacturerEnum"    = $SMDevice.ManufacturerEnum
        }

        ################### UPDATES ##################################


        #Match check for simple properties (hash table) - assume true, prove false

        $Match = $true
        foreach($Key in $PropertyHash.Keys){
            if($PropertyHash.Item($Key) -ne $SMPropertyHash.Item($Key)){
                $Match = $false
            }
        }
        #if property hashes do not match, rather than determining the individual incorrect key, update entire property hash
        if($Match -eq $false){
            Write-Host "Updating Properties"
            Set-SCSMObject -ComputerName $CompName -SMObject $SMDevice -PropertyHashtable $PropertyHash
        }


        #Create/Reset Relationship vars
        $CurLocation,$CurPriUser,$CurCostCenter,$CurCatItem,$Relations = $null

        #Get Current Device Relationships
        $Relations = Get-SCSMRelationshipObject -ComputerName $CompName -BySource $SMDevice

        #Get Readable Relationships
        $Relations | ForEach-Object{
            if($_.IsDeleted -eq $False){
                if($_.RelationshipId -eq $LocationRelationId){
                    $CurLocation   = $_.TargetObject
                }
                if($_.RelationshipId -eq $PrimaryUserRelationId){
                    $CurPriUser    = $_.TargetObject
                }
                if($_.RelationshipId -eq $CostCenterRelationId){
                    $CurCostCenter = $_.TargetObject
                }
                if($_.RelationshipId -eq $CatalogItemRelationId){
                    $CurCatItem    = $_.TargetObject
                }
            }
        }


        #Match check for relationship properties

        if(($CurLocation -ne $Location) -or ($null -eq $CurLocation)){
            #First Remove old location (if it exists)
            if($null -ne $CurLocation){
                foreach($R in $Relations){
                    if(($R.RelationshipId -eq $LocationRelationId) -and ($R.IsDeleted -eq $False)){
                        Remove-SCSMRelationshipObject -SMObject $R -ComputerName $CompName
                    }
                }
            }

            #Then create new relationship object with corrected location (if it was found)
            if($null -ne $Location){
                Write-Host "Updating Location"
                New-SCSMRelationshipObject -Relationship $LocationRelation -Source $SMDevice -Target $Location -ComputerName $CompName -Bulk
            }
        }
        

        if(($CurPriUser -ne $PrimaryUser) -or ($null -eq $CurPriUser)){
            #First Remove old primary user (if it exists)
            if($null -ne $CurPriUser){
                foreach($R in $Relations){
                    if(($R.RelationshipId -eq $PrimaryUserRelationId) -and ($R.IsDeleted -eq $False)){
                        Remove-SCSMRelationshipObject -SMObject $R -ComputerName $CompName
                    }
                }
            }

            #Then create new relationship object with corrected primary user (if it was found)
            if($null -ne $PrimaryUser){
                Write-Host "Updating Primary User"
                New-SCSMRelationshipObject -Relationship $PrimaryUserRelation -Source $SMDevice -Target $PrimaryUser -ComputerName $CompName -Bulk
            }
        }
        
        if(($CurCostCenter -ne $CostCenter) -or ($null -eq $CurCostCenter)){
            #First Remove old cost center (if it exists)
            if($null -ne $CurCostCenter){
                foreach($R in $Relations){
                    if(($R.RelationshipId -eq $CostCenterRelationId) -and ($R.IsDeleted -eq $False)){
                        Remove-SCSMRelationshipObject -SMObject $R -ComputerName $CompName
                    }
                }
            }

            #Then create new relationship object with corrected cost center (if it was found)
            if($null -ne $CostCenter){
                Write-Host "Updating Cost Center"
                New-SCSMRelationshipObject -Relationship $CostCenterRelation -Source $SMDevice -Target $CostCenter -ComputerName $CompName -Bulk
            }
        }

        #In theory, this should never run because an asset can't change what it is
        if(($CurCatItem -ne $CatalogItem) -or ($null -eq $CurCatItem)){
            #First Remove old catalog item (if it exists)
            if($null -ne $CurCatItem){
                foreach($R in $Relations){
                    if(($R.RelationshipId -eq $CatalogItemRelationId) -and ($R.IsDeleted -eq $False)){
                        Remove-SCSMRelationshipObject -SMObject $R -ComputerName $CompName
                    }
                }
            }

            #Then create new relationship object with corrected catalog item (if it was found)
            if($null -ne $CatalogItem){
                Write-Host "Updating Catalog Item"
                New-SCSMRelationshipObject -Relationship $CatalogItemRelation -Source $SMDevice -Target $CatalogItem -ComputerName $CompName -Bulk
            }
        }

    }else{#This means the asset does not exist in SCSM - Therefore we create a new device
        ###################################  NEW DEVICE ######################################
        Write-Host "New Device"
        #Create new guid and add to property hash
        $NewGuid = (New-Guid).Guid
        $PropertyHash.Add("HardwareAssetId",$NewGuid.ToString())

        #Create new SCSM object with property hash
        $NewPhone = New-SCSMObject -Class $DeviceClass -PropertyHashtable $PropertyHash -ComputerName $CompName -PassThru

        #All Relationship objects are already retrieved

        #Link objects retrieved to new phone with relationship class
        New-SCSMRelationshipObject -Relationship $PrimaryUserRelation -Source $NewPhone -Target $PrimaryUser -ComputerName $CompName -Bulk
        New-SCSMRelationshipObject -Relationship $LocationRelation -Source $NewPhone -Target $Location -ComputerName $CompName -Bulk
        New-SCSMRelationshipObject -Relationship $CatalogItemRelation -Source $NewPhone -Target $CatalogItem -ComputerName $CompName -Bulk
        New-SCSMRelationshipObject -Relationship $CostCenterRelation -Source $NewPhone -Target $CostCenter -ComputerName $CompName -Bulk
        #>
    }
}
Write-Host "Done"

############################################## Retires ######################################################################


#     This section retires devices from SCSM that are not in the Genesys report
#                  To use, remove the less-than sign at the start of this comment

Write-Host "Retiring Phones that are not in Genesys..."

#Phone Hardware Type GUID
$HTPhone = 'Phone hardware type guid'

#Filter SCSM Devices by Phone GUID
$SCSMPhones = Get-SCSMObject -ComputerName $CompName -Class $DeviceClass -Filter "HardwareAssetType -eq $HTPhone"

#Create Retire Enum Var
$Retire = Get-SCSMEnumeration -ComputerName $CompName -name Cireson.AssetManagement.HardwareAssetStatusEnum.Retired

#Create List for Retired Devices
$RetireList = [System.Collections.Generic.List[Object]]::new()

foreach($SDevice in $SCSMPhones){
    $Found = $False
    #Check if SCSM Phone is in our Genesys List
    if($GenesysDevices.PhoneName -eq $SDevice.AssetTag){
        $Found = $True
    }

    #If its not found and not retired already
    if(($Found -eq $False) -and ($SDevice.HardwareAssetStatus -ne $Retire)){

        Write-Host $SDevice.AssetTag
        #Set Device to retired
        Set-SCSMObject -ComputerName $CompName -SMObject $SDevice -Property "HardwareAssetStatus" -Value $Retire

        #Create report of retired devices
        foreach($Enum in $Enums){
            if($Enum.Name -eq $SDevice.HardwareAssetStatus){
                $DeviceStatus = $Enum.DisplayName
            }
        }
        $ReportLine = [PSCustomObject]@{
            AssetTag       = $SDevice.AssetTag
            SerialNumber   = $SDevice.SerialNumber
            HardwareStatus = $DeviceStatus #This status shows what it used to be
            HardwareId     = $SDevice.HardwareAssetId
        }
        $RetireList.Add($ReportLine)
    }
}

Write-Host "Done"
#Export Retire List
$RetireList | Export-Csv -path "$Path\RetireList.csv"

#>          #End of Retire section


##################################################################################################################
