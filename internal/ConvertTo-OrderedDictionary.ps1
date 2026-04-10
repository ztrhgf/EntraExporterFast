function ConvertTo-OrderedDictionary
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject
    )

    begin {
        function _Get-OrderedDictionarySortKey {
            param($Item)

            if ($null -eq $Item) { return '' }

            if (
                $Item.GetType().IsPrimitive -or
                $Item -is [string] -or
                $Item -is [decimal] -or
                $Item -is [datetime] -or
                $Item -is [datetimeoffset] -or
                $Item -is [timespan] -or
                $Item -is [guid] -or
                $Item -is [enum]
            ) {
                return [string]$Item
            }

            $keyParts = [System.Collections.Generic.List[string]]::new()

            if ($Item -is [System.Collections.IDictionary]) {
                foreach ($key in ($Item.Keys | Sort-Object { [string]$_ })) {
                    if ($keyParts.Count -ge 3) { break }
                    $val = $Item[$key]
                    if (
                        $null -eq $val -or
                        $val.GetType().IsPrimitive -or
                        $val -is [string] -or
                        $val -is [decimal] -or
                        $val -is [datetime] -or
                        $val -is [datetimeoffset] -or
                        $val -is [timespan] -or
                        $val -is [guid] -or
                        $val -is [enum]
                    ) {
                        $keyParts.Add([string]$val)
                    }
                }
            }
            else {
                try {
                    $props = @(
                        $Item.PSObject.Properties |
                        Where-Object {
                            $_.IsGettable -and
                            $_.MemberType -in [System.Management.Automation.PSMemberTypes]::NoteProperty, [System.Management.Automation.PSMemberTypes]::Property
                        } |
                        Sort-Object Name
                    )

                    foreach ($prop in $props) {
                        if ($keyParts.Count -ge 3) { break }
                        try { $val = $prop.Value } catch { continue }
                        if (
                            $null -eq $val -or
                            $val.GetType().IsPrimitive -or
                            $val -is [string] -or
                            $val -is [decimal] -or
                            $val -is [datetime] -or
                            $val -is [datetimeoffset] -or
                            $val -is [timespan] -or
                            $val -is [guid] -or
                            $val -is [enum]
                        ) {
                            $keyParts.Add([string]$val)
                        }
                    }
                }
                catch { }
            }

            return $keyParts -join "`0"
        }
    }

    process
    {
        if ($null -eq $InputObject) {
            return $null
        }

        if (
            $InputObject.GetType().IsPrimitive -or
            $InputObject -is [string] -or
            $InputObject -is [decimal] -or
            $InputObject -is [datetime] -or
            $InputObject -is [datetimeoffset] -or
            $InputObject -is [timespan] -or
            $InputObject -is [guid] -or
            $InputObject -is [enum]
        ) {
            return $InputObject
        }

        if ($InputObject -is [System.Collections.IDictionary]) {
            $outputObject = [ordered]@{}
            $sortedKeys = [System.Collections.Generic.List[Object]]::new()

            foreach ($key in $InputObject.Keys) {
                $insertAt = $sortedKeys.Count

                for ($i = 0; $i -lt $sortedKeys.Count; $i++) {
                    if ([string]::CompareOrdinal([string]$key, [string]$sortedKeys[$i]) -lt 0) {
                        $insertAt = $i
                        break
                    }
                }

                $sortedKeys.Insert($insertAt, $key)
            }

            foreach ($key in $sortedKeys) {
                $outputObject[$key] = ConvertTo-OrderedDictionary -InputObject $InputObject[$key]
            }

            return $outputObject
        }

        if ($InputObject -is [System.Array]) {
            $outputArray = @()
            foreach ($item in ($InputObject | Sort-Object { _Get-OrderedDictionarySortKey $_ })) {
                $outputArray += ConvertTo-OrderedDictionary -InputObject $item
            }

            return $outputArray
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $outputArray = @()
            foreach ($item in ($InputObject | Sort-Object { _Get-OrderedDictionarySortKey $_ })) {
                $outputArray += ConvertTo-OrderedDictionary -InputObject $item
            }

            return $outputArray
        }

        $properties = @(
            $InputObject.PSObject.Properties |
            Where-Object {
                $_.MemberType -in [System.Management.Automation.PSMemberTypes]::NoteProperty, [System.Management.Automation.PSMemberTypes]::Property -and
                $_.IsGettable
            }
        )

        if ($properties.Count -gt 0) {
            $outputObject = [ordered]@{}
            $sortedProperties = [System.Collections.Generic.List[Object]]::new()

            foreach ($property in $properties) {
                $insertAt = $sortedProperties.Count

                for ($i = 0; $i -lt $sortedProperties.Count; $i++) {
                    if ([string]::CompareOrdinal([string]$property.Name, [string]$sortedProperties[$i].Name) -lt 0) {
                        $insertAt = $i
                        break
                    }
                }

                $sortedProperties.Insert($insertAt, $property)
            }

            foreach ($property in $sortedProperties) {
                try {
                    $propertyValue = $property.Value
                }
                catch {
                    continue
                }

                $outputObject[$property.Name] = ConvertTo-OrderedDictionary -InputObject $propertyValue
            }

            return [PSCustomObject]$outputObject
        }

        return $InputObject
    }
}
