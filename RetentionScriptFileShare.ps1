param (
    [Parameter(Mandatory=$false)]
    [String] $userName = $null,

    [Parameter(Mandatory=$false)]
    [String] $password,

    [Parameter(Mandatory=$true)]
    [String] $fileSharePath,

    # this needs to be put in the main powershell script used to excute both these scripts
    [Parameter(Mandatory=$false)]
    [String] $StorageType,

    [Parameter(Mandatory=$true)]
    [String] $dateTimeBefore,    

    [Parameter(Mandatory=$true)]
    [String] $ClusterEndpoint
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
         
    # Close the handle to the token. Voided to mask the Boolean return value. 
    [void][Import.Win32]::CloseHandle($userToken) 
    
}

Write-Host "Enumerating the Share : $fileSharePath"

# Here i will perform the impersonation task and make it proper.
Get-ChildItem -Path $fileSharePath -Include *.bkmetadata -Recurse | ForEach-Object {$filePathList.Add($_.FullName)} 
Get-ChildItem -Path $fileSharePath -Include *.zip -Recurse | ForEach-Object {$filePathList.Add($_.FullName)} 


$partitionDict = New-Object 'system.collections.generic.dictionary[[string],[system.collections.generic.list[string]]]'
$finalDateTimeObject = $dateTimeBeforeObject.ToUniversalTime()
# i dont think that I would want to delete it.
$sortedPathsList = $filePathList | Sort-Object -Property @{Expression = {[DateTime]::ParseExact([System.IO.Path]::GetFileNameWithoutExtension($_) + "Z","yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)}; Ascending = $True}
foreach($path in $sortedPathsList)
{
    $pathList = $path.Split("\",[StringSplitOptions]'RemoveEmptyEntries')
    Write-Host $pathList
    $length = $pathList.Length
    $partitionID = $null
    Write-Host "Length of pathList is $length"
    if($pathList -eq $path)
    {
        $pathList = $path.Split("/",[StringSplitOptions]'RemoveEmptyEntries')
        $length = $pathList.Length
        Write-Host "Length of pathList is $length"
        if($pathList.Length -le 0)
        {
            throw "$path is not in correct format."
        }
        else
        {
            Write-Host "Length of pathList is $length"
            $partitionID = $pathList[$pathList.Length - 2]
        }
    }
    else {
        $partitionID = $pathList[$pathList.Length - 2]            
    }
    Write-Host "Partition Id extracted is this $partitionID"

    if($partitionID -eq $null)
    {
        throw "Not able to extract partitionID"
    }
    if(!$partitionDict.ContainsKey($partitionID))
    {
        $partitionDict.Add($partitionID, $path)        
    }
    else {
        $partitionDict[$partitionID].add($path)
    }
}

foreach($partitionid in $partitionDict.Keys)
{
    $dateTimeBeforeString = $dateTimeBeforeObject.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") 
    $url = "http://$ClusterEndpoint/Partitions/$partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
    Write-Host $url
    $backupEnumerations = $null
    try {
        $pagedBackupEnumeration = Invoke-RestMethod -Uri $url
        Write-Host "pagedBackupEnumeration is found."
        $backupEnumerationsNotSorted = $pagedBackupEnumeration.Items
        Write-Host "backupEnumerationsSorted is found."
        foreach($backupEnumeration in $backupEnumerationsNotSorted)
        {
            Write-Host "Writing the creation time utc of every file."
            Write-Host "$backupEnumeration.CreationTimeUtc"
        }
        $backupEnumerations = $backupEnumerationsNotSorted | Sort-Object -Property @{Expression = {[DateTime]::ParseExact($_.CreationTimeUtc,"yyyy-MM-ddTHH:mm:ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)}; Ascending = $false}
    }
    catch [System.Net.WebException] {
        $err = $_.ToString() | ConvertFrom-Json
        if($err.Error.Code == "FABRIC_E_PARTITION_NOT_FOUND")
        {
            Write-Host "$partitionid is not found. If you want to delete the data in this partition. Skipping this partition."
            Write-Host "If you want to remove this partition as well, please run the script by enabling force flag."
            continue
        }
        else {
            throw $_.Exception.Message
        }
    }
    catch{
        throw $_.Exception.Message
    }
    foreach($backupEnumeration in $backupEnumerations)
    {
        Write-Host $backupEnumeration.CreationTimeUtc
        Write-Host $backupEnumeration.BackupType
        Write-Host "Finding the finalDateTime in backupEnumerations."
        if($backupEnumeration.BackupType -eq "Full")
        {
            $finalDateTimeObject = [DateTime]::Parse($backupEnumeration.CreationTimeUtc)
            break
        }
    }
    foreach($filePath in $partitionDict[$partitionid])
    {
        Write-Host "Processing the file: " $filePath
        $fileNameWithExtension = Split-Path $filePath -Leaf
        $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($fileNameWithExtension)
        $extension =  [IO.Path]::GetExtension($fileNameWithExtension)
        if($extension -eq ".zip" -or $extension -eq ".bkmetadata" )
        {
            $dateTimeObject = [DateTime]::ParseExact($fileNameWithoutExtension + "Z","yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
            if($dateTimeObject.ToUniversalTime() -lt $finalDateTimeObject.ToUniversalTime())
            {
                Write-Host "Deleting the file: $filePath"
                Remove-Item -Path $filePath
            }
        }
    }
    Write-Host "Cleanup for the partitionID: $partitionid is complete "
}




if($userName -ne $null -and $userName -ne "")
{   
    $ImpersonatedUser.ImpersonationContext.Undo() 
    
    #Clean up the Global variable and the function itself. 
    Remove-Variable ImpersonatedUser -Scope Global 
}






