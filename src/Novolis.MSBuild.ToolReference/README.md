<!-- novolis-pkg-brand:start -->
[![Novolis](https://raw.githubusercontent.com/Novolis-Platform/.github/main/brand/logo-icon.png)](https://novolis-platform.github.io/.github/novolis-msbuild/)

[Novolis](https://github.com/Novolis-Platform) · [Docs](https://novolis-platform.github.io/.github/novolis-msbuild/) · [Source](https://github.com/Novolis-Platform/novolis-msbuild)
<!-- novolis-pkg-brand:end -->

# Novolis.MSBuild.ToolReference

Evaluation-time executable tool references for MSBuild projects.

`ToolReference` restores a published NuGet tool package without exposing its
compile or runtime assets. The package-relative `ToolPath` is resolved from
`project.assets.json`, then the tool can be run explicitly or incrementally
before compilation.

## Install

```xml
<ItemGroup>
  <PackageReference Include="Novolis.MSBuild.ToolReference" PrivateAssets="all" />
</ItemGroup>
```

With central package management, add the package version to
`Directory.Packages.props`.

## Usage

```xml
<ItemGroup>
  <ToolReference Include="Novolis.Solution.Tool"
                Version="[2026.1.1.90]"
                ToolPath="tools/net10.0/any/Novolis.Solution.Tool.dll"
                Arguments="--help"
                Inputs="$(MSBuildProjectFullPath)"
                Outputs="$(IntermediateOutputPath)tool-reference.stamp"
                RunOnBuild="false" />
</ItemGroup>
```

Run all declared tools explicitly with the `NovolisRunToolReferences` target.
Set `RunOnBuild` or `RunOnPack` only for tools that are safe to invoke during
those lifecycle phases. Design-time builds do not execute tools.

Tool packages must be restored from the configured NuGet sources. Use an exact
NuGet version or exact version range; `PackageDownload` does not accept
floating `PackageReference` versions. This package does not create a local
feed or install global tools.
