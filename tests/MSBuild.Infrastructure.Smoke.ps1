#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "novolis-msbuild-smoke-$PID"
$sourceTargets = Join-Path $RepoRoot 'src\Novolis.MSBuild.ToolReference\build\Novolis.MSBuild.ToolReference.targets'
$toolFixture = Join-Path $RepoRoot 'tests\fixtures\ToolReference\ToolReference.csproj'
$codeGenFixture = Join-Path $RepoRoot 'tests\fixtures\CodeGenConsumer\CodeGenConsumer.csproj'
$codeGenTool = Join-Path $RepoRoot 'tests\fixtures\CodeGenTool\CodeGenTool.csproj'

function Invoke-Dotnet {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & dotnet @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "dotnet $($Arguments -join ' ') failed with exit code $exitCode`n$output"
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Get-MsBuildItems {
    param(
        [Parameter(Mandatory)][string]$Project,
        [Parameter(Mandatory)][string]$ItemName,
        [hashtable]$Properties = @{}
    )

    $arguments = [System.Collections.Generic.List[string]]::new()
    $arguments.Add($Project)
    $arguments.Add("-getItem:$ItemName")
    $arguments.Add('-nologo')
    foreach ($key in $Properties.Keys) {
        $arguments.Add("-p:$key=$($Properties[$key])")
    }

    $dotnetArguments = @('msbuild') + $arguments.ToArray()
    $result = Invoke-Dotnet -Arguments $dotnetArguments
    $start = $result.Output.IndexOf('{')
    $end = $result.Output.LastIndexOf('}')
    if ($start -lt 0 -or $end -le $start) {
        throw "No JSON from dotnet msbuild -getItem:$ItemName for $Project.`n$($result.Output)"
    }

    $json = $result.Output.Substring($start, $end - $start + 1) | ConvertFrom-Json
    $items = $json.Items.$ItemName
    if ($null -eq $items) {
        return @()
    }

    if ($items -is [System.Array]) {
        return @($items)
    }

    @($items)
}

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        $failures.Add($Message)
    }
}

function New-TaskProject {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ToolPath,
        [string]$Arguments = '',
        [string]$Inputs = '',
        [string]$Outputs = ''
    )

    $escapedToolPath = [System.Security.SecurityElement]::Escape($ToolPath)
    $escapedArguments = [System.Security.SecurityElement]::Escape($Arguments)
    $escapedInputs = [System.Security.SecurityElement]::Escape($Inputs)
    $escapedOutputs = [System.Security.SecurityElement]::Escape($Outputs)
    $escapedTargets = [System.Security.SecurityElement]::Escape($sourceTargets)

    @"
<Project>
  <Import Project="$escapedTargets" />
  <Target Name="Run">
    <RunToolReferenceTask ToolPath="$escapedToolPath"
                          Arguments="$escapedArguments"
                          Inputs="$escapedInputs"
                          Outputs="$escapedOutputs" />
  </Target>
