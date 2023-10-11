#When this script is run, you will receive an immediate export of the number of messages
#each group has received in the past 10 days
#   In addition, you will recieve a number (around 10) of emails to the specified address 
#   that contains a report of the messages recieved in the past 90 days 
#   from the groups that had no messages in the past 10 days   

#Specify Email that the historical reports are sent to
$EmailToSendTo = 'aidan.williamson@bcu.org'

#Specify Path to export to
$Path = "C:\Users\$env:username\Documents"

#Connect to Exchange
Connect-ExchangeOnline

#Get all distribution groups
$DistroGroups = Get-DistributionGroup

#Create a list to export to
$ExportList = [System.Collections.Generic.List[Object]]::new()

#Create vars for historical report sends
$num = 1
$EmailAddresses = $null

#Loop distribution groups
$DistroGroups | ForEach-Object {
    #if the group is not security enabled
    if(($_.GroupType.EndsWith("SecurityEnabled")) -eq $False){
        #Get all emails for current group
        $CurEA = $_.EmailAddresses | Where-Object {$_ -like "smtp:*"} | ForEach-Object {$_ -replace "smtp:",""}
        #Get 10 Day Trace
        $Trace = Get-MessageTrace -RecipientAddress $CurEA -StartDate (Get-Date).AddDays(-10) -EndDate (Get-Date)

        #if trace comes back with 0 count, add emails to list to search
        if(($Trace.count -eq 0) -or ($null -eq $Trace.count)){
            if($EmailAddresses.count -gt 0){ $EmailAddresses += $CurEA }
            else{ $EmailAddresses = $CurEA }
        }

        #because max search is 100 addresses, we need to search and then clear our list
        if($EmailAddresses.count -gt 93){
            #Notify address error we were getting is a general catch all error for the command. 
            Start-HistoricalSearch -ReportTitle "Inactive Search $num" -StartDate (Get-Date).AddDays(-90) -EndDate (Get-Date) -ReportType MessageTrace -RecipientAddress $EmailAddresses -NotifyAddress $EmailToSendTo
            #Increment num for title of next search
            $num++
            #Reset list
            $EmailAddresses = $null
        }

        #Add trace data to export list
        $ReportLine = [PSCustomObject]@{
            Group = $_.DisplayName
            NumMessages = $Trace.count
        }
        $ExportList.add($ReportLine)
    }
}
#after loop is done, check to see if there is any extra searches, and start another search if necessary
if($EmailAddresses.count -gt 0){
    Start-HistoricalSearch -ReportTitle "Inactive Search $num" -StartDate (Get-Date).AddDays(-90) -EndDate (Get-Date) -ReportType MessageTrace -RecipientAddress $EmailAddresses -NotifyAddress $EmailToSendTo
}

$ExportList | Export-Csv -Path "$Path\MessagesInLast10Days.csv" -NoTypeInformation
