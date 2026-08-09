<!-- novolis-marketing:start -->
<p align="center">
  <a href="https://github.com/Novolis-Platform">
    <img src="https://raw.githubusercontent.com/Novolis-Platform/.github/main/brand/logo-brand-transparent.svg" width="360" alt="Novolis"/>
  </a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/Novolis-Platform/.github/main/brand/banners/novolis-msbuild.svg" width="100%" alt="novolis-msbuild"/>
</p>

<p align="center">
  <strong>MSBuild props and targets</strong><br/>
  Shared MSBuild props/targets used across Novolis package repos.
</p>

<p align="center">
  <a href="https://novolis-platform.github.io/.github/novolis-msbuild/"><img src="https://img.shields.io/badge/docs-portfolio-0a7ea3" alt="docs"/></a>
  <a href="https://github.com/Novolis-Platform/novolis-msbuild/actions"><img src="https://img.shields.io/github/actions/workflow/status/Novolis-Platform/novolis-msbuild/merge.yml?branch=main&label=merge&logo=github" alt="merge"/></a>
  <a href="https://github.com/orgs/Novolis-Platform/packages?repo_name=novolis-msbuild"><img src="https://img.shields.io/badge/packages-GitHub%20Packages-0a7ea3?logo=nuget" alt="packages"/></a>
  <a href="https://github.com/Novolis-Platform"><img src="https://img.shields.io/badge/org-Novolis--Platform-111827" alt="org"/></a>
</p>

<p align="center">
  <a href="https://novolis-platform.github.io/.github/novolis-msbuild/">Docs</a>
  ·
  <a href="https://nuget.pkg.github.com/Novolis-Platform/index.json"><code>https://nuget.pkg.github.com/Novolis-Platform/index.json</code></a>
  ·
  <a href="https://github.com/Novolis-Platform/.github/blob/main/profile/README.md">Org landing</a>
  ·
  <a href="https://github.com/Novolis-Platform/novolis-governance">Governance</a>
</p>

---
<!-- novolis-marketing:end -->
# novolis-msbuild

Publishes **`Novolis.MSBuild.LibraryReference`** — an MSBuild props/targets package that expands `LibraryReference` items to `ProjectReference` or `PackageReference`.

## Package

| Id | Role |
|----|------|
| `Novolis.MSBuild.LibraryReference` | Development dependency (`PrivateAssets=all`); imports props/targets via `build/` + `buildTransitive/` |

```xml
<ItemGroup>
  <PackageReference Include="Novolis.MSBuild.LibraryReference" PrivateAssets="all" />
  <LibraryReference Include="Novolis.Math.Geometry"
                    Version="2026.1.*"
                    ProjectPath="$(NovolisWorkspaceRoot)novolis-math\src\Novolis.Math.Geometry\Novolis.Math.Geometry.csproj" />
</ItemGroup>
```

See [src/Novolis.MSBuild.LibraryReference/README.md](src/Novolis.MSBuild.LibraryReference/README.md) for the full contract (map item, CPM, default `*` version).

## Local verify

```powershell
dotnet pack d:\novolis\novolis-msbuild\src\Novolis.MSBuild.LibraryReference\Novolis.MSBuild.LibraryReference.csproj -c Release
pwsh -File d:\novolis\novolis-msbuild\tests\LibraryReference.Smoke.ps1
```

## Docs

- [docs/getting-started.md](docs/getting-started.md)
- [docs/design.md](docs/design.md)
- [docs/release.md](docs/release.md)

