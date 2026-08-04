# Novolis.MSBuild.LibraryReference

MSBuild package that provides a single `LibraryReference` item for dependencies that should use a local `ProjectReference` when the project exists, otherwise a `PackageReference`.

## Install

```xml
<!-- Directory.Build.props or Directory.Packages.props + PackageReference -->
<ItemGroup>
  <PackageReference Include="Novolis.MSBuild.LibraryReference" PrivateAssets="all" />
</ItemGroup>
```

With central package management, add a `PackageVersion` row (for example `2026.1.*`).

## Usage

```xml
<ItemGroup>
  <!-- Explicit path: project if the file exists, else package -->
  <LibraryReference Include="Novolis.Math.Geometry"
                    Version="2026.1.*"
                    ProjectPath="$(NovolisWorkspaceRoot)novolis-math\src\Novolis.Math.Geometry\Novolis.Math.Geometry.csproj" />

  <!-- Version omitted → $(LibraryReferenceDefaultVersion), default "*" -->
  <LibraryReference Include="Some.Other.Lib" />
</ItemGroup>
```

Optional map (PackageId → path), useful when many consumers share the same checkout layout:

```xml
<ItemGroup>
  <LibraryProjectMap Include="Novolis.Math.Geometry">
    <ProjectPath>$(NovolisWorkspaceRoot)novolis-math\src\Novolis.Math.Geometry\Novolis.Math.Geometry.csproj</ProjectPath>
  </LibraryProjectMap>
</ItemGroup>
```

`LibraryReference` items without `ProjectPath` pick up a matching `LibraryProjectMap` entry before the Exists check.

## Properties

| Property | Default | Meaning |
|----------|---------|---------|
| `LibraryReferenceEnabled` | `true` | Kill switch |
| `LibraryReferenceDefaultVersion` | `*` | Used when item `Version` is omitted (“latest” float) |

Floating versions require NuGet floating versions (Novolis enables `CentralPackageFloatingVersionsEnabled`). Prefer an explicit platform float such as `2026.1.*` for Novolis packages.

## CPM vs non-CPM

- **CPM** (`ManagePackageVersionsCentrally=true`): emits `PackageReference` without Version, and adds `PackageVersion` only when that PackageId is not already in `@(PackageVersion)`.
- **Non-CPM**: puts `Version` on the `PackageReference`.

## Notes

- Same non-transitive caveat as ProjectReference mode: replacing a package with a project drops NuGet transitive closure. Reference needed dependencies explicitly.
- Common `PackageReference` / `ProjectReference` metadata (`PrivateAssets`, `IncludeAssets`, `ExcludeAssets`, `OutputItemType`, …) is forwarded when set.
- Committed `.csproj` files should use `LibraryReference` (or `PackageReference`); do not commit cross-repo `ProjectReference` paths.
