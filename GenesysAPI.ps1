#Create function to connect to Genesys Cloud
function Connect-GC {
    $authServiceURL = "url to auth"
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
    if ($parms.count) { $uriParms = "?" + ($parms -join "&") } else { $uriParms = "" }
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
            if ($parms.count) { $uriParms = "?" + ($parms -join "&") + "&$pageParm" } else { $uriParms = "?$pageParm" }
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
$PhoneReport = [System.Collections.Generic.List[Object]]::new() 

#Loop through Gensys phones to find physical phones only by hardware ID (MAC address) and add it to the phone report variable for reference in SCSM
ForEach ($Phone in $Phones){
    if ($null -ne $Phone.properties.phone_hardwareId) {

        #Create/Reset Name Vars
        $TypeName, $SiteName = $null

        #Find Hardware Type and Site name in repective lists (Where-Object doesn't work, not sure why)
        ForEach($Type in $PhoneBaseSettings){
            if($Type.id -eq $Phone.phoneBaseSettings.id){$TypeName = $Type.name;break}
        }
        ForEach($Site in $Sites){
            if($Site.id -eq $Phone.site.id){$SiteName = $Site.name;break}
        }

        #Create Report
        $PhoneReportLine  = [PSCustomObject] @{ 
            PhoneName     = $Phone.name
            State         = $Phone.State
            SerialNumber  = $Phone.properties.phone_hardwareId.value.instance
            HardwareType  = $TypeName
            Location      = $SiteName
        }
        $PhoneReport.Add($PhoneReportLine)
    }
}
#Export Data
$PhoneReport | Export-Csv -Path "C:\Users\$env:username\Documents\GenesysDevices.csv"
