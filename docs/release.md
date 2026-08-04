# Release

CalVer `YEAR.MAJOR.MINOR.BUILD` via `build/version.json` and merge CI (`github.run_number` as BUILD).

- **Merge to `main`** (package-surface changes) → pack + push to GitHub Packages
- **GitHub Release** → nuget.org (workflow `release.yml`)

See [release policy](https://github.com/Novolis-Platform/novolis-governance/blob/main/docs/release-policy.md).

Consumer float for this package: **`2026.1.*`** (platform line).
