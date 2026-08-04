# Design

## Problem

Cross-repo libraries need one committed declaration that works for:

- **Local multi-repo iteration** — compile against sibling source when the project is checked out
- **CI / single-repo consumers** — restore from NuGet when the sibling project is absent

Novolis historically keeps committed `PackageReference` only and optionally rewrites to `ProjectReference` in [ProjectReference mode](https://github.com/Novolis-Platform/novolis-governance/blob/main/docs/platform-project-ref-mode.md). `LibraryReference` inverts that: the committed item *is* the dependency; expansion chooses project vs package at build time.

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

## Non-goals (this repo)

- Replacing org-wide ProjectReference mode or migrating all Novolis `PackageReference` trees
- Inventing transitive ProjectReferences for NuGet dependency graphs
