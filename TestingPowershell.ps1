param (
    [Parameter(Mandatory=$false)]
    [String] $userName = $null,

    [Parameter(Mandatory=$false)]
    [String] $password,

    [Parameter(Mandatory=$false)]
    [String] $fileSharePath
)

$userNameDomainList = $username.Split("\",[StringSplitOptions]'RemoveEmptyEntries')

if($userNameDomainList.Length -eq 2)
{
    $userNameToTry = $userNameDomainList[1]
    $domain = $userNameDomainList[0]
}
else {
    $userNameToTry = $userName
    $domain = "."
}

$tokenHandle = 0 
Write-Host $userNameToTry
Write-Host $password
Write-Host $domain


$returnValue = [Import.Win32]::LogonUser($userNameToTry, $domain, $password, 9, 3, [ref]$tokenHandle) 

if (!$returnValue) { 
    $errCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error(); 
    Write-Host "Impersonate-User failed a call to LogonUser with error code: $errCode" 
    throw [System.ComponentModel.Win32Exception]$errCode 
    
}

$Global:ImpersonatedUser = @{}

$Global:ImpersonatedUser.ImpersonationContext = [System.Security.Principal.WindowsIdentity]::Impersonate($tokenHandle)   

Get-ChildItem -Path $fileSharePath -Include *.bkmetadata  -Recurse 
Get-ChildItem -Path $fileSharePath -Include *.zip  -Recurse 