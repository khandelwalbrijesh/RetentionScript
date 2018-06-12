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
    param([Parameter(ParameterSetName="String", Mandatory=$true)][string]$dateTimeBefore, 
    [Parameter(ParameterSetName="String", Mandatory=$true)][string]$partitionid, 
    [Parameter(ParameterSetName="String", Mandatory=$true)][string]$ClusterEndpoint
    )  
    $dateTimeBeforeObject = [DateTime]::ParseExact($dateTimeBefore,"yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
    $finalDateTimeObject = $dateTimeBeforeObject
    $dateTimeBeforeString = $dateTimeBeforeObject.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") 
    $url = "http://$ClusterEndpoint/Partitions/$partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
    $backupEnumerations = $null
    try {
        Write-Host "Querying the URL: $url"
        $pagedBackupEnumeration = Invoke-RestMethod -Uri $url
        Write-Host "Trying to find sorted list of backupEnumerations from paged object."
        $backupEnumerations = $pagedBackupEnumeration.Items | Sort-Object -Property @{Expression = {[DateTime]::ParseExact($_.CreationTimeUtc,"yyyy-MM-ddTHH:mm:ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)}; Ascending = $false}
    }
    catch [System.Net.WebException] {
        $err = $_.ToString() | ConvertFrom-Json
        if($err.Error.Code == "FABRIC_E_PARTITION_NOT_FOUND")
        {
            Write-Host "$partitionid is not found. If you want to delete the data in this partition. Skipping this partition."
            Write-Host "If you want to remove this partition as well, please run the script by enabling force flag."
            continue
        }
        else {
            throw $_.Exception.Message
        }
    }
    catch{
        throw $_.Exception.Message
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
    if( $backupEnumerations.Length -gt 0 -and !$fullBackupFound)
    {
        Write-Host "The Backups Before this $dateTimeBeforeString date are corrupt as no full backup is found, So, deleting them."
    }

    return $finalDateTimeObject
}
