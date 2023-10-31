Connect-ExchangeOnline

$DistroGroups = Get-DistributionGroup

$ExportList = [System.Collections.Generic.List[Object]]::new()

#Uses Get-MessageTrace to determine the number of times used in the past 10 days
#Has a 'group' and 'NumMessages' column
#Due to permissions for the command, a csv import is used
$TraceReport = Import-Csv -Path "C:\Users\$env:username\Documents\CSVExports\MessagesInLast10Days.csv"

#Uses data from Start-HistoricalSearch on groups that show a 0 on the trace report
#For more information on how data is gathered check the EOLastUsedTest.ps1 file
#You may receive several reports from said script and they must be appended to each other for this import to work correctly
$HistoricalReport = Import-Csv -Path "C:\Users\$env:username\Documents\CSVExports\HistoricalReport.csv"

$ActiveUsers = Import-Csv -Path "C:\Users\$env:username\Documents\CSVExports\ActiveUsers.csv"

#Counter
$Count = 1
$Total = $DistroGroups.count

$DistroGroups | ForEach-Object {
    #Ignore groups that are security enabled
    if(($_.GroupType.EndsWith("SecurityEnabled")) -eq $False){

        #Create/Reset Vars
        $MemberList,$OwnerList,$MemberOfList,$Group,$MemberOf,$Owner = $null
        $HasNested,$IsNested = $False
        $Mail = $_.primarySMTPAddress
        $Name = $_.DisplayName
        #Get List of members
        $Members = Get-DistributionGroupMember -Identity $_.DistinguishedName
        foreach($Member in $Members){
            #Determine if any members are nested groups
            if(($Member.RecipientType -eq 'Group') -or ($Member.RecipientType -like "MailUniversal*")){ $HasNested = $True }
            #Add members from nested group into seperate column
            
            #Format members into readable list
            if($MemberList.count -eq 0){ $MemberList = $Member.DisplayName }
            else{ $MemberList += (", " + $Member.DisplayName)}
        }
        
        #Get Owner/s
        $Owner = $_.ManagedBy
        
        if($Owner.count -gt 1){
            foreach($Own in $Owner){
                $Active = "(Active)"
                foreach($User in $ActiveUsers){
                    if(($User.DisplayName -eq $Own) -and ($User.BlockCredential -eq $True)){ $Active = "(Inactive)" }
                }
                if($OwnerList.count -eq 0){ $OwnerList = $Own + $Active}
                else { $OwnerList += (", " + $Own + $Active)}
            }
        } else { 
            $Active = "(Active)"
            foreach($User in $ActiveUsers){
                if(($User.DisplayName -eq $Owner) -and ($User.BlockCredential -eq $True)){ $Active = "(Inactive)" }
            }
            $OwnerList = ("$Owner" + "$Active")
        }

        #Get MemberOf from AD
        $Group = Get-ADGroup -Filter {(Mail -eq $Mail) -and (GroupCategory -eq "Distribution")}
        if($null -eq $Group){ $Group = Get-ADGroup -Filter {(Name -eq $Name) -and (GroupCategory -eq "Distribution")} }
        if($null -ne $Group){
            if($Group.count -gt 1){$Group = $Group[1]}
            $MemberOf = Get-ADPrincipalGroupMembership $Group
            if($null -ne $MemberOf){
                $IsNested = $True
                foreach($Member in $MemberOf){
                    if($MemberOfList.count -eq 0){ $MemberOfList = $Member.Name }
                    else{ $MemberOfList += (", " + $Member.Name) }
                }
            } else { $IsNested = $False }  
        }

        #Last Used
        $NumMessages = 0
        foreach($Trace in $TraceReport){
            if($_.DisplayName -eq $Trace.group){
                $NumMessages = [int]$Trace.NumMessages
            }
        }
        if(($NumMessages -eq 0) -or ($null -eq $NumMessages)){
            $CurEA = $_.EmailAddresses | Where-Object {$_ -like "smtp:*"} | ForEach-Object {$_ -replace "smtp:",""}
            foreach($email in $CurEA){
                foreach($Message in $HistoricalReport){
                    if($Message.recipient_status -like "*$email*"){
                        if($NumMessages) { $NumMessages++ }
                        else { $NumMessages = 1 } 
                    }
                }
            }
        }
        
        
        #Format all gathered data
        $ReportLine = [PSCustomObject] @{
            Name         = $Name
            Internal     = $_.RequireSenderAuthenticationEnabled
            HasNested    = $HasNested
            IsNested     = $IsNested
            MessagesSent = $NumMessages
            Owner        = $OwnerList
            Members      = $MemberList
            MemberOf     = $MemberOfList
        }
        $ExportList.add($ReportLine)
    }
    Write-Progress "$Count/$Total"
    $Count++
    #Progress counter
}


#Export
$ExportList | Export-Csv -path "C:\Users\$env:username\Documents\CSVExports\EODistroListTest.csv" -NoTypeInformation
