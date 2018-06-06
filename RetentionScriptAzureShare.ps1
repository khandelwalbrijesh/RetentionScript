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
    [String] $dateTimeBefore
)

$contextForStorageAccount = $null

if(!$ConnectionString.IsPresent)
{
    $contextForStorageAccount = New-AzureStorageContext -ConnectionString $ConnectionString
}
else
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
else {
    foreach($ContainerName in $ContainerNames)
    {
        $containerNameList.Add($ContainerName)
    }
}

foreach($containerName in $containerNameList)
{
    $blobs  = Get-AzureStorageBlob -Container $containerName -Context $contextForStorageAccount
    foreach($blob in $blobs)
    {
        $path = $blob.Name
        $fileNameWithExtension = Split-Path $path -Leaf
        $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($fileNameWithExtension)
        $extension =  [IO.Path]::GetExtension($fileNameWithExtension)
        if($extension -eq ".zip" -or $extension -eq ".bkmetadata" )
        {
            $dateTimeObject = [DateTime]::ParseExact($fileNameWithoutExtension + "Z","yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
            if($dateTimeObject -lt $dateTimeBefore)
            {
                Remove-AzureStorageBlob -Blob $path -Container $container -Context $contextForStorageAccount
            }
        }
    }
}




