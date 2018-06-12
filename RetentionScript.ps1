param (
    [Parameter(Mandatory=$false)]
    [String] $userName = $null,

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
    [String []] $ContainerNames,

    [Parameter(Mandatory=$false)]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$false)]
    [String] $StorageAccountKey,

    [Parameter(Mandatory=$true)]
    [String] $ApplicationName,

    [Parameter(Mandatory=$true)]
    [String] $ClusterEndPoint
)


if($StorageType == "FileShare")
{
  if(!$fileSharePath.isPresent)
  {
    throw "Please specify file share path and then, run the script"
  }

  if($userName.isPresent)
  {
      if(!$password.isPresent)
      {
          throw "If username is specified then, password should also be specified"
      } 
      .\RetentionScriptFileShare.ps1 -userName $userName -fileSharePath $fileSharePath -password $password -dateTimeBefore $dateTimeBefore -ClusterEndPoint $ClusterEndPoint
  }
  else {
    .\RetentionScriptFileShare.ps1 -fileSharePath $fileSharePath -dateTimeBefore $dateTimeBefore -ClusterEndPoint $ClusterEndPoint
  }
}
elseif($StorageType == "AzureBlob")
{
    if($ConnectionString.isPresent)
    {
        if($ContainerNames.isPresent)
        {
            .\RetentionScriptAzureShare.ps1 -ConnectionString $ConnectionString -dateTimeBefore $dateTimeBefore -ContainerNames $ContainerNames -ClusterEndPoint $ClusterEndPoint
        }
        else {
            .\RetentionScriptAzureShare.ps1 -ConnectionString $ConnectionString -dateTimeBefore $dateTimeBefore $ContainerNames -ClusterEndPoint $ClusterEndPoint
        }
    }
    else {
        if(!$StorageAccountName -or !$StorageAccountKey)
        {
            throw "StorageAccountName and StorageAccountKey must be specified to connect to the AzureBlobStore"
        }
        if($ContainerNames.isPresent)
        {
            .\RetentionScriptAzureShare.ps1 -StorageAccountName $StorageAccontName -StorageAccountKey $StorageAccountKey -dateTimeBefore $dateTimeBefore -ContainerNames $ContainerNames $ContainerNames -ClusterEndPoint $ClusterEndPoint
        }
        else {
            .\RetentionScriptAzureShare.ps1 -StorageAccountName $StorageAccontName -StorageAccountKey $StorageAccountKey -dateTimeBefore $dateTimeBefore -ClusterEndPoint $ClusterEndPoint
        }        
    }
}
else {
    throw "The storage of type " +  $storageType + "is not supported"
}