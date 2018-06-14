[CmdletBinding(PositionalBinding = $false)]
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
    [Switch] $Force,

    [Parameter(Mandatory=$false)]
    [String] $PartitionId,

    [Parameter(Mandatory=$false)]
    [String] $ServiceId,
 
    [Parameter(Mandatory=$false)]
    [String] $ApplicationId,

    [Parameter(Mandatory=$false)]
    [String] $SSLCertificateThumbPrint
)
if(!$PartitionId)
{
    Write-Host "Partition not given"
    $PartitionId = $null
}
if(!$ApplicationId)
{
    Write-Host "Application not given"
    $ApplicationId = $null
}
if(!$ServiceId)
{
    Write-Host "Service not given"
    $ServiceId = $null
}

if(!$SSLCertificateThumbPrint)
{
    Write-Host "SSLThumbprint not given"
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
      .\RetentionScriptFileShare.ps1 -UserName $UserName -FileSharePath $FileSharePath -Password $Password -DateTimeBefore $DateTimeBefore -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId -ApplicationId $ApplicationId -SSLCertificateThumbPrint $SSLCertificateThumbPrint
  }
  else {
    .\RetentionScriptFileShare.ps1 -FileSharePath $FileSharePath -DateTimeBefore $DateTimeBefore -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId -ApplicationId $ApplicationId -SSLCertificateThumbPrint $SSLCertificateThumbPrint
  }
}
elseif($StorageType -eq "AzureBlob")
{
    if($ConnectionString)
    {
        if($ContainerName)
        {
            .\RetentionScriptAzureShare.ps1 -ConnectionString $ConnectionString -DateTimeBefore $DateTimeBefore -ContainerName $ContainerName -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId -ApplicationId $ApplicationId -SSLCertificateThumbPrint $SSLCertificateThumbPrint
        }
        else {
            .\RetentionScriptAzureShare.ps1 -ConnectionString $ConnectionString -DateTimeBefore $DateTimeBefore -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId -ApplicationId $ApplicationId -SSLCertificateThumbPrint $SSLCertificateThumbPrint
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
            .\RetentionScriptAzureShare.ps1 -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -DateTimeBefore $DateTimeBefore -ContainerName $ContainerName $ContainerName -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId -ApplicationId $ApplicationId -SSLCertificateThumbPrint $SSLCertificateThumbPrint
        }
        else {
            .\RetentionScriptAzureShare.ps1 -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -DateTimeBefore $DateTimeBefore -ClusterEndPoint $ClusterEndPoint -Force $Force -PartitionId $PartitionId -ServiceId $ServiceId  -ApplicationId $ApplicationId -SSLCertificateThumbPrint $SSLCertificateThumbPrint
        }        
    }
}
else {
    throw "The storage of type $StorageType not supported"
}