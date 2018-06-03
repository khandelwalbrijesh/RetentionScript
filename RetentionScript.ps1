param (
    [Parameter(Mandatory=$true)]
    [string] $ClusterConfigFilePath,

    [Parameter(Mandatory=$false)]
    [switch] $AcceptEULA,

    [Parameter(Mandatory=$false)]
    [switch] $Force,

    [Parameter(Mandatory=$false)]
    [switch] $NoCleanupOnFailure,

    [Parameter(Mandatory=$false)]
    [string] $FabricRuntimePackagePath,

    [Parameter(Mandatory=$false)]
    [switch] $GenerateX509Cert,

    [Parameter(Mandatory=$false)]
    [string] $GeneratedX509CertClusterConfigPath = $null,

    [Parameter(Mandatory=$false)]
    [int] $MaxPercentFailedNodes,

    [Parameter(Mandatory=$false)]
    [int] $TimeoutInSeconds
)
$Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
$IsAdmin = $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)