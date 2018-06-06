param (
    [Parameter(Mandatory=$false)]
    [String] $userName = $null,

    [Parameter(Mandatory=$false)]
    [String] $password,

    [Parameter(Mandatory=$false)]
    [String] $fileSharePath,

    # this needs to be put in the main powershell script used to excute both these scripts
    [Parameter(Mandatory=$false)]
    [String] $StorageType,

    [Parameter(Mandatory=$true)]
    [String] $dateTimeBefore
)

Add-Type -Namespace Import -Name Win32 -MemberDefinition @' 
    [DllImport("advapi32.dll", SetLastError = true)] 
    public static extern bool LogonUser(string user, string domain, string password, int logonType, int logonProvider, out IntPtr token); 
 
    [DllImport("kernel32.dll", SetLastError = true)] 
    public static extern bool CloseHandle(IntPtr handle); 
'@ 


Function Get-LogonUserToken 
{
    param([Parameter(ParameterSetName="String", Mandatory=$true)][string]$Username, 
    [Parameter(ParameterSetName="String", Mandatory=$true)][string]$Domain, 
    [Parameter(ParameterSetName="String", Mandatory=$true)][string]$Pass,
    [Parameter(ParameterSetName="String", Mandatory=$false)][string]$LogonType = 'NEW_CREDENTIALS',
    [Parameter(ParameterSetName="String", Mandatory=$false)][string]$LogonProvider = 'WINNT50'
    ) 
    
    $tokenHandle =  [IntPtr]::Zero
    

    $LogonTypeID = Switch ($LogonType) {
        'BATCH' { 4 }
        'INTERACTIVE' { 2 }
        'NETWORK' { 3 }
        'NETWORK_CLEARTEXT' { 8 }
        'NEW_CREDENTIALS' { 9 }
        'SERVICE' { 5 }
    }

    $LogonProviderID = Switch ($LogonProvider) {
        'DEFAULT' { 0 }
        'WINNT40' { 2 }
        'WINNT50' { 3 }
    }

    $returnValue = [Import.Win32]::LogonUser($Username, $Domain, $Password, $LogonTypeID, $LogonProviderID, [ref]$tokenHandle) 
 
    #If it fails, throw the verbose with the error code 
    if (!$returnValue) { 
        $errCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error(); 
        Write-Host "Impersonate-User failed a call to LogonUser with error code: $errCode" 
        throw [System.ComponentModel.Win32Exception]$errCode 
        
    } 
    
    return $tokenHandle
}

$dateTimeBeforeObject = [DateTime]::ParseExact($dateTimeBefore,"yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
$filePathList = New-Object System.Collections.ArrayList
$Global:ImpersonatedUser = @{} 


if($userName -ne $null -and $userName -ne "")
{
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
    
    
    
    $userToken = Get-LogonUserToken  -Username $userNameToTry -Domain $domain -Pass $password
    $Global:ImpersonatedUser.ImpersonationContext = [System.Security.Principal.WindowsIdentity]::Impersonate($userToken) 
         
    #Close the handle to the token. Voided to mask the Boolean return value. 
    [void][Import.Win32]::CloseHandle($userToken) 
    
}

# Here i will perform the impersonation task and make it proper.
Get-ChildItem -Path $fileSharePath -Include *.bkmetadata -Recurse | ForEach-Object {$filePathList.Add($_.FullName)} 
Get-ChildItem -Path $fileSharePath -Include *.zip -Recurse | ForEach-Object {$filePathList.Add($_.FullName)} 

foreach($filePath in $filePathList)
{
    Write-Host "Processing the file: " $filePath
    $fileNameWithExtension = Split-Path $filePath -Leaf
    $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($fileNameWithExtension)
    $extension =  [IO.Path]::GetExtension($fileNameWithExtension)
    if($extension -eq ".zip" -or $extension -eq ".bkmetadata" )
    {
        $dateTimeObject = [DateTime]::ParseExact($fileNameWithoutExtension + "Z","yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
        if($dateTimeObject -lt $dateTimeBeforeObject)
        {
            Remove-Item -Path $filePath
        }
    }
}

if($userName -ne $null -and $userName -ne "")
{   
    $ImpersonatedUser.ImpersonationContext.Undo() 
    
    #Clean up the Global variable and the function itself. 
    Remove-Variable ImpersonatedUser -Scope Global 
}






