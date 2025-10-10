function _getAzureResourceIAMData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $rootFolder
    )

    $assignmentsFolder = Join-Path -Path $rootFolder -ChildPath "RoleAssignments"
    $definitionsFolder = Join-Path -Path $rootFolder -ChildPath "RoleDefinitions"

    #region IAM Role assignments export
    #region helper functions
    function _scopeType {
        param ([string] $scope)

        if ($scope -match "^/$") {
            return 'root'
        } elseif ($scope -match "^/subscriptions/[^/]+$") {
            return 'subscription'
        } elseif ($scope -match "^/subscriptions/[^/]+/resourceGroups/[^/]+$") {
            return "resourceGroup"
        } elseif ($scope -match "^/subscriptions/[^/]+/resourceGroups/[^/]+/.+$") {
            return 'resource'
        } elseif ($scope -match "^/providers/Microsoft.Management/managementGroups/.+") {
            return 'managementGroup'
        } else {
            throw 'undefined type'
        }
    }

    function Search-AzGraph2 {
    <#
    .SYNOPSIS
    Function similar to Search-AzGraph, but with pagination support.

    .DESCRIPTION
    Function similar to Search-AzGraph, but with pagination support.

    .PARAMETER query
    KQL query to run against Azure Resource Manager.

    .EXAMPLE
    Search-AzGraph2 -query 'resources
    | where type =~ "microsoft.keyvault/vaults"
    | extend accessPolicies = properties.accessPolicies
    | where isnotnull(accessPolicies) and array_length(accessPolicies) > 0
    | project name, resourceGroup, subscriptionId, accessPolicies'
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $query
    )

    $batchSize = 1000
    $skipResult = 0

    while ($true) {
        $param = @{
            Query          = $query
            First          = $batchSize
            UseTenantScope = $true
        }

        # handle pagination
        if ($skipResult -gt 0) {
            $param.SkipToken = $graphResult.SkipToken
        }

        $graphResult = Search-AzGraph @param

        # output the results
        $graphResult.data

        if ($graphResult.data.Count -lt $batchSize) {
            break
        }

        $skipResult += $skipResult + $batchSize
    }
}

    function Get-AzureDirectoryObject {
        <#
        .SYNOPSIS
        Alternative for Get-MgDirectoryObjectById if you want to avoid Microsoft.Graph.DirectoryObjects module dependency.

        .DESCRIPTION
        Alternative for Get-MgDirectoryObjectById if you want to avoid Microsoft.Graph.DirectoryObjects module dependency.

        .PARAMETER id
        ID(s) of the Azure object(s).

        .EXAMPLE
        Get-AzureDirectoryObject -Id 'a5834928-0f19-292d-4a69-3fbc98fd84ef'
        #>

        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [Alias("ids")]
            [string[]] $id
        )

        if (!(Get-Command Get-MgContext -ErrorAction silentlycontinue) -or !(Get-MgContext)) {
            throw "$($MyInvocation.MyCommand): Authentication needed. Please call Connect-MgGraph."
        }

        # directoryObjects/microsoft.graph.getByIds can process only 1000 ids per request
        $chunkSize = 1000

        # calculate the total number of chunks
        $totalChunks = [Math]::Ceiling($id.Count / $chunkSize)

        # process each chunk
        for ($i = 0; $i -lt $totalChunks; $i++) {
            # calculate the start index of the current chunk
            $startIndex = $i * $chunkSize

            # extract the current chunk
            $currentChunk = $id[$startIndex..($startIndex + $chunkSize - 1)]

            # process the current chunk
            Write-Verbose "Processing chunk $($i + 1) with items: $($currentChunk -join ', ')"

            $body = @{
                "ids" = @($currentChunk)
            }

            Invoke-MgGraphRequest -Uri "v1.0/directoryObjects/microsoft.graph.getByIds" -Body ($body | ConvertTo-Json) -Method POST | Get-MgGraphAllPages | select *, @{Name = 'ObjectType'; Expression = { $_.'@odata.type' -replace "#microsoft.graph." } } -ExcludeProperty '@odata.type'
        }
    }

    function Get-MgGraphAllPages {
        <#
        .SYNOPSIS
        Function make sure that all api call pages are returned a.k.a. all results.

        .DESCRIPTION
        Function make sure that all api call pages are returned a.k.a. all results.

        .PARAMETER NextLink
        For internal use.

        .PARAMETER SearchResult
        For internal use.

        .PARAMETER AsHashTable
        Switch to return results as hashtable.
        By default returns pscustomobject.

        .EXAMPLE
        Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps" | Get-MgGraphAllPages

        .NOTES
        Based on https://dev.to/celadin/get-mggraphallpages-the-mggraph-missing-command-45b5.
        #>

        [CmdletBinding(
            ConfirmImpact = 'Medium',
            DefaultParameterSetName = 'SearchResult'
        )]
        param (
            [Parameter(Mandatory = $true, ParameterSetName = 'NextLink', ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            [Alias('@odata.nextLink')]
            [string] $NextLink
            ,
            [Parameter(ParameterSetName = 'SearchResult', ValueFromPipeline = $true)]
            [PSObject] $SearchResult
            ,
            [switch] $AsHashTable
        )

        begin {}

        process {
            if (!$SearchResult) { return }

            if ($PSCmdlet.ParameterSetName -eq 'SearchResult') {
                # Set the current page to the search result provided
                $page = $SearchResult

                # Extract the NextLink
                $currentNextLink = $page.'@odata.nextLink'

                # We know this is a wrapper object if it has an "@odata.context" property
                #if (Get-Member -InputObject $page -Name '@odata.context' -Membertype Properties) {
                # MgGraph update - MgGraph returns hashtables, and almost always includes .context
                # instead, let's check for nextlinks specifically as a hashtable key
                if ($page.ContainsKey('@odata.count')) {
                    Write-Verbose "First page value count: $($Page.'@odata.count')"
                }

                if ($page.ContainsKey('@odata.nextLink') -or $page.ContainsKey('value')) {
                    $values = $page.value
                } else {
                    # this will probably never fire anymore, but maybe.
                    $values = $page
                }

                # Output the values
                if ($values) {
                    if ($AsHashTable) {
                        # Default returned objects are hashtables, so this makes for easy pscustomobject conversion on demand
                        $values | Write-Output
                    } else {
                        $values | ForEach-Object { [pscustomobject]$_ }
                    }
                }
            }

            while (-Not ([string]::IsNullOrWhiteSpace($currentNextLink))) {
                # Make the call to get the next page
                try {
                    $page = Invoke-MgGraphRequest -Uri $currentNextLink -Method GET
                } catch {
                    throw $_
                }

                # Extract the NextLink
                $currentNextLink = $page.'@odata.nextLink'

                # Output the items in the page
                $values = $page.value

                if ($page.ContainsKey('@odata.count')) {
                    Write-Verbose "Current page value count: $($Page.'@odata.count')"
                }

                if ($AsHashTable) {
                    # Default returned objects are hashtables, so this makes for easy pscustomobject conversion on demand
                    $values | Write-Output
                } else {
                    $values | ForEach-Object { [pscustomobject]$_ }
                }
            }
        }

        end {}
    }
    #endregion helper functions

    #region build the query
    $query = @'
authorizationresources
| where type == "microsoft.authorization/roleassignments"
| extend scope = tostring(properties['scope'])
| extend principalType = tostring(properties['principalType'])
| extend principalId = tostring(properties['principalId'])
| extend roleDefinitionId = tolower(tostring(properties['roleDefinitionId']))
| extend managementGroupId = iif(
        properties['scope'] startswith "/providers/Microsoft.Management/managementGroups",
        tostring(split(properties['scope'], "/")[-1]),""
    )
| mv-expand createdOn = parse_json(properties).createdOn
| mv-expand updatedOn = parse_json(properties).updatedOn
| join kind=inner (
    authorizationresources
    | where type =~ 'microsoft.authorization/roledefinitions'
    | extend id = tolower(id)
    | project id, properties
) on $left.roleDefinitionId == $right.id
| mv-expand roleDefinitionName = parse_json(properties1).roleName
| join kind=leftouter (
    resourcecontainers
    | where type =~ 'microsoft.resources/subscriptions'
    | project-rename subscriptionName = name
    | project subscriptionId, subscriptionName
) on $left.subscriptionId == $right.subscriptionId
'@

    # define the query output
    $property = "createdOn", "updatedOn", "principalId", "principalType", "scope", "roleDefinitionName", "roleDefinitionId", "managementGroupId", "subscriptionId", "subscriptionName", "resourceGroup"
    $query += "`n| project $($property -join ',')"
    #endregion build the query

    #region run the query
    $kqlResult = Search-AzGraph2 -query $query

    # there can be duplicates with different createdOn/updatedOn, keep just the latest one
    $kqlResult = $kqlResult | Group-Object -Property ($property | ? {$_ -notin "createdOn", "updatedOn"}) | % {if ($_.count -eq 1) {$_.group} else {$_.group | sort updatedOn | select -First 1}}

    if (!$kqlResult) { return }
    #endregion run the query

    # get the principal name from its id
    $idToNameList = Get-AzureDirectoryObject -id ($kqlResult.principalId | select -Unique)

    $joinChar = "&"

    # output the final results
    $kqlResult | select @{n = 'PrincipalName'; e = { $id = $_.PrincipalId; $result = $idToNameList | ? Id -EQ $id; if ($result.DisplayName) { $result.DisplayName } else { $result.mailNickname } } }, PrincipalId, PrincipalType, RoleDefinitionName, RoleDefinitionId, Scope, @{ n = 'ScopeType'; e = { _scopeType $_.scope } }, ManagementGroupId, SubscriptionId, SubscriptionName, ResourceGroup, CreatedOn, UpdatedOn | % {
        $item = $_

        switch ($item.scopeType) {
            'root' {
                $outputPath = Join-Path -Path $assignmentsFolder -ChildPath "Root"
            }
            'managementGroup' {
                $outputPath = Join-Path -Path (Join-Path -Path $assignmentsFolder -ChildPath "ManagementGroups") -ChildPath $item.ManagementGroupId
            }
            'subscription' {
                $outputPath = Join-Path -Path (Join-Path -Path $assignmentsFolder -ChildPath "Subscriptions") -ChildPath $item.SubscriptionId
            }
            'resourceGroup' {
                $outputPath = Join-Path -Path (Join-Path -Path (Join-Path -Path $assignmentsFolder -ChildPath "Subscriptions") -ChildPath $item.SubscriptionId) -ChildPath $item.ResourceGroup
            }
            'resource' {
                # $folder = ($item.Scope.Split("/")[-3..-1] -join $joinChar)
                $folder = $item.Scope -replace "/", $joinChar
                $outputPath = Join-Path -Path (Join-Path -Path (Join-Path -Path (Join-Path -Path $assignmentsFolder -ChildPath "Subscriptions") -ChildPath $item.SubscriptionId) -ChildPath $item.ResourceGroup) -ChildPath $folder
            }
            default {
                throw "Undefined scope type $($item.scopeType)"
            }
        }

        $itemId = $item.principalId + $joinChar + ($item.roleDefinitionId).split("/")[-1]

        $outputFileName = Join-Path -Path $outputPath -ChildPath "$itemId.json"

        if ($outputFileName.Length -gt 255 -and (Get-ItemPropertyValue HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -ErrorAction SilentlyContinue) -ne 1) {
            throw "Output file path '$outputFileName' is longer than 255 characters. Enable long path support to continue!"
        }

        if (Test-Path $outputFileName -ErrorAction SilentlyContinue) {
            # this shouldn't happen!
            Write-Error "File $outputFileName already exists!"
            $outputFileName = $outputFileName + ".replace"
        }

        $item | ConvertTo-Json -depth 100 | Out-File (New-Item -Path $outputFileName -Force)
    }
    #endregion IAM Role assignments export

    #region IAM Role definitions export
    #region export built-in RBAC (IAM) roles
    New-AzureBatchRequest -url "https://management.azure.com/providers/Microsoft.Authorization/roleDefinitions?%24filter=type%20eq%20%27BuiltInRole%27&api-version=2022-05-01-preview" | Invoke-AzureBatchRequest | % {
        $result = $_
        $roleId = $result.name
        $outputPath = Join-Path -Path $definitionsFolder -ChildPath "BuiltInRole"
        $outputFileName = Join-Path -Path $outputPath -ChildPath "$roleId.json"
        $result | select * -ExcludeProperty RequestName | ConvertTo-Json -depth 100 | Out-File (New-Item -Path $outputFileName -Force)
    }
    #endregion export built-in RBAC (IAM) roles

    #region export custom RBAC (IAM) roles
    # custom roles are defined on subscription or management group level, so I need to get all subscriptions and management groups first
    # get all subscriptions and management groups
    $scopeList = Search-AzGraph2 -query "
ResourceContainers
| where type =~ 'microsoft.resources/subscriptions' or type =~ 'microsoft.management/managementgroups'
| project name, type, id
"

    # get all custom roles for each subscription and management group
    New-AzureBatchRequest -url "https://management.azure.com/<placeholder>/providers/Microsoft.Authorization/roleDefinitions?%24filter=type%20eq%20%27CustomRole%27&api-version=2022-05-01-preview" -placeholder $scopeList.id -placeholderAsId | Invoke-AzureBatchRequest | % {
        $result = $_
        $scopeId = ($result.RequestName).split("/")[-1]
        $roleId = $result.name

        if ($result.RequestName -like "/providers/Microsoft.Management/managementGroups/*") {
            $outputPath = Join-Path -Path (Join-Path -Path $definitionsFolder -ChildPath "CustomRole\ManagementGroups") -ChildPath $scopeId
        } elseif ($result.RequestName -like "/subscriptions/*") {
            $outputPath = Join-Path -Path (Join-Path -Path $definitionsFolder -ChildPath "CustomRole\Subscriptions") -ChildPath $scopeId
        } else {
            throw "Undefined scope type in $($result.RequestName)"
        }

        $outputFileName = Join-Path -Path $outputPath -ChildPath "$roleId.json"

        $result | select * -ExcludeProperty RequestName | ConvertTo-Json -depth 100 | Out-File (New-Item -Path $outputFileName -Force)
    }
    #endregion export custom RBAC (IAM) roles
    #endregion IAM Role definitions export
}