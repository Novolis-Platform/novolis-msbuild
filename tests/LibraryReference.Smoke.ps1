#Requires -Version 7.0
<#
.SYNOPSIS
  Smoke-test LibraryReference expansion via dotnet msbuild -getItem.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

$consumer = Join-Path $RepoRoot 'tests\fixtures\Consumer\Consumer.csproj'
$consumerCpm = Join-Path $RepoRoot 'tests\fixtures\ConsumerCpm\ConsumerCpm.csproj'
$bridgeMap = Join-Path $RepoRoot 'tests\fixtures\BridgeMap\BridgeMap.csproj'
$failures = [System.Collections.Generic.List[string]]::new()
$expandTarget = @('ExpandLibraryReferences')

function Get-MsBuildItems {
    param(
        [Parameter(Mandatory)][string]$Project,
        [Parameter(Mandatory)][string]$ItemName,
        [hashtable]$Properties = @{},
        [string[]]$Targets = @()
    )

    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add($Project) | Out-Null
    if ($Targets.Count -gt 0) {
        $argList.Add("-t:$($Targets -join ';')") | Out-Null
    }
    $argList.Add("-getItem:$ItemName") | Out-Null
    $argList.Add('-nologo') | Out-Null
    foreach ($k in $Properties.Keys) {
        $argList.Add("-p:$k=$($Properties[$k])") | Out-Null
    }

    $json = & dotnet msbuild @argList 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) {
        $err = & dotnet msbuild @argList 2>&1 | Out-String
        throw "dotnet msbuild -getItem:$ItemName failed for $Project : $err"
    }

    $start = $json.IndexOf('{')
    $end = $json.LastIndexOf('}')
    if ($start -lt 0 -or $end -le $start) {
        throw "No JSON from -getItem:$ItemName for $Project. Raw: $json"
    }
    $jsonOnly = $json.Substring($start, $end - $start + 1)
    $obj = $jsonOnly | ConvertFrom-Json
    $items = $obj.Items.$ItemName
    if ($null -eq $items) { return @() }
    if ($items -is [System.Array]) { return @($items) }
    return @($items)
}

function Get-Identities([object[]]$items) {
    @($items | ForEach-Object { $_.Identity })
}

function Get-Versions([object[]]$items) {
    @($items | ForEach-Object { $_.Version })
}

function Get-FullPaths([object[]]$items) {
    @($items | ForEach-Object {
            if ($_.FullPath) { $_.FullPath }
            elseif ($_.Identity) { $_.Identity }
            else { "$_" }
        })
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $failures.Add($Message) }
}

Write-Host 'LibraryReference smoke: ExplicitProject → ProjectReference'
$pr = Get-MsBuildItems -Project $consumer -ItemName ProjectReference -Properties @{ LibraryRefSmokeScenario = 'ExplicitProject' } -Targets $expandTarget
$pk = Get-MsBuildItems -Project $consumer -ItemName PackageReference -Properties @{ LibraryRefSmokeScenario = 'ExplicitProject' } -Targets $expandTarget
Assert-True (($(Get-FullPaths $pr) -join '`n') -match 'Provider\.csproj') 'ExplicitProject: expected ProjectReference to Provider.csproj'
Assert-True ((Get-Identities $pk) -notcontains 'Novolis.MSBuild.Fixtures.Provider') 'ExplicitProject: Provider must not remain PackageReference'

Write-Host 'LibraryReference smoke: MissingProject → PackageReference Version 9.9.9'
$pk = Get-MsBuildItems -Project $consumer -ItemName PackageReference -Properties @{ LibraryRefSmokeScenario = 'MissingProject' } -Targets $expandTarget
$pr = Get-MsBuildItems -Project $consumer -ItemName ProjectReference -Properties @{ LibraryRefSmokeScenario = 'MissingProject' } -Targets $expandTarget
Assert-True ((Get-Identities $pk) -contains 'Novolis.MSBuild.Fixtures.DoesNotExist') 'MissingProject: expected PackageReference id'
Assert-True ((Get-Versions $pk) -contains '9.9.9') 'MissingProject: expected Version 9.9.9'
Assert-True (($(Get-FullPaths $pr) -join '`n') -notmatch 'Missing\.DoesNotExist') 'MissingProject: must not ProjectReference missing path'

Write-Host 'LibraryReference smoke: MapProject → ProjectReference'
$pr = Get-MsBuildItems -Project $consumer -ItemName ProjectReference -Properties @{ LibraryRefSmokeScenario = 'MapProject' } -Targets $expandTarget
Assert-True (($(Get-FullPaths $pr) -join '`n') -match 'Provider\.csproj') 'MapProject: expected ProjectReference to Provider.csproj'

Write-Host 'LibraryReference smoke: DefaultVersion → *'
$pk = Get-MsBuildItems -Project $consumer -ItemName PackageReference -Properties @{ LibraryRefSmokeScenario = 'DefaultVersion' } -Targets $expandTarget
Assert-True ((Get-Identities $pk) -contains 'Novolis.MSBuild.Fixtures.DoesNotExist') 'DefaultVersion: expected PackageReference id'
Assert-True ((Get-Versions $pk) -contains '*') 'DefaultVersion: expected Version *'

Write-Host 'LibraryReference smoke: CPM → PackageVersion 3.4.5'
$pv = Get-MsBuildItems -Project $consumerCpm -ItemName PackageVersion -Targets $expandTarget
$pk = Get-MsBuildItems -Project $consumerCpm -ItemName PackageReference -Targets $expandTarget
Assert-True ((Get-Identities $pv) -contains 'Novolis.MSBuild.Fixtures.DoesNotExist') 'CPM: expected PackageVersion id'
Assert-True ((Get-Versions $pv) -contains '3.4.5') 'CPM: expected PackageVersion 3.4.5'
Assert-True ((Get-Identities $pk) -contains 'Novolis.MSBuild.Fixtures.DoesNotExist') 'CPM: expected PackageReference id'

if (Test-Path $bridgeMap) {
    Write-Host 'LibraryReference smoke: BridgeMap → ProjectReference via NovolisPackageProject'
    $pr = Get-MsBuildItems -Project $bridgeMap -ItemName ProjectReference -Targets $expandTarget
    Assert-True (($(Get-FullPaths $pr) -join '`n') -match 'Novolis\.MSBuild\.LibraryReference\.csproj') 'BridgeMap: expected ProjectReference to LibraryReference csproj'
}

if ($failures.Count -gt 0) {
    Write-Host 'FAIL:'
    $failures | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host 'LibraryReference smoke: OK'
exit 0
