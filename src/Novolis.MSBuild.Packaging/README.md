<!-- novolis-pkg-brand:start -->
[![Novolis](https://raw.githubusercontent.com/Novolis-Platform/.github/main/brand/logo-icon.png)](https://novolis-platform.github.io/.github/novolis-msbuild/)

[Novolis](https://github.com/Novolis-Platform) · [Docs](https://novolis-platform.github.io/.github/novolis-msbuild/) · [Source](https://github.com/Novolis-Platform/novolis-msbuild)
<!-- novolis-pkg-brand:end -->

# Novolis.MSBuild.Packaging

Reusable package conventions for Novolis libraries.

The package provides README embedding and validation, package icon discovery,
strict XML documentation defaults, and generic package metadata. CalVer,
GitHub Packages publishing, repository maps, and layer policy remain owned by
`novolis-governance`.

## Install

```xml
<ItemGroup>
  <PackageReference Include="Novolis.MSBuild.Packaging" PrivateAssets="all" />
</ItemGroup>
```

Packable projects must keep `README.md` next to the project file. The package
embeds it in the resulting NuGet package and uses the first suitable prose line
as a fallback description when no description is supplied.