</Project>
"@ | Set-Content -LiteralPath $Path -Encoding utf8
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    Write-Host 'BuildReference: evaluation and CPM'
    $buildReference = Join-Path $RepoRoot 'tests\fixtures\BuildReference\BuildReference.csproj'
    $buildReferenceCpm = Join-Path $RepoRoot 'tests\fixtures\BuildReferenceCpm\BuildReferenceCpm.csproj'
    $buildItems = Get-MsBuildItems -Project $buildReference -ItemName PackageReference
    $buildItem = @($buildItems | Where-Object Identity -eq 'Newtonsoft.Json')
    Assert-True ($buildItem.Count -eq 1) 'BuildReference: expected one PackageReference'
    Assert-True ($buildItem[0].PrivateAssets -eq 'all') 'BuildReference: expected PrivateAssets=all'
    Assert-True ($buildItem[0].IncludeAssets -match 'buildTransitive') 'BuildReference: expected build-only asset metadata'
    $buildCpmItems = Get-MsBuildItems -Project $buildReferenceCpm -ItemName PackageVersion
    $buildCpmItem = @($buildCpmItems | Where-Object Identity -eq 'Newtonsoft.Json')
    Assert-True ($buildCpmItem.Count -eq 1) 'BuildReference CPM: expected one PackageVersion'
    Assert-True ($buildCpmItem[0].Version -eq '13.0.3') 'BuildReference CPM: expected declared version'

    Write-Host 'ToolReference: restore, resolution, and explicit invocation'
    Invoke-Dotnet -Arguments @('restore', $toolFixture) | Out-Null
    $downloads = Get-MsBuildItems -Project $toolFixture -ItemName PackageDownload
    $download = @($downloads | Where-Object Identity -eq 'Novolis.Solution.Tool')
    Assert-True ($download.Count -eq 1) 'ToolReference: expected PackageDownload for published tool'
    $assetsPath = Join-Path (Split-Path $toolFixture -Parent) 'obj\project.assets.json'
    $assets = Get-Content -LiteralPath $assetsPath -Raw
    Assert-True ($assets -match '"downloadDependencies"') 'ToolReference: expected downloadDependencies in assets'
    Assert-True ($assets -notmatch '"libraries"\s*:\s*\{[^}]*Novolis\.Solution\.Tool') 'ToolReference: tool must not be a library asset'

    $verify = Invoke-Dotnet -Arguments @(
        'msbuild', $toolFixture, '-t:NovolisVerifyToolReferences',
        '-p:Configuration=Release', '-nologo', '-v:minimal'
    )
    Assert-True ($verify.Output -match 'Novolis\.Solution\.Tool\.dll') 'ToolReference: expected resolved DLL path'

    $run = Invoke-Dotnet -Arguments @(
        'msbuild', $toolFixture, '-t:NovolisRunToolReferences',
        '-p:Configuration=Release', '-nologo', '-v:minimal'
    )
    Assert-True ($run.Output -match '\[ToolReference\]') 'ToolReference: expected forwarded tool output'

    $designTime = Invoke-Dotnet -Arguments @(
        'msbuild', $toolFixture, '-t:NovolisRunToolReferences',
        '-p:Configuration=Release', '-p:DesignTimeBuild=true', '-nologo', '-v:minimal'
    )
    Assert-True ($designTime.Output -notmatch '\[ToolReference\]') 'ToolReference: design-time build must not execute'

    Write-Host 'ToolReference: native entry point, argument handling, incrementality, and failure'
    Invoke-Dotnet -Arguments @('build', $codeGenTool, '-c', 'Release', '--no-restore') | Out-Null
    $nativeTool = Join-Path $RepoRoot 'tests\fixtures\CodeGenTool\bin\Release\net10.0\CodeGenTool.exe'
    Assert-True (Test-Path $nativeTool) 'ToolReference: expected Windows apphost for native-path test'
    $nativeRoot = Join-Path $tempRoot 'Native Tool'
    New-Item -ItemType Directory -Path $nativeRoot -Force | Out-Null
    $nativeInput = Join-Path $nativeRoot 'input with spaces.txt'
    $nativeOutput = Join-Path $nativeRoot 'output with spaces.txt'
    Set-Content -LiteralPath $nativeInput -Value 'native-input' -Encoding utf8
    $nativeProject = Join-Path $nativeRoot 'native.proj'
    New-TaskProject -Path $nativeProject -ToolPath $nativeTool `
        -Arguments ('"{0}" "{1}"' -f $nativeInput, $nativeOutput)
    $nativeRun = Invoke-Dotnet -Arguments @('msbuild', $nativeProject, '-t:Run', '-p:Configuration=Release', '-nologo')
    Assert-True (Test-Path $nativeOutput) 'ToolReference: native entry point did not create output'
    Assert-True ((Get-Content -LiteralPath $nativeOutput -Raw) -match 'native-input') 'ToolReference: quoted arguments were not forwarded'

    $beforeNative = (Get-Item -LiteralPath $nativeOutput).LastWriteTimeUtc
    Start-Sleep -Milliseconds 1100
    New-TaskProject -Path $nativeProject -ToolPath $nativeTool `
        -Arguments ('"{0}" "{1}"' -f $nativeInput, $nativeOutput) `
        -Inputs $nativeInput -Outputs $nativeOutput
    Invoke-Dotnet -Arguments @('msbuild', $nativeProject, '-t:Run', '-p:Configuration=Release', '-nologo') | Out-Null
    $afterNative = (Get-Item -LiteralPath $nativeOutput).LastWriteTimeUtc
    Assert-True ($beforeNative -eq $afterNative) 'ToolReference: up-to-date output should skip execution'

    Set-Content -LiteralPath $nativeInput -Value 'native-input-changed' -Encoding utf8
    Invoke-Dotnet -Arguments @('msbuild', $nativeProject, '-t:Run', '-p:Configuration=Release', '-nologo') | Out-Null
    Assert-True ((Get-Content -LiteralPath $nativeOutput -Raw) -match 'native-input-changed') 'ToolReference: stale input should rerun'

    $failureProject = Join-Path $nativeRoot 'failure.proj'
    New-TaskProject -Path $failureProject -ToolPath $nativeTool -Arguments ''
    $failure = Invoke-Dotnet -Arguments @('msbuild', $failureProject, '-t:Run', '-p:Configuration=Release', '-nologo') -AllowFailure
    Assert-True ($failure.ExitCode -ne 0) 'ToolReference: nonzero tool exit must fail the build'

    Write-Host 'CodeGen: generate, no-op incrementality, changed input, verify, and pack suppression'
    $generated = Join-Path (Split-Path $codeGenFixture -Parent) 'generated.txt'
    $input = Join-Path (Split-Path $codeGenFixture -Parent) 'input.txt'
    $originalInput = Get-Content -LiteralPath $input -Raw
    try {
        Remove-Item -LiteralPath $generated -Force -ErrorAction SilentlyContinue
        Invoke-Dotnet -Arguments @('build', $codeGenFixture, '-c', 'Release', '-v:minimal') | Out-Null
        Assert-True (Test-Path $generated) 'CodeGen: expected generated output'
        $before = (Get-Item -LiteralPath $generated).LastWriteTimeUtc
        Start-Sleep -Milliseconds 1100
        Invoke-Dotnet -Arguments @('build', $codeGenFixture, '-c', 'Release', '-v:minimal') | Out-Null
        $after = (Get-Item -LiteralPath $generated).LastWriteTimeUtc
        Assert-True ($before -eq $after) 'CodeGen: unchanged inputs should skip generation'

        Set-Content -LiteralPath $input -Value ($originalInput + 'changed') -Encoding utf8
        Invoke-Dotnet -Arguments @('build', $codeGenFixture, '-c', 'Release', '-v:minimal') | Out-Null
        Assert-True ((Get-Content -LiteralPath $generated -Raw) -match 'changed') 'CodeGen: changed input should regenerate'
        Invoke-Dotnet -Arguments @('msbuild', $codeGenFixture, '-t:NovolisVerifyCodeGen', '-p:Configuration=Release', '-nologo') | Out-Null
    }
    finally {
        Set-Content -LiteralPath $input -Value $originalInput -Encoding utf8
        Invoke-Dotnet -Arguments @('build', $codeGenFixture, '-c', 'Release', '-v:minimal') | Out-Null
    }

    Write-Host 'Packaging: README, icon, documentation, and metadata contract'
    $packagingFixtureDirectory = Join-Path $tempRoot 'PackagingContract'
    New-Item -ItemType Directory -Path $packagingFixtureDirectory -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'icon.png') -Destination (Join-Path $packagingFixtureDirectory 'icon.png')
    Set-Content -LiteralPath (Join-Path $packagingFixtureDirectory 'README.md') -Value @(
        '# Packaging contract'
        ''
        'This prose line is deliberately long enough to become the fallback package description.'
    ) -Encoding utf8
    $packagingProps = [System.Security.SecurityElement]::Escape((Join-Path $RepoRoot 'src\Novolis.MSBuild.Packaging\build\Novolis.MSBuild.Packaging.props'))
    $packagingTargets = [System.Security.SecurityElement]::Escape((Join-Path $RepoRoot 'src\Novolis.MSBuild.Packaging\build\Novolis.MSBuild.Packaging.targets'))
    $packagingProject = Join-Path $packagingFixtureDirectory 'PackagingContract.csproj'
    @"
<Project Sdk="Microsoft.NET.Sdk">
  <Import Project="$packagingProps" />
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <PackageId>Novolis.MSBuild.Packaging.Smoke</PackageId>
    <PackageVersion>1.0.0</PackageVersion>
    <Description>Package Description</Description>
    <IsPackable>true</IsPackable>
  </PropertyGroup>
  <Import Project="$packagingTargets" />
</Project>
"@ | Set-Content -LiteralPath $packagingProject -Encoding utf8
    Invoke-Dotnet -Arguments @('restore', $packagingProject) | Out-Null
    $packagingOutput = Join-Path $packagingFixtureDirectory 'packages'
    New-Item -ItemType Directory -Path $packagingOutput -Force | Out-Null
    Invoke-Dotnet -Arguments @('pack', $packagingProject, '-c', 'Release', '--no-restore', '-o', $packagingOutput, '-v:minimal') | Out-Null
    $packagingNupkg = Get-ChildItem -LiteralPath $packagingOutput -Filter '*.nupkg' | Select-Object -First 1
    Assert-True ($null -ne $packagingNupkg) 'Packaging: expected smoke package'
    if ($null -ne $packagingNupkg) {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($packagingNupkg.FullName)
        try {
            $names = @($archive.Entries | ForEach-Object FullName)
            Assert-True (@($names | Where-Object { $_ -eq 'README.md' }).Count -eq 1) 'Packaging: expected one README.md'
            Assert-True (@($names | Where-Object { $_ -eq 'icon.png' }).Count -eq 1) 'Packaging: expected one icon.png'
            $nuspec = $archive.Entries | Where-Object { $_.FullName -match '\.nuspec$' } | Select-Object -First 1
            $reader = [System.IO.StreamReader]::new($nuspec.Open())
            try {
                $nuspecText = $reader.ReadToEnd()
            }
            finally {
                $reader.Dispose()
            }
            Assert-True ($nuspecText -match 'This prose line is deliberately long enough') 'Packaging: README fallback description missing'
        }
        finally {
            $archive.Dispose()
        }
    }
    Assert-True (Test-Path (Join-Path $packagingFixtureDirectory 'obj\Release\net10.0\PackagingContract.xml')) 'Packaging: XML documentation was not generated'

    Write-Host 'Package contents'
    $packageRoot = Join-Path $tempRoot 'packages'
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    $packageProjects = @(
        'src\Novolis.MSBuild.ToolReference\Novolis.MSBuild.ToolReference.csproj',
        'src\Novolis.MSBuild.CodeGen\Novolis.MSBuild.CodeGen.csproj',
        'src\Novolis.MSBuild.BuildReference\Novolis.MSBuild.BuildReference.csproj',
        'src\Novolis.MSBuild.Packaging\Novolis.MSBuild.Packaging.csproj'
    ) | ForEach-Object { Join-Path $RepoRoot $_ }
    foreach ($project in $packageProjects) {
        Invoke-Dotnet -Arguments @('pack', $project, '-c', 'Release', '--no-restore', '-o', $packageRoot) | Out-Null
    }

    Add-Type -AssemblyName System.IO.Compression
    $nupkgs = Get-ChildItem -LiteralPath $packageRoot -Filter '*.nupkg'
    foreach ($nupkg in $nupkgs) {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($nupkg.FullName)
        try {
            $names = @($archive.Entries | ForEach-Object FullName)
            $packageId = ($packageProjects | Where-Object {
                $projectName = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path $_ -Leaf))
                $nupkg.Name.StartsWith("$projectName.", [System.StringComparison]::OrdinalIgnoreCase)
            } | ForEach-Object {
                [System.IO.Path]::GetFileNameWithoutExtension($_)
            } | Select-Object -First 1)
            Assert-True ($null -ne $packageId) "$($nupkg.Name): package project could not be identified"
            Assert-True (@($names | Where-Object { $_ -eq 'README.md' }).Count -eq 1) "$($nupkg.Name): expected one embedded README.md"
            Assert-True (@($names | Where-Object { $_ -eq 'icon.png' }).Count -eq 1) "$($nupkg.Name): expected one embedded icon.png"
            Assert-True ($names -contains "build/$packageId.props") "$($nupkg.Name): missing build props"
            Assert-True ($names -contains "build/$packageId.targets") "$($nupkg.Name): missing build targets"
            Assert-True ($names -contains "buildTransitive/$packageId.props") "$($nupkg.Name): missing buildTransitive props"
            Assert-True ($names -contains "buildTransitive/$packageId.targets") "$($nupkg.Name): missing buildTransitive targets"
            Assert-True (@($names | Where-Object { $_ -match '^(lib|ref)/' }).Count -eq 0) "$($nupkg.Name): unexpected compile/runtime assets"
            if ($packageId -eq 'Novolis.MSBuild.ToolReference') {
                Assert-True ($names -contains 'build/netstandard2.0/Novolis.MSBuild.ToolReference.dll') "$($nupkg.Name): missing MSBuild task assembly"
            }
        }
        finally {
            $archive.Dispose()
        }
    }
}
catch {
    $failures.Add($_.Exception.Message)
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'FAIL:'
    $failures | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host 'MSBuild infrastructure smoke: OK'
exit 0
