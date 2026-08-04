# Getting started

## Install the package

1. Ensure `nuget.config` includes nuget.org and GitHub Packages (`Novolis.*`).
2. Add a central version (Novolis consumers: `2026.1.*`):

```xml
<PackageVersion Include="Novolis.MSBuild.LibraryReference" Version="2026.1.*" />
```

3. Reference it with `PrivateAssets=all` (Directory.Build.props is typical):

```xml
<ItemGroup>
  <PackageReference Include="Novolis.MSBuild.LibraryReference" PrivateAssets="all" />
</ItemGroup>
```

4. Declare dependencies with `LibraryReference` instead of dual Package/Project blocks:

```xml
<ItemGroup>
  <LibraryReference Include="Novolis.Math.Geometry"
                    Version="2026.1.*"
                    ProjectPath="$(NovolisWorkspaceRoot)novolis-math\src\Novolis.Math.Geometry\Novolis.Math.Geometry.csproj" />
</ItemGroup>
```

When the `.csproj` at `ProjectPath` exists, MSBuild emits a `ProjectReference`; otherwise a `PackageReference` (Version or `LibraryReferenceDefaultVersion`, default `*`).

Optional: populate `LibraryProjectMap` (PackageId → path). Under a Novolis workspace, governance can copy `NovolisPackageProject` into `LibraryProjectMap` so map paths are available without repeating `ProjectPath` on every item.

## Smoke tests

```powershell
pwsh -File d:\novolis\novolis-msbuild\tests\LibraryReference.Smoke.ps1
```
