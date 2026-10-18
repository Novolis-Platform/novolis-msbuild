# Design

## Problem

Cross-repo libraries need one committed declaration that works for:

- **Local multi-repo iteration** — compile against sibling source when the project is checked out
- **CI / single-repo consumers** — restore from NuGet when the sibling project is absent

Novolis historically keeps committed `PackageReference` only and optionally rewrites to `ProjectReference` in [ProjectReference mode](https://github.com/Novolis-Platform/novolis-governance/blob/main/docs/platform-project-ref-mode.md). `LibraryReference` inverts that: the committed item *is* the dependency; expansion chooses project vs package at **evaluation time** (required for NuGet restore; a Target-added `ProjectReference` fails with `NETSDK1004`).

## Resolution

```text
LibraryReference (PackageId, optional Version, optional ProjectPath)
  → stamp ProjectPath from LibraryProjectMap when missing
  → if ProjectPath exists and is not self → ProjectReference (+ forwarded metadata)
  → else → PackageReference (Version or LibraryReferenceDefaultVersion)
       CPM: also PackageVersion when no central row exists yet
```

No filesystem crawl. Paths come from explicit metadata or `LibraryProjectMap` (same reliability model as the generated `NovolisPackageProject` map).

## Packaging

Props/targets-only NuGet package (`IncludeBuildOutput=false`, `DevelopmentDependency=true`). Auto-imported from `build/` and `buildTransitive/` when referenced.

The repository also publishes opt-in build infrastructure packages:

- `Novolis.MSBuild.BuildReference` expands private build-only package items at evaluation time.
- `Novolis.MSBuild.CodeGen` owns the incremental MSBuild lifecycle around repository-owned generators.
- `Novolis.MSBuild.Packaging` owns reusable README, icon, documentation, and package-contract behavior.
- `Novolis.MSBuild.ToolReference` restores and invokes published executable tool packages without adding compile/runtime assets.

`ToolReference` does not publish tools. `PackAsTool` projects remain in
`novolis-tools`, and the tool package is restored from the configured NuGet
sources.

When the platform meta-solution resolves these packages as local project
references, governance imports the matching source `build/` assets so the
project-reference graph keeps the same MSBuild behavior as the NuGet package.

## Non-goals (this repo)

- Migrating every existing Novolis `PackageReference` to `LibraryReference` (governance already imports these targets for any project that declares the item)
- Inventing transitive ProjectReferences for NuGet dependency graphs
- Owning version/release policy, package-to-project maps, layer rules, or native runtime-asset staging
