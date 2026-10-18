# Getting started

## Novolis workspace

Repos that import `novolis-governance/build/Novolis.Packaging.targets` already expand `LibraryReference`. Declare the dependency and leave the path to the generated package map:

```xml
<ItemGroup>
  <LibraryReference Include="Novolis.Math.Geometry" />
</ItemGroup>
```

A sibling `.csproj` becomes a `ProjectReference`. A missing checkout becomes a `PackageReference` at `2026.1.*`. Do not also `PackageReference` `Novolis.MSBuild.LibraryReference`; the first static-graph restore would not see the expanded items.

## Outside the workspace

1. Ensure `nuget.config` includes nuget.org and GitHub Packages (`Novolis.*`).
2. Add a central version (`2026.1.*` on the Novolis line):

```xml
<PackageVersion Include="Novolis.MSBuild.LibraryReference" Version="2026.1.*" />
```

3. Reference it with `PrivateAssets=all`:

```xml
<ItemGroup>
  <PackageReference Include="Novolis.MSBuild.LibraryReference" PrivateAssets="all" />
</ItemGroup>
```

4. Declare dependencies:

```xml
<ItemGroup>
  <LibraryReference Include="Novolis.Math.Geometry"
                    Version="2026.1.*"
                    ProjectPath="$(NovolisWorkspaceRoot)novolis-math\src\Novolis.Math.Geometry\Novolis.Math.Geometry.csproj" />
</ItemGroup>
```

When `ProjectPath` exists, MSBuild emits a `ProjectReference`; otherwise a `PackageReference` (item `Version`, or `LibraryReferenceDefaultVersion`, package default `*`). Populate `LibraryProjectMap` when many items share paths.

## Build-only package references

Install `Novolis.MSBuild.BuildReference` when a package contributes build
targets or tasks but should not expose compile/runtime assets:

```xml
<ItemGroup>
  <PackageReference Include="Novolis.MSBuild.BuildReference" PrivateAssets="all" />
  <BuildReference Include="Novolis.Avalonia.Packaging.Inno" />
</ItemGroup>
```

`BuildReference` expands to a private `PackageReference` during evaluation and
honors normal CPM/version metadata.

## File-generating codegen

Install `Novolis.MSBuild.CodeGen` and declare one or more generator items:

```xml
<ItemGroup>
  <NovolisCodeGen Include="Example">
    <ToolProject>$(MSBuildProjectDirectory)..\codegen\Example.Pipeline\Example.Pipeline.csproj</ToolProject>
    <Arguments>run generate</Arguments>
    <WorkingDirectory>$(MSBuildProjectDirectory)..\</WorkingDirectory>
    <InputFiles>@(ExampleCodeGenInput)</InputFiles>
    <OutputFiles>@(ExampleCodeGenOutput)</OutputFiles>
  </NovolisCodeGen>
</ItemGroup>
```

The generator runs before compilation when inputs are newer than outputs.
`NovolisVerifyCodeGen` performs an explicit output/verification pass.

## Executable tool references

Install `Novolis.MSBuild.ToolReference` for a published NuGet tool package:

```xml
<ItemGroup>
  <ToolReference Include="Novolis.Solution.Tool"
                Version="[2026.1.1.90]"
                ToolPath="tools/net10.0/any/Novolis.Solution.Tool.dll"
                Arguments="--help" />
</ItemGroup>
```

`ToolReference` restores the package without compile/runtime assets and
resolves the entry point from `project.assets.json`. Use an exact NuGet
version or exact version range because `PackageDownload` does not accept
floating `PackageReference` versions. Run declared tools with the
`NovolisRunToolReferences` target. Actual `PackAsTool` projects remain in
`novolis-tools`.

## Smoke tests

```powershell
pwsh -File d:\novolis\novolis-msbuild\tests\LibraryReference.Smoke.ps1
pwsh -File d:\novolis\novolis-msbuild\tests\MSBuild.Infrastructure.Smoke.ps1
```
