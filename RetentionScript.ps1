param (
    [Parameter(Mandatory=$false)]
    [String] $UserName,

    [Parameter(Mandatory=$false)]
    [String] $Password,

    [Parameter(Mandatory=$false)]
    [String] $FileSharePath,

    [Parameter(Mandatory=$true)]
    [String] $StorageType,

    [Parameter(Mandatory=$true)]
    [String] $DateTimeBefore,
    
    [Parameter(Mandatory=$false)]
    [String] $ConnectionString,

    [Parameter(Mandatory=$false)]
    [String] $ContainerName,

    [Parameter(Mandatory=$false)]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$false)]
    [String] $StorageAccountKey,

    [Parameter(Mandatory=$true)]
    [String] $ClusterEndPoint,

    [Parameter(Mandatory=$false)]
    [switch] $Force,

    [Parameter(Mandatory=$false)]
    [String] $PartitionId,

    [Parameter(Mandatory=$false)]
    [String] $SSLCertificateThumbPrint,
    
    [Parameter(Mandatory=$false)]
    [String] $ApplicationId,

    [Parameter(Mandatory=$false)]
    [String] $ServiceId
)
if(!$PartitionId)
{
    $PartitionId = $null
}
if(!$ApplicationId)
{
    $ApplicationId = $null
}
if(!$ServiceId)
{
    $ServiceId = $null
}

if(!$SSLCertificateThumbPrint)
{
    $SSLCertificateThumbPrint = $null
}


if($StorageType -eq "FileShare")
{
  if(!$FileSharePath)
  {
    throw "Please specify file share path and then, run the script"
  }

  if($UserName)
  {
      if(!$Password)
      {
          throw "If username is specified then, password should also be specified"
      } 
      .\RetentionScriptFileShare.ps1 -UserName $UserName -FileSharePath $FileSharePath -Password $Password -DateTimeBefore $DateTimeBefore -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId -ApplicationId $ApplicationId
  }
  else {
    .\RetentionScriptFileShare.ps1 -FileSharePath $FileSharePath -DateTimeBefore $DateTimeBefore -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId -ApplicationId $ApplicationId
  }
}
elseif($StorageType -eq "AzureBlob")
{
    if($ConnectionString)
    {
        if($ContainerName)
        {
            .\RetentionScriptAzureShare.ps1 -ConnectionString $ConnectionString -DateTimeBefore $DateTimeBefore -ContainerName $ContainerName -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId -ApplicationId $ApplicationId
        }
        else {
            .\RetentionScriptAzureShare.ps1 -ConnectionString $ConnectionString -DateTimeBefore $DateTimeBefore $ContainerName -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId -ApplicationId $ApplicationId
        }
    }
    else {
        if(!$StorageAccountName)
        {
            throw "StorageAccountName must be specified to connect to the AzureBlobStore"
        }
        if(!$StorageAccountKey)
        {
            throw "StorageAccountKey must be specified to connect to the AzureBlobStore"
        }

        if($ContainerName)
        {
            .\RetentionScriptAzureShare.ps1 -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -DateTimeBefore $DateTimeBefore -ContainerName $ContainerName $ContainerName -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId -ApplicationId $ApplicationId
        }
        else {
            .\RetentionScriptAzureShare.ps1 -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -DateTimeBefore $DateTimeBefore -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId
        }        
    }
}
else {
    throw "The storage of type $StorageType not supported"
}