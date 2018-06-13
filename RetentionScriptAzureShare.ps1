param (
    [Parameter(Mandatory=$false)]
    [String] $StorageType,

    [Parameter(Mandatory=$false)]
    [String] $ConnectionString,

    [Parameter(Mandatory=$false)]
    [String] $ContainerName,

    [Parameter(Mandatory=$false)]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$false)]
    [String] $StorageAccountKey,
    
    [Parameter(Mandatory=$true)]
    [String] $dateTimeBefore,
    
    [Parameter(Mandatory=$true)]
    [String] $ClusterEndpoint
)
. .\UtilScript.ps1

$contextForStorageAccount = $null

if($ConnectionString)
{
    $contextForStorageAccount = New-AzureStorageContext -ConnectionString $ConnectionString
}
else
{
    $contextForStorageAccount = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
}

$containerNameList = New-Object System.Collections.ArrayList

if(!$ContainerName.IsPresent)
{
    # Throw exception here.
    $containers = Get-AzureStorageContainer -Context $contextForStorageAccount
    foreach($container in $containers)
    {
        $containerNameList.Add($container.Name)
    }
}
Else {
    $containerNameList.Add($ContainerName)
}

foreach($containerName in $containerNameList)
{
    $blobs  = Get-AzureStorageBlob -Container $containerName -Context $contextForStorageAccount
    $partitionDict = New-Object 'system.collections.generic.dictionary[[string],[system.collections.generic.list[string]]]'
    $finalDateTimeObject = $dateTimeBeforeObject
    $pathsList = New-Object System.Collections.ArrayList
    foreach($blob in $blobs)    
    {
        $pathsList.Add($blob.Name)
    }
    $partitionDict = Get-PartitionDict -pathsList $pathsList

    foreach($partitionid in $partitionDict.Keys)
    {
        $finalDateTimeObject = Get-FinalDateTimeBefore -dateTimeBefore $dateTimeBefore -partitionid $partitionid -ClusterEndpoint $ClusterEndpoint
        if($finalDateTimeObject -eq [DateTime]::MaxValue)
        {
            continue
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




