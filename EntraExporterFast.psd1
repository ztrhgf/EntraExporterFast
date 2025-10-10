@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'EntraExporterFast.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.1'

    # Supported PSEditions
    CompatiblePSEditions = 'Core','Desktop'

    # ID used to uniquely identify this module
    GUID = '5b2da6fa-9f1c-4589-a6b2-7ddb2bfa8962'

    # Author of this module
    Author = '@AndrewZtrhgf'

    # Company or vendor of this module
    CompanyName = 'Unknown'

    # Copyright statement for this module
    Copyright = '(c) 2022 @AndrewZtrhgf. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'This is improved version of the official EntraExporter module.
- it is significantly faster thanks to Graph API batching (parallelization)
- there are new backup options (like "IAM", "AccessPolicies", ...)
- and fixes (like "PIM" data export).'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; Guid = '883916f2-9184-46ee-b1f8-b6a2fb784cee'; ModuleVersion = '2.2.0' }
    )

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
        'internal\New-FinalUri.ps1'
        'internal\Get-ObjectProperty.ps1'
        'internal\ConvertTo-OrderedDictionary.ps1'
        'internal\ConvertFrom-QueryString.ps1'
        'internal\ConvertTo-QueryString.ps1'
        'internal\New-GraphBatchRequest.ps1'
        'internal\Invoke-GraphBatchRequest.ps1'
        'internal\New-AzureBatchRequest.ps1'
        'internal\Invoke-AzureBatchRequest.ps1'
        'internal\Search-AzGraph2.ps1'
        'internal\Get-MgGraphAllPages.ps1'
        'Connect-EntraExporter.ps1'
        'Export-Entra.ps1'
        'Get-EEDefaultSchema.ps1'
        'Get-EERequiredScopes.ps1'
        '_getEEAccessPackageAssignmentPolicies.ps1'
        '_getEEAccessPackageAssignments.ps1'
        '_getEEAccessPackageResourceScopes.ps1'
        '_getAzureResourceIAMData.ps1'
        '_getAzureResourceAccessPolicies.ps1'
        '_getAzurePIMDirectoryRoles.ps1'
        '_getAzurePIMResources.ps1'
        '_getAzurePIMGroups.ps1'
    )

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Connect-EntraExporter'
        'Export-Entra'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = 'Microsoft', 'Identity', 'Azure', 'Entra', 'AzureAD', 'AAD', 'PSEdition_Desktop', 'Windows', 'Export', 'Backup', 'DR'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/ztrhgf/EntraExporterFast'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = '
            1.0.0
                initial release of EntraExporterFast module
            1.0.1
                FIXED
                    Get-MgGraphAllPages -missing dependency
            '
        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}