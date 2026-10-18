<!-- novolis-pkg-brand:start -->
[![Novolis](https://raw.githubusercontent.com/Novolis-Platform/.github/main/brand/logo-icon.png)](https://novolis-platform.github.io/.github/novolis-msbuild/)

[Novolis](https://github.com/Novolis-Platform) · [Docs](https://novolis-platform.github.io/.github/novolis-msbuild/) · [Source](https://github.com/Novolis-Platform/novolis-msbuild)
<!-- novolis-pkg-brand:end -->

# Novolis.MSBuild.BuildReference

An evaluation-time `BuildReference` item for NuGet packages that contribute
MSBuild targets, tasks, analyzers, or other build assets but should not become
compile/runtime dependencies.

## Install

```xml
<ItemGroup>
  <PackageReference Include="Novolis.MSBuild.BuildReference" PrivateAssets="all" />
</ItemGroup>
```

## Usage

```xml
<ItemGroup>
  <BuildReference Include="Novolis.Avalonia.Packaging.Inno" />
</ItemGroup>
```

`BuildReference` expands to an ordinary `PackageReference` during evaluation,
with private build-only asset defaults. Versions and central package
management follow the normal NuGet rules.
