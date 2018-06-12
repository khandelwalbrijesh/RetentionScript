param (
    [Parameter(Mandatory=$false)]
    [String] $StorageType,

    [Parameter(Mandatory=$false)]
    [String] $ConnectionString,

    [Parameter(Mandatory=$false)]
    [String []] $ContainerNames,

    [Parameter(Mandatory=$false)]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$false)]
    [String] $StorageAccountKey,
    
    [Parameter(Mandatory=$true)]
    [String] $dateTimeBefore,
    
    [Parameter(Mandatory=$true)]
    [String] $ClusterEndpoint
)

$dateTimeBeforeObject = [DateTime]::ParseExact($dateTimeBefore,"yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)

$contextForStorageAccount = $null

if(!$ConnectionString.IsPresent)
{
    $contextForStorageAccount = New-AzureStorageContext -ConnectionString $ConnectionString
}
Else
{
    $contextForStorageAccount = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountName
}

$containerNameList = New-Object System.Collections.ArrayList

if(!$ContainerNames.IsPresent)
{
    # Throw exception here.
    $containers = Get-AzureStorageContainer -Context $contextForStorageAccount
    foreach($container in $containers)
    {
        $containerNameList.Add($container.Name)
    }
}
Else {
    foreach($ContainerName in $ContainerNames)
    {
        $containerNameList.Add($ContainerName)
    }
}

foreach($containerName in $containerNameList)
{
    $blobs  = Get-AzureStorageBlob -Container $containerName -Context $contextForStorageAccount
    $partitionDict = New-Object 'system.collections.generic.dictionary[[string],[system.collections.generic.list[string]]]'
    $finalDateTimeObject = $dateTimeBeforeObject
    # i dont think that I would want to delete it.
    $sortedBlobsList = $blobs | Sort -Property @{Expression = {[DateTime]::ParseExact([System.IO.Path]::GetFileNameWithoutExtension($_.Name) + "Z","yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)}; Ascending = $True}
    $sortedPathsList = $sortedBlobsList | Select-Object -Property Name
    foreach($path in $sortedPathsList)
    {
        $pathList = $path.Split("\",[StringSplitOptions]'RemoveEmptyEntries')
        Write-Host $pathList
        $length = $pathList.Length
        Write-Host "Length of pathList is $length"
        $partitionID = $null
        if($pathList -eq $path)
        {
            $pathList = $path.Split("/",[StringSplitOptions]'RemoveEmptyEntries')
            $length = $pathList.Length
            Write-Host "Length of pathList is $length"
            if($length -le 0)
            {
                throw "$path is not in correct format."
            }
            Else
            {
                Write-Host "Length of pathList is $length"
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

    foreach($partitionid in $partitionDict.Keys)
    {
        $dateTimeBeforeString = $dateTimeBeforeObject.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") 
        $url = "http://$ClusterEndpoint/Partitions/$partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
        Write-Host $url
        $backupEnumerations = $null
        try {
            $pagedBackupEnumeration = Invoke-RestMethod -Uri $url
            $backupEnumerationsNotSorted = $pagedBackupEnumeration.Items
            foreach($backupEnumeration in $backupEnumerationsNotSorted)
            {
                Write-Host $backupEnumeration.CreationTimeUtc
            }
            $backupEnumerations = $backupEnumerationsNotSorted | Sort-Object -Property @{Expression = {[DateTime]::ParseExact($_.CreationTimeUtc,"yyyy-MM-ddTHH:mm:ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)}; Ascending = $false}
        }
        catch[System.Net.WebException] {
            $error = $_.ToString() | ConvertFrom-Json
            if($error.Error.Code -eq "FABRIC_E_PARTITION_NOT_FOUND")
            {
                Write-Host "$partitionid is not found. If you want to delete the data in this partition. Skipping this partition."
                Write-Host "If you want to remove this partition as well, please run the script by enabling force flag."
                continue
            }
        }
        catch{
            throw $_.Exception.Message
        }
        foreach($backupEnumeration in $backupEnumerations)
        {
            Write-Host $backupEnumeration.CreationTimeUtc
            Write-Host $backupEnumeration.BackupType
            Write-Host "Finding the finalDateTime in backupEnumerations."
            if($backupEnumeration.BackupType -eq "Full")
            {
                $finalDateTimeObject = [DateTime]::Parse($backupEnumeration.CreationTimeUtc)
                Write-Host "DateTimeObject to delete the time finally is $finalDateTimeObject "
                break
            }
        }
        Write-Host $finalDateTimeObject
        foreach($blobPath in $partitionDict[$partitionid])
        {
            Write-Host "Processing the file: " $blobPath
            $fileNameWithExtension = Split-Path $blobPath -Leaf
            $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($fileNameWithExtension)
            $extension = [IO.Path]::GetExtension($fileNameWithExtension)
            # now make the query
            if($extension -eq ".zip" -or $extension -eq ".bkmetadata" )
            {
                $dateTimeObject = [DateTime]::ParseExact($fileNameWithoutExtension + "Z","yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
                if($dateTimeObject.ToUniversalTime() -lt $finalDateTimeObject.ToUniversalTime())
                {
                    Write-Host "Deleting the file: $blobPath"
                    Remove-AzureStorageBlob -Blob $blobPath -Container $containerName -Context $contextForStorageAccount
                }
            }
        }
        Write-Host "Cleanup for the partitionID: $partitionid is complete "
    }
}




