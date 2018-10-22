function Get-DscLcmSettings
{
    Get-DscLocalConfigurationManager
}
function Get-DscTagging
{
    $values = Get-ItemProperty -Path HKLM:\SOFTWARE\DscTagging -ErrorAction SilentlyContinue
    if (-not $value)
    {
        Write-Error "There is no DSC tagging in 'HKLM:\SOFTWARE\DscTagging'"
        return
    }

    @{
        BuildDate = $values.BuildDate
        Environment = $values.Environment
        GitCommitId = $values.GitCommitId
        Version = $values.Version
    }
}
function DscDiagnosticsRead
{
    New-PSRoleCapabilityFile -Path C:\DscDiagnosticsRead.psrc `
    -ModulesToImport Microsoft.PowerShell.Management, PSDesiredStateConfiguration `
    -VisibleProviders FileSystem `
    -VisibleCmdlets Get-Command `
    -FunctionDefinitions `
    @{ Name = 'Get-DscLcmSettings'; ScriptBlock = (Get-Command -Name Get-DscLcmSettings).ScriptBlock },
    @{ Name = 'Get-DscTagging'; ScriptBlock = (Get-Command -Name Get-DscTagging).ScriptBlock }

    # Create the RoleCapabilities folder and copy in the PSRC file
    $modulePath = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules\DscDiagnostics"
    $rcFolder = Join-Path -Path $modulePath -ChildPath "RoleCapabilities"
    if (-not (Test-Path -Path $rcFolder))
    {
        mkdir -Path $rcFolder
    }
    Move-Item -Path C:\DscDiagnosticsRead.psrc -Destination $rcFolder -Force
}

function Register-SupportPSSessionConfiguration
{
    param(

        [string[]]$AllowedPrincipals,
        
        [Parameter(Mandatory)]
        [string]$EndpointName
    )
    
    if (-not (Test-Path -Path C:\PowerShellTranscripts))
    {
        mkdir -Path C:\PowerShellTranscripts | Out-Null
    }

    New-PSSessionConfigurationFile -Path c:\DscDiagnostics.pssc `
    -SessionType RestrictedRemoteServer `
    -LanguageMode RestrictedLanguage `
    -ExecutionPolicy Unrestricted `
    -RunAsVirtualAccount `
    -VisibleCmdlets Get-Command `
    -TranscriptDirectory "C:\PowerShellTranscripts\$EndpointName" `
    -FunctionDefinitions @{ Name = 'Dummy'; ScriptBlock = { } } `
    -RoleDefinitions @{
        'NT AUTHORITY\Authenticated Users' = @{ RoleCapabilities = 'DscDiagnosticsRead' }
    }

    Register-PSSessionConfiguration -Name $EndpointName `
    -Path C:\$EndpointName.pssc `
    -Force

    $pssc = Get-PSSessionConfiguration -Name $EndpointName
    $psscSd = New-Object System.Security.AccessControl.CommonSecurityDescriptor($false, $false, $pssc.SecurityDescriptorSddl)

    foreach ($allowedPrincipal in $AllowedPrincipals)
    {
        $account = New-Object System.Security.Principal.NTAccount($allowedPrincipal)
        $accessType = "Allow"
        $accessMask = 268435456
        $inheritanceFlags = "None"
        $propagationFlags = "None"
        $psscSd.DiscretionaryAcl.AddAccess($accessType,$account.Translate([System.Security.Principal.SecurityIdentifier]),$accessMask,$inheritanceFlags,$propagationFlags)
    }

    Set-PSSessionConfiguration -Name $EndpointName -SecurityDescriptorSddl $psscSd.GetSddlForm("All") -Force
    
    # Create a folder for the module
    $modulePath = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules\$EndpointName"
    if (-not (Test-Path -Path $modulePath))
    {
        mkdir -Path $modulePath | Out-Null
    }

    # Create an empty script module and module manifest. At least one file in the module folder must have the same name as the folder itself.
    $path = Join-Path -Path $modulePath -ChildPath "$EndpointName.psm1"
    if (-not (Test-Path -Path $path))
    {
        New-Item -ItemType File -Path $path | Out-Null
    }
    
    $path = Join-Path -Path $modulePath -ChildPath "$EndpointName.psd1"
    if (-not (Test-Path -Path $path))
    {
        New-ModuleManifest -Path $path -RootModule "$EndpointName.psm1"
    }    
}

Register-SupportPSSessionConfiguration -EndpointName DscDiagnostics -AllowedPrincipals 'NT AUTHORITY\Authenticated Users'

DscDiagnosticsRead