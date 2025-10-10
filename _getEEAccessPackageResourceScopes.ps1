<#
 .Synopsis
  Creates batch requests for accessPackage resource scopes

 .Description
  Creates batch requests for GET /identityGovernance/entitlementManagement/accessPackages/{id}?$expand=accessPackageResourceRoleScopes
  https://docs.microsoft.com/en-us/graph/api/accesspackage-list-accesspackageresourcerolescopes?view=graph-rest-beta&tabs=http

 .Example
  _getEEAccessPackageResourceScopes -Parents $parentIds -BasePath "C:\temp\AccessPackages"
#>

Function _getEEAccessPackageResourceScopes {
  [CmdletBinding()]
  param
  (
      [Parameter(Mandatory = $true)]
      [string[]]$Parents,

      [Parameter(Mandatory = $true)]
      [string]$BasePath
  )

  foreach ($parentId in $Parents) {
      $outputFileName = Join-Path -Path $BasePath -ChildPath $parentId
      $outputFileName = Join-Path -Path $outputFileName -ChildPath "ResourceScopes"
      $id = $outputFileName -replace '\\', '/'

      # add random number to avoid duplicated ids in batch requests
      $id = _randomizeRequestId $id

      $uri = "identityGovernance/entitlementManagement/accessPackages/$parentId?`$expand=accessPackageResourceRoleScopes(`$expand=accessPackageResourceRole,accessPackageResourceScope)"

      Write-Verbose "Adding request '$uri' with id '$id' to the batch"
      $request = New-GraphBatchRequest -Url $uri -Id $id -header @{ ConsistencyLevel = 'eventual' }

      $BatchRequestBetaApi.Value.Add($request)
  }
}
