<!-- novolis-pkg-brand:start -->
[![Novolis](https://raw.githubusercontent.com/Novolis-Platform/.github/main/brand/logo-icon.png)](https://novolis-platform.github.io/.github/novolis-msbuild/)

[Novolis](https://github.com/Novolis-Platform) · [Docs](https://novolis-platform.github.io/.github/novolis-msbuild/) · [Source](https://github.com/Novolis-Platform/novolis-msbuild)
<!-- novolis-pkg-brand:end -->

# Novolis.MSBuild.CodeGen

Reusable incremental lifecycle targets for file-generating code generators.

The package schedules a repository-owned generator before compilation, skips
unchanged work using declared inputs and outputs, and avoids execution during
design-time builds and packing. Generator manifests, pipelines, and generated
source remain owned by the consuming repository.

## Install

```xml
<ItemGroup>
  <PackageReference Include="Novolis.MSBuild.CodeGen" PrivateAssets="all" />
</ItemGroup>
```

## Usage

```xml
<ItemGroup>
  <NovolisCodeGen Include="Example">
    <ToolProject>$(MSBuildProjectDirectory)..\codegen\Example.Pipeline\Example.Pipeline.csproj</ToolProject>
    <Arguments>run generate</Arguments>
    <WorkingDirectory>$(MSBuildProjectDirectory)..\</WorkingDirectory>
    <InputFiles>@(ExampleCodeGenInput)</InputFiles>
    <OutputFiles>@(ExampleCodeGenOutput)</OutputFiles>
    <ProjectArguments> -p:NovolisUseProjectReferences=true</ProjectArguments>
  </NovolisCodeGen>
</ItemGroup>
```

Use `NovolisVerifyCodeGen` for an explicit output/verification pass. The
underlying generator remains responsible for detailed fingerprints and
pipeline caching.

For a published generator package, also install
`Novolis.MSBuild.ToolReference`, declare its package entry point, and point the
CodeGen item at that reference:

```xml
<ItemGroup>
  <ToolReference Include="Example.Generator"
                 Version="[2026.1.1.1]"
                 ToolPath="tools/net10.0/any/Example.Generator.dll" />
  <NovolisCodeGen Include="Example">
    <ToolReference>Example.Generator</ToolReference>
    <Arguments>run generate</Arguments>
    <InputFiles>@(ExampleCodeGenInput)</InputFiles>
    <OutputFiles>@(ExampleCodeGenOutput)</OutputFiles>
  </NovolisCodeGen>
</ItemGroup>
```
