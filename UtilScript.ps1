Function Get-PartitionDict 
{    param([Parameter(ParameterSetName="System.Collections.ArrayList", Mandatory=$true)][System.Collections.ArrayList]$pathsList
    ) 

    $partitionDict = New-Object 'system.collections.generic.dictionary[[string],[system.collections.generic.list[string]]]'
    foreach($path in $pathsList)
    {
        $pathList = $path.Split("\",[StringSplitOptions]'RemoveEmptyEntries')
        $length = $pathList.Length
        $partitionID = $null
        if($length -le 1)
        {
            $pathList = $path.Split("/",[StringSplitOptions]'RemoveEmptyEntries')
            $length = $pathList.Length
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
        
        Write-Host "Partition Id extracted is this $partitionID"
    
        if($partitionID -eq $null)
        {
            throw "Not able to extract partitionID"
        }
        
        if(!$partitionDict.ContainsKey($partitionID))
        {
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
    param([Parameter(ParameterSetName="String", Mandatory=$true)][string]$DateTimeBefore, 
    [Parameter(ParameterSetName="String", Mandatory=$true)][string]$Partitionid, 
    [Parameter(ParameterSetName="String", Mandatory=$true)][string]$ClusterEndpoint,
    [Parameter(ParameterSetName="switch", Mandatory=$false)][switch]$Force,
    [Parameter(ParameterSetName="String", Mandatory=$false)][switch]$SSLCertificateThumbPrint
    )  
    # DateTime Improvement to be done here.
    $dateTimeBeforeObject = [DateTime]::ParseExact($DateTimeBefore,"yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
    $finalDateTimeObject = $dateTimeBeforeObject
    $dateTimeBeforeString = $dateTimeBeforeObject.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") 
    $url = "http://$ClusterEndpoint/Partitions/$Partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
    $backupEnumerations = $null
    try {
        Write-Host "Querying the URL: $url"
        if($SSLCertificateThumbPrint -ne $null)
        {
            $pagedBackupEnumeration = Invoke-RestMethod -Uri $url -CertificateThumbprint $SSLCertificateThumbPrint
        }
        else {
            $pagedBackupEnumeration = Invoke-RestMethod -Uri $url            
        }
        Write-Host "Trying to find sorted list of backupEnumerations from paged object."
        $backupEnumerations = $pagedBackupEnumeration.Items | Sort-Object -Property @{Expression = {[DateTime]::ParseExact($_.CreationTimeUtc,"yyyy-MM-ddTHH:mm:ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)}; Ascending = $false}
    }
    catch  {
        $err = $_.ToString() | ConvertFrom-Json
        if($err.Error.Code -eq "FABRIC_E_PARTITION_NOT_FOUND")
        {
            Write-Host "$Partitionid is not found." 
            if($Force)
            {
                Write-Host "Force flag is enabled so, deleting data in this partition"
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
    if($backupEnumerations.Length -eq 0)
    {
        Write-Host "The BackupEnumerations had length equal to 0. So, not deleting anything."
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
    param([Parameter(ParameterSetName="String", Mandatory=$false)][string]$ApplicationId, 
    [Parameter(ParameterSetName="String", Mandatory=$false)][string]$ServiceId
    ) 
    # need to add continuationToken Logic here.
    $serviceIdList = New-Object System.Collections.ArrayList
    if(ApplicationId)
    {
        $serviceIdList = Get-ServiceIdList $ApplicationId
    }
    else {
        $serviceIdList.Add($ServiceId)
    }

    $partitionIdList = New-Object System.Collections.ArrayList


    foreach($serviceId in $serviceIdList)
    {
        $continuationToken = $null
        do
        {
            $partitionInfoList = Invoke-RestMethod "http://localhost:19080/Services/$serviceId/$/GetPartitions?api-version=6.2&ContinuationToken=$continuationToken"
            foreach($partitionInfo in $partitionInfoList.Items)
            {
                $partitionIdList.Add($partitionInfo.PartitionInformation.Id)
            }
            $continuationToken = $partitionInfoList.ContinuationToken

        }while($continuationToken -ne $null)

    }

    return $partitionIdList
}


Function Get-ServiceIdList 
{   
    param([Parameter(ParameterSetName="String", Mandatory=$true)][string]$ApplicationId
        )

    # need to add continuationToken Logic here.    
    $continuationToken = $null
    $serviceIdList = New-Object System.Collections.ArrayList
    do
    {
        $serviceInfoList = Invoke-RestMethod "http://localhost:19080/Applications/$ApplicationId/$/GetServices?api-version=6.2&ContinuationToken=$continuationToken"
        foreach($serviceInfo in $serviceInfoList.Items)
        {
            $serviceIdList.Add($serviceInfo.Id)
        }
        $continuationToken = $serviceInfoList.ContinuationToken
    }while($continuationToken -ne $null)

    return $serviceIdList
}


Function Start-BackupDataCorruptionTest 
{  
    param([Parameter(ParameterSetName="String", Mandatory=$true)][string]$Partitionid, 
    [Parameter(ParameterSetName="String", Mandatory=$true)][string]$ClusterEndpoint,
    [Parameter(ParameterSetName="String", Mandatory=$false)][switch]$SSLCertificateThumbPrint
    )  
    # DateTime Improvement to be done here.
    $url = "http://$ClusterEndpoint/Partitions/$Partitionid/$/GetBackups?api-version=6.2-preview"
    $backupEnumerations = $null
    try {
        Write-Host "Querying the URL: $url"
        if($SSLCertificateThumbPrint -ne $null)
        {
            $pagedBackupEnumeration = Invoke-RestMethod -Uri $url -CertificateThumbprint $SSLCertificateThumbPrint
        }
        else {
            $pagedBackupEnumeration = Invoke-RestMethod -Uri $url            
        }
        Write-Host "Trying to find sorted list of backupEnumerations from paged object."
        $backupEnumerations = $pagedBackupEnumeration.Items | Sort-Object -Property @{Expression = {[DateTime]::ParseExact($_.CreationTimeUtc,"yyyy-MM-ddTHH:mm:ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)}; Ascending = $true}
        if($backupEnumerations.Items[0].BackupType -ne "Full")
        {
            throw "Data is corrupted for this partition : $Partitionid"
        }
    }
    catch  {
        $err = $_.ToString() | ConvertFrom-Json
        if($err.Error.Code -eq "FABRIC_E_PARTITION_NOT_FOUND")
        {
            Write-Host "Partition not found, so, leaving the partition as it is."
        }
        else {
            throw $_.Exception.Message
        }
    }
}