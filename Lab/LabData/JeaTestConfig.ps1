Configuration ConfJEA
{
    Import-DscResource -ModuleName JustEnoughAdministration,PSDesiredStateConfiguration
    node localhost
    {
        File DscDiagnosticsRoleCapabilities 
        { 
            SourcePath = 'C:\Artifacts\DscDiagnostics'
            DestinationPath = "C:\Program Files\WindowsPowerShell\Modules\DscDiagnostics"
            Checksum = 'SHA-1'
            Ensure = "Present" 
            Type = 'Directory'
            Recurse = $true 
         }

                
        JeaEndPoint EndPoint
        {
            EndpointName = "DscDiagnostics"
            RoleDefinitions = "@{ 'NT AUTHORITY\Authenticated Users' = @{ RoleCapabilities = 'DscDiagnosticsRead' } }"
            Ensure = 'Present'
            #TranscriptDirectory = “$env:ProgramFiles\WindowsPowerShell\Modules\DscDiagnostics\Transcripts”
            DependsOn = '[File]DscDiagnosticsRoleCapabilities'
            
        }
    }
} 

ConfJea -OutputPath C:\DSC

Start-DscConfiguration -Path C:\DSC