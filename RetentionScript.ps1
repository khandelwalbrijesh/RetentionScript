param (
    [Parameter(Mandatory=$false)]
    [String] $userName,

    [Parameter(Mandatory=$false)]
    [String] $password,

    [Parameter(Mandatory=$false)]
    [String] $fileSharePath,

    [Parameter(Mandatory=$true)]
    [String] $StorageType,

    [Parameter(Mandatory=$true)]
    [String] $dateTimeBefore,
    
    [Parameter(Mandatory=$false)]
    [String] $ConnectionString,

    [Parameter(Mandatory=$false)]
    [String] $ContainerName,

    [Parameter(Mandatory=$false)]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$false)]
    [String] $StorageAccountKey,

    [Parameter(Mandatory=$true)]
    [String] $ClusterEndPoint
)


if($StorageType -eq "FileShare")
{
  if(!$fileSharePath)
  {
    throw "Please specify file share path and then, run the script"
  }

  if($userName)
  {
      if(!$password)
      {
          throw "If username is specified then, password should also be specified"
      } 
      .\RetentionScriptFileShare.ps1 -userName $userName -fileSharePath $fileSharePath -password $password -dateTimeBefore $dateTimeBefore -ClusterEndPoint $ClusterEndPoint
  }
  else {
    .\RetentionScriptFileShare.ps1 -fileSharePath $fileSharePath -dateTimeBefore $dateTimeBefore -ClusterEndPoint $ClusterEndPoint
  }
}
elseif($StorageType -eq "AzureBlob")
{
    if($ConnectionString)
    {
        if($ContainerName)
        {
            .\RetentionScriptAzureShare.ps1 -ConnectionString $ConnectionString -dateTimeBefore $dateTimeBefore -ContainerName $ContainerName -ClusterEndPoint $ClusterEndPoint
        }
        else {
            .\RetentionScriptAzureShare.ps1 -ConnectionString $ConnectionString -dateTimeBefore $dateTimeBefore $ContainerName -ClusterEndPoint $ClusterEndPoint
        }
    }
    else {
        if(!$StorageAccountName -or !$StorageAccountKey)
        {
            throw "StorageAccountName and StorageAccountKey must be specified to connect to the AzureBlobStore"
        }
        if($ContainerName)
        {
            .\RetentionScriptAzureShare.ps1 -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -dateTimeBefore $dateTimeBefore -ContainerName $ContainerName $ContainerName -ClusterEndPoint $ClusterEndPoint
        }
        else {
            .\RetentionScriptAzureShare.ps1 -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -dateTimeBefore $dateTimeBefore -ClusterEndPoint $ClusterEndPoint
        }        
    }
}
else {
    throw "The storage of type " +  $storageType + "is not supported"
}