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

## Smoke tests

```powershell
pwsh -File d:\novolis\novolis-msbuild\tests\LibraryReference.Smoke.ps1
```
