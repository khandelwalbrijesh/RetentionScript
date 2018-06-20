Function Get-PartitionDict 
{    
    [CmdletBinding(PositionalBinding = $false)]
    param([Parameter(Mandatory=$true)][System.Collections.ArrayList]$pathsList
    ) 

    $partitionDict = New-Object 'system.collections.generic.dictionary[[string],[system.collections.generic.list[string]]]'
    foreach($path in $pathsList)
    {
        $pathList = $path.Split("\",[StringSplitOptions]'RemoveEmptyEntries')
        $length = $pathList.Count
        $partitionID = $null
        if($length -le 1)
        {
            $pathList = $path.Split("/",[StringSplitOptions]'RemoveEmptyEntries')
            $length = $pathList.Count
            if($length -le 1)
            {
                throw "$path is not in correct format."
            }
            Else
            {
                $partitionID = $pathList[$length - 2]
            }
        }
        Else {
            $partitionID = $pathList[$length - 2]            
        }
        
    
        if($partitionID -eq $null)
        {
            throw "Not able to extract partitionID"
        }
        
        if(!$partitionDict.ContainsKey($partitionID))
        {
            Write-Host "Partition Id extracted is this $partitionID"
            $partitionDict.Add($partitionID, $path)
        }
        else {
            $partitionDict[$partitionID].add($path)
        }
    }

    return $partitionDict
}

Function Get-FinalDateTimeBefore 
{   
    [CmdletBinding(PositionalBinding = $false)]    
    param([Parameter(Mandatory=$true)][string]$DateTimeBefore, 
    [Parameter(Mandatory=$true)][string]$Partitionid, 
    [Parameter(Mandatory=$true)][string]$ClusterEndpoint,
    [Parameter(Mandatory=$false)][bool]$DeleteNotFoundPartitions,
    [Parameter(Mandatory=$false)][string]$ClientCertificateThumbprint
    )  

    # DateTime Improvement to be done here.
    $dateTimeBeforeObject = [DateTime]::ParseExact($DateTimeBefore,"yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
    $finalDateTimeObject = $dateTimeBeforeObject
    $dateTimeBeforeString = $dateTimeBeforeObject.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") 
    $url = "http://$ClusterEndpoint/Partitions/$Partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
    $backupEnumerations = $null
    try {
        Write-Host "Querying the URL: $url"
        if($ClientCertificateThumbprint)
        {
            $url = "https://$ClusterEndpoint/Partitions/$Partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
            Write-Host "Querying the URL: $url"    
            $pagedBackupEnumeration = Invoke-RestMethod -Uri $url  -CertificateThumbprint $ClientCertificateThumbprint
        }
        else {  
            Write-Host "Trying to query without cert thumbprint"
            Write-Host "Querying the URL: $url"
            $pagedBackupEnumeration = Invoke-RestMethod  -Uri $url       
        }
        Write-Host "Sorting the list of backupEnumerations with respect to creationTimeUtc."
        $backupEnumerations = $pagedBackupEnumeration.Items | Sort-Object -Property @{Expression = {[DateTime]::ParseExact($_.CreationTimeUtc,"yyyy-MM-ddTHH:mm:ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)}; Ascending = $false}
    }
    catch  {
        $err = $_.ToString() | ConvertFrom-Json
        if($err.Error.Code -eq "FABRIC_E_PARTITION_NOT_FOUND")
        {
            Write-Host "$Partitionid is not found." 
            if($DeleteNotFoundPartitions -eq $true)
            {
                Write-Host "DeleteNotFoundPartitions flag is enabled so, deleting data all in this partition"
                return [DateTime]::MaxValue
            }
            else {
                Write-Host "If you want to delete the data in this partition."
                Write-Host "If you want to remove this partition as well, please run the script by enabling force flag."
                return [DateTime]::MinValue
            }
        }
        else {
            throw $_.Exception.Message
        }
    }

    Write-Host "Finding the finalDateTime in backupEnumerations."
    Write-Host "Iterating over backupEnumerations till we find the last full backup"
    $fullBackupFound = $false
    foreach($backupEnumeration in $backupEnumerations)
    {
        Write-Host $backupEnumeration.BackupType
        if($backupEnumeration.BackupType -eq "Full")
        {
            Write-Host "Full backup is found."
            $finalDateTimeObject = [DateTime]::Parse($backupEnumeration.CreationTimeUtc)
            $fullBackupFound = $true
            break
        }
    }
    if($backupEnumerations.Count -eq 0)
    {
        Write-Host "The BackupEnumerations had length equal to 0. So, could not go through with the cleanup for this partition: $Partitionid"
        return [DateTime]::MinValue
    }

    if(!$fullBackupFound)
    {
        Write-Host "The Backups Before this $dateTimeBeforeString date are corrupt as no full backup is found, So, deleting them."
    }
    return $finalDateTimeObject
}


Function Get-PartitionIdList 
{   
    [CmdletBinding(PositionalBinding = $false)]
    param([Parameter(Mandatory=$false)][string]$ApplicationId, 
    [Parameter(Mandatory=$false)][string]$ServiceId,
    [Parameter(Mandatory=$true)][string]$ClusterEndpoint,    
    [Parameter(Mandatory=$false)][string]$ClientCertificateThumbprint
    ) 
    # need to add continuationToken Logic here.
    $serviceIdList = New-Object System.Collections.ArrayList
    if($ApplicationId)
    {
        if($ClientCertificateThumbprint)
        {
            $serviceIdList = Get-ServiceIdList -ApplicationId $ApplicationId -ClusterEndpoint $ClusterEndpoint -ClientCertificateThumbprint $ClientCertificateThumbprint
        }
        else {
            $serviceIdList = Get-ServiceIdList -ApplicationId $ApplicationId -ClusterEndpoint $ClusterEndpoint
        }
    }
    else {
        $serviceIdList.Add($ServiceId) | Out-Null
    }

    $partitionIdList = New-Object System.Collections.ArrayList

    foreach($serviceId in $serviceIdList)
    {
        Write-Host " Service Id found: $serviceId"
        $continuationToken = $null
        do
        {
            if($ClientCertificateThumbprint)
            {
                $partitionInfoList = Invoke-RestMethod -Uri "https://$ClusterEndpoint/Services/$serviceId/$/GetPartitions?api-version=6.2&ContinuationToken=$continuationToken"  -CertificateThumbprint $ClientCertificateThumbprint
            }
            else {  
                Write-Host "Trying to query without cert thumbprint"
                $partitionInfoList = Invoke-RestMethod -Uri "http://$ClusterEndpoint/Services/$serviceId/$/GetPartitions?api-version=6.2&ContinuationToken=$continuationToken" 
            }
            foreach($partitionInfo in $partitionInfoList.Items)
            {
                $partitionid = $partitionInfo.PartitionInformation.Id
                Write-Host "$partitionid"    
                $partitionIdList.Add($partitionInfo.PartitionInformation.Id)
            }
            $continuationToken = $partitionInfoList.ContinuationToken
        }while($continuationToken -ne "")
    }
    $length = $partitionIdList.Count
    Write-Host "The total number of partitions found are $length"
    return $partitionIdList
}


Function Get-ServiceIdList 
{   
    [CmdletBinding(PositionalBinding = $false)]
    param([Parameter(Mandatory=$true)][string]$ApplicationId,
    [Parameter(Mandatory=$true)][string]$ClusterEndpoint,    
    [Parameter(Mandatory=$false)][string]$ClientCertificateThumbprint
        )

    $continuationToken = $null
    $serviceIdList = New-Object System.Collections.ArrayList
    do
    {
        if($ClientCertificateThumbprint)
        {
            $serviceInfoList = Invoke-RestMethod -Uri "https://$ClusterEndpoint/Applications/$ApplicationId/$/GetServices?api-version=6.2&ContinuationToken=$continuationToken" -CertificateThumbprint $ClientCertificateThumbprint
        }
        else {  
            Write-Host "Trying to query without cert thumbprint"
            $serviceInfoList = Invoke-RestMethod -Uri "http://$ClusterEndpoint/Applications/$ApplicationId/$/GetServices?api-version=6.2&ContinuationToken=$continuationToken"
        }
        foreach($serviceInfo in $serviceInfoList.Items)
        {
            $serviceIdList.Add($serviceInfo.Id) | Out-Null
            $serviceId = $serviceInfo.Id
            Write-Host "$serviceId"
        }
        $continuationToken = $serviceInfoList.ContinuationToken
    }while($continuationToken -ne "")

    $length = $serviceIdList.Count
    Write-Host "$ApplicationId has $length number of services"
    return $serviceIdList
}


Function Start-BackupDataCorruptionTest 
{  
    [CmdletBinding(PositionalBinding = $false)]
    param([Parameter(Mandatory=$true)][string]$DateTimeBefore,
    [Parameter(Mandatory=$true)][string]$Partitionid, 
    [Parameter(Mandatory=$true)][string]$ClusterEndpoint,
    [Parameter(Mandatory=$false)][string]$ClientCertificateThumbprint
    )
    $dateTimeBeforeObject = [DateTime]::ParseExact($DateTimeBefore,"yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
    $finalDateTimeObject = $dateTimeBeforeObject
    $dateTimeBeforeString = $dateTimeBeforeObject.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") 
    # DateTime Improvement to be done here.
    $url = "http://$ClusterEndpoint/Partitions/$Partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
    Write-Host "$url"
    
    $backupEnumerations = $null
    try {
        if($ClientCertificateThumbprint)
        {
            $url = "https://$ClusterEndpoint/Partitions/$Partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
            Write-Host "Querying the URL: $url"
            $pagedBackupEnumeration = Invoke-RestMethod -Uri $url -CertificateThumbprint  $ClientCertificateThumbprint
        }
        else {
            Write-Host "Querying the URL: $url"
            $pagedBackupEnumeration = Invoke-RestMethod -Uri $url 
        }
        $backupEnumerations = $pagedBackupEnumeration.Items | Sort-Object -Property @{Expression = {[DateTime]::ParseExact($_.CreationTimeUtc,"yyyy-MM-ddTHH:mm:ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)}; Ascending = $true}
        
        if($backupEnumerations -ne $null -and $backupEnumerations[0].BackupType -ne "Full")
        {
            throw "Data is corrupted for this partition : $Partitionid"
        }
    }
    catch  {
        $err = $_.ToString() | ConvertFrom-Json
        if($err.Error.Code -eq "FABRIC_E_PARTITION_NOT_FOUND")
        {
            Write-Host "Partition not found, so, could not go through with testing the integrity of data of this partition."
        }
        else {
            throw $_.Exception.Message
        }
    }
}