[CmdletBinding(PositionalBinding = $false)]
param (
    [Parameter(Mandatory=$false)]
    [String] $UserName,

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
    [Switch] $DeleteNotFoundPartitions,

    [Parameter(Mandatory=$false)]
    [String] $PartitionId,

    [Parameter(Mandatory=$false)]
    [String] $ServiceId,
 
    [Parameter(Mandatory=$false)]
    [String] $ApplicationId,

    [Parameter(Mandatory=$false)]
    [String] $ClientCertificateThumbprint
)

$command = ""
if($StorageType -eq "FileShare")
{
  if(!$FileSharePath)
  {
    $FileSharePath = Read-Host -Prompt "Please enter the FileShare path"
  }

  if($UserName)
  {
      $command = $command +  ".\RetentionScriptFileShare.ps1 -UserName `"$UserName`" -FileSharePath `"$FileSharePath`" -DateTimeBefore `"$DateTimeBefore`" -ClusterEndPoint `"$ClusterEndPoint`""
  }
  else {
    $command = $command +  ".\RetentionScriptFileShare.ps1 -FileSharePath `"$FileSharePath`" -DateTimeBefore `"$DateTimeBefore`" -ClusterEndPoint `"$ClusterEndPoint`""
  }
}
elseif($StorageType -eq "AzureBlob")
{
    if($ConnectionString)
    {
        if($ContainerName)
        {
            $command = $command + ".\RetentionScriptAzureShare.ps1 -ConnectionString `"$ConnectionString`" -DateTimeBefore `"$DateTimeBefore`" -ClusterEndPoint `"$ClusterEndPoint`""
        }
        else {
            $command = $command + ".\RetentionScriptAzureShare.ps1 -ConnectionString `"$ConnectionString`" -DateTimeBefore `"$DateTimeBefore`" -ClusterEndPoint `"$ClusterEndPoint`""
        }
    }
    else {
        if(!$StorageAccountName)
        {
            $StorageAccountName = Read-Host -Prompt "Please enter the Storage account name"
        }
        if(!$StorageAccountKey)
        {
            $StorageAccountKey = Read-Host -Prompt "Please enter the Storage account key"
        }
        $command = $command + ".\RetentionScriptAzureShare.ps1 -StorageAccountName `"$StorageAccountName`" -StorageAccountKey `"$StorageAccountKey`" -DateTimeBefore `"$DateTimeBefore`" -ContainerName `"$ContainerName`" -ClusterEndPoint `"$ClusterEndPoint`""    
    }

    if($ContainerName)
    {
        $command = $command + " -ContainerName `"$ContainerName`""
    }
}
else {
    throw "The storage of type $StorageType not supported"
}

if($ApplicationId)
{
    $command = $command + " -ApplicationId `"$ApplicationId`""
}
if($ServiceId)
{
    $command = $command + " -ServiceId `"$ServiceId`""
}

if($ClientCertificateThumbprint)
{
    $command = $command + " -ClientCertificateThumbprint `"$ClientCertificateThumbprint`""
}

if($PartitionId)
{
    $command = $command + " -PartitionId `"$PartitionId`""
}

if($DeleteNotFoundPartitions)
{
    $command = $command + " -DeleteNotFoundPartitions"    
}

$scriptBlock = [ScriptBlock]::Create($command)
Invoke-Command $scriptBlock